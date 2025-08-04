#!/bin/sh
# /root/welcome.sh — startup welcome script for Alpine Live ISO

echo ""
echo "──────────────────────────────────────────────────────"
echo " 🚀 Welcome to Alpine Linux Live! "
echo "──────────────────────────────────────────────────────"

# System info
echo " 🖥️  Hostname:    $(hostname)"
echo " 📅 Date:        $(date)"
echo " 🧠 Uptime:      $(uptime -p)"

# Network info
echo ""
echo "🌐 Network:"
ip -4 addr show | awk '/inet / {print " 📡 Interface:", $NF, "→", $2}'

# Disk usage
echo ""
echo "💾 Root filesystem usage:"
df -h / | awk 'NR==1 || NR==2 {print " " $0}'

echo ""
echo "🔧 Type 'setup-alpine' to install Alpine to disk."
echo "📚 Use 'man' or 'help' for more info."
echo "──────────────────────────────────────────────────────"
