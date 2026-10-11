#!/bin/bash
# ==========================================
# NEXUS TUNNELING - m-sshws.sh (v4.0 NEXUS)
# Menu SSH WebSocket: Dropbear 2019 + WStunnel
# ==========================================

source /usr/local/bin/common.sh
check_license

DB_SSHWS="/etc/nexustunnel/sshws_users.db"   # user:password:expired
touch "$DB_SSHWS"

WS_BIN="/opt/ssh-ws/wstunnel10"
DB_BIN="/opt/dropbear2019/bin/dropbear"
DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
IP=$(curl -sS --max-time 5 ipv4.icanhazip.com)

add_days() { date -d "+$1 days" '+%Y-%m-%d' 2>/dev/null; }
expired_days() {
    local exp="$1"
    [[ "$exp" == "lifetime" ]] && { echo "∞"; return; }
    echo $(( ( $(date -d "$exp" +%s 2>/dev/null || echo 0) - $(date +%s) ) / 86400 ))
}

list_users() {
    echo -e "  ${CYAN}NO   USER                     EXPIRED      STATUS${NC}"
    local i=1
    while IFS=: read -r u p exp; do
        [[ -z "$u" ]] && continue
        local sisa=$(expired_days "$exp")
        local col="${GREEN}"
        if [[ "$sisa" != "∞" && "$sisa" =~ ^-?[0-9]+$ ]] && [[ "$sisa" -lt 0 ]]; then col="${RED}"; fi
        printf "  %-4d %-24s %-12s %s%s hari%s\n" "$i" "$u" "$exp" "$col" "$sisa" "$NC"
        ((i++))
    done < "$DB_SSHWS"
    [[ $(wc -l < "$DB_SSHWS") -eq 0 ]] && echo -e "  ${YELLOW}Belum ada user SSH-WS.${NC}"
}

service_status() {
    st1=$(systemctl is-active dropbear-ws 2>/dev/null)
    st2=$(systemctl is-active wstunnel-ws 2>/dev/null)
    st3=$(systemctl is-active haproxy 2>/dev/null)
    echo -e "  ${CYAN}Dropbear 2019 :${NC} $st1"
    echo -e "  ${CYAN}WStunnel      :${NC} $st2"
    echo -e "  ${CYAN}HAProxy       :${NC} $st3"
    echo -e "  ${CYAN}Dropbear ver  :${NC} $($DB_BIN -V 2>&1 | head -1)"
    echo -e "  ${CYAN}Ports         :${NC} 443(SSL /sshws) • 80(/sshws) → 2222 → 2221"
}

add_user() {
    read -p "  Username : " U
    U=$(echo "$U" | tr -d ' ' | tr 'A-Z' 'a-z')
    [[ -z "$U" || ! "$U" =~ ^[a-z0-9._-]+$ ]] && { echo -e "${RED}Username tidak valid!${NC}"; read -p "Enter..."; return; }
    grep -q "^${U}:" "$DB_SSHWS" && { echo -e "${RED}User sudah ada!${NC}"; read -p "Enter..."; return; }
    read -p "  Password : " P
    [[ -z "$P" ]] && P="nexus123"
    read -p "  Masa aktif (hari) [30]: " D
    [[ -z "$D" || ! "$D" =~ ^[0-9]+$ ]] && D=30
    EXP=$(add_days "$D")
    # Bikin user di dropbear 2019 (auth pakai password SSH biasa → useradd system)
    useradd -m -s /bin/bash "$U" 2>/dev/null
    echo "$U:$P" | chpasswd
    echo "${U}:${P}:${EXP}" >> "$DB_SSHWS"
    echo -e "${GREEN}✓ User SSH-WS dibuat!${NC}"
    echo -e "${LINE}"
    echo -e "  ${WHITE}━━━━━ INFO SSH WEBSOCKET ━━━━━${NC}"
    echo -e "  ${CYAN}SSL (443 TLS):${NC}"
    echo -e "    Host      : $DOMAIN"
    echo -e "    IP        : $IP"
    echo -e "    Port      : 443"
    echo -e "    Path      : /sshws"
    echo -e "    Type      : WebSocket TLS (Dropbear 2019.78)"
    echo -e "  ${CYAN}NON-SSL (80 NTLS):${NC}"
    echo -e "    Host      : $DOMAIN / $IP"
    echo -e "    Port      : 80"
    echo -e "    Path      : /sshws"
    echo -e "  ${CYAN}Login:${NC}"
    echo -e "    Username  : $U"
    echo -e "    Password  : $P"
    echo -e "    Expired   : $EXP (sisa $(expired_days $EXP) hari)"
    echo -e "  ${CYAN}Server Detail:${NC}"
    echo -e "    OpenSSH   : 22 (port 22)"
    echo -e "    Dropbear  : 2019.78 (port 2221 via WS)"
    echo -e "    UDPGW     : 7100-7300"
    echo -e "  ${CYAN}Payload (HTTP Injector / NetMod):${NC}"
    echo -e "    GET /sshws HTTP/1.1[crlf]Host: $DOMAIN[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"
    echo -e "  ${CYAN}Config Client (WStunnel v10):${NC}"
    echo -e "    wstunnel client -P /sshws wss://$DOMAIN:443 -L tcp://1080:127.0.0.1:2221"
    echo -e "    → lalu konek SSH ke 127.0.0.1:1080 dengan user $U"
    echo -e "  ${CYAN}App Support:${NC} HTTP Injector, NetMod, WStunnel, HTTP Custom"
    echo -e "${LINE}"
    read -p "Tekan Enter..."
}

del_user() {
    read -p "  Username yang dihapus : " U
    if ! grep -q "^${U}:" "$DB_SSHWS"; then echo -e "${RED}User tidak ditemukan!${NC}"; read -p "Enter..."; return; fi
    grep -v "^${U}:" "$DB_SSHWS" > "$DB_SSHWS.tmp" && mv "$DB_SSHWS.tmp" "$DB_SSHWS"
    userdel -r "$U" 2>/dev/null
    echo -e "${GREEN}✓ User $U dihapus!${NC}"; sleep 1
}

renew_user() {
    read -p "  Username yang diperpanjang : " U
    if ! grep -q "^${U}:" "$DB_SSHWS"; then echo -e "${RED}User tidak ditemukan!${NC}"; read -p "Enter..."; return; fi
    read -p "  Tambah berapa hari : " D
    [[ -z "$D" || ! "$D" =~ ^[0-9]+$ ]] && D=30
    local line=$(grep "^${U}:" "$DB_SSHWS")
    local pass=$(echo "$line" | cut -d: -f2)
    local NEWEXP=$(add_days "$D")
    sed -i "s|^${U}:.*|${U}:${pass}:${NEWEXP}|" "$DB_SSHWS"
    echo -e "${GREEN}✓ $U diperpanjang $D hari → $NEWEXP (sisa $(expired_days $NEWEXP) hari)${NC}"; sleep 1
}

trial_user() {
    U="trial$(date +%s | tail -c 5)"
    P="nexus123"
    useradd -m -s /bin/bash "$U" 2>/dev/null
    echo "$U:$P" | chpasswd
    echo "${U}:${P}:$(date -d '+1 hours' '+%Y-%m-%d %H:%M')" >> "$DB_SSHWS"
    echo -e "${GREEN}✓ Trial 1 jam dibuat!${NC}"
    echo -e "${LINE}"
    echo -e "  ${CYAN}SSL (443 TLS):${NC} $DOMAIN :443 /sshws (WStunnel, Dropbear 2019.78)"
    echo -e "  ${CYAN}NON-SSL (80)  :${NC} $IP :80 /sshws"
    echo -e "  ${CYAN}Username  :${NC} $U"
    echo -e "  ${CYAN}Password  :${NC} $P"
    echo -e "  ${CYAN}Expired   :${NC} $(date -d '+1 hours' '+%Y-%m-%d %H:%M') (1 jam)"
    echo -e "${LINE}"
    read -p "Tekan Enter..."
}

check_login() {
    read -p "  Username : " U
    read -sp "  Password : " P; echo
    if [[ -x "$DB_BIN" ]] && command -v dbclient >/dev/null 2>&1; then
        # tes login lewat wstunnel local loop
        timeout 10 $WS_BIN client -P /sshws ws://127.0.0.1:2222 -L "tcp://19999:127.0.0.1:2221" >/dev/null 2>&1 &
        sleep 2
        echo "$P" | timeout 6 /opt/dropbear2019/bin/dbclient -p 19999 "$U"@127.0.0.1 "echo LOGIN_OK" 2>&1 | grep -q LOGIN_OK \
            && echo -e "${GREEN}✓ LOGIN BERHASIL${NC}" || echo -e "${RED}✗ LOGIN GAGAL${NC}"
        pkill -f "tcp://19999" 2>/dev/null
    else
        # fallback: cek user+pass system
        if id "$U" >/dev/null 2>&1 && python3 -c "
import spwd, crypt, sys
u='$U'
for e in spwd.getspnam(u)[1:]:
    if e and crypt.crypt('$P', e) == e: sys.exit(0)
sys.exit(1)" 2>/dev/null; then
            echo -e "${GREEN}✓ LOGIN VALID (system password match)${NC}"
        else
            echo -e "${RED}✗ LOGIN GAGAL${NC}"
        fi
    fi
    read -p "Enter..."
}

show_config() {
    echo -e "${LINE}"
    echo -e "  ${WHITE}CONFIG SSH-WS UNTUK CLIENT${NC}"
    echo -e "${LINE}"
    echo -e "  ${CYAN}SSL (443):${NC}"
    echo -e "   Host: $DOMAIN   Port: 443   Path: /sshws   Type: WebSocket TLS"
    echo -e "  ${CYAN}NON-SSL (80):${NC}"
    echo -e "   Host: $IP   Port: 80   Path: /sshws   Type: WebSocket (no TLS)"
    echo -e "  ${CYAN}Uname Apps:${NC} SSH Client → set WS path /sshws (HTTP upgrade)"
    echo -e "  ${CYAN}WStunnel CLI:${NC} wstunnel client -P /sshws wss://$DOMAIN:443 -L tcp://1080:127.0.0.1:2221"
    echo -e "${LINE}"
    read -p "Enter..."
}

while true; do
    clear
    echo -e "${LINE}"
    echo -e "        ${WHITE}MENU SSH WEBSOCKET${NC}"
    echo -e "        ${CYAN}Dropbear 2019.78 + WStunnel${NC}"
    echo -e "${LINE}"
    service_status
    echo -e "${LINE}"
    list_users
    echo -e "${LINE}"
    echo -e "  ${GREEN}[1]${NC} Tambah User SSH-WS"
    echo -e "  ${CYAN}[2]${NC} Trial User (1 jam)"
    echo -e "  ${YELLOW}[3]${NC} Perpanjang User"
    echo -e "  ${RED}[4]${NC} Hapus User"
    echo -e "  ${BLUE}[5]${NC} Cek Login User"
    echo -e "  ${CYAN}[6]${NC} Config Client"
    echo -e "  ${CYAN}[7]${NC} Restart Service SSH-WS"
    echo -e "  ${RED}[0]${NC} Kembali ke Menu Utama"
    echo -e "${LINE}"
    echo -ne "${WHITE}Pilih menu: ${NC}"
    read -r opt
    case $opt in
        1) add_user ;;
        2) trial_user ;;
        3) renew_user ;;
        4) del_user ;;
        5) check_login ;;
        6) show_config ;;
        7) systemctl restart dropbear-ws wstunnel-ws; echo -e "${GREEN}✓ Service di-restart${NC}"; sleep 1 ;;
        0) exec menu ;;
        *) sleep 0.2 ;;
    esac
done
