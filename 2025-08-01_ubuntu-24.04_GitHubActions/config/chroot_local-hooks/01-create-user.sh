#!/bin/bash
# Create default user with sudo privileges and no password
echo "Creating user liveuser..."
useradd -m -s /bin/bash liveuser
echo "liveuser:live" | chpasswd
echo "liveuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/liveuser
chmod 0440 /etc/sudoers.d/liveuser