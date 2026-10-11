#!/bin/bash
# fix-permissions.sh - Secure file permissions for wibutunnel

echo "Fixing file permissions for security..."

# Secure bot config and databases
if [ -f /etc/wibutunnel/bot.conf ]; then
    chmod 600 /etc/wibutunnel/bot.conf
    echo "✓ bot.conf secured (600)"
fi

# Secure all database files
for db in /etc/wibutunnel/*.db; do
    if [ -f "$db" ]; then
        chmod 600 "$db"
        echo "✓ $(basename "$db") secured (600)"
    fi
done

# Ensure lock.conf is also secured
if [ -f /etc/wibutunnel/lock.conf ]; then
    chmod 600 /etc/wibutunnel/lock.conf
    echo "✓ lock.conf secured (600)"
fi

# Secure tmp directory
if [ -d /etc/wibutunnel/tmp ]; then
    chmod 700 /etc/wibutunnel/tmp
    echo "✓ tmp directory secured (700)"
fi

echo "✓ All sensitive files secured"
