#!/bin/bash

# Display each command after execution
set -x

# Treat undefined variables as error
set -u

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"

# Exit if not supposed to revert
if [[ -f "/home/$VIRSH_USER/.win10debugshutdown" ]]; then
    echo "doing debug stop, nothing to do"
    exit 0
fi

# Save current gnome session
su -c "gnome-session-restore --dbus-address $VIRSH_USER_DBUS_ADDR save" - $VIRSH_USER

# Kill the display manager
systemctl stop gdm.service
killall gdm-wayland-session

# Kill all user desktop processes
systemctl kill user@$(id -u $VIRSH_USER).service

# Reverse cpu core isolation
systemctl set-property --runtime -- user.slice AllowedCPUs=0-11
systemctl set-property --runtime -- system.slice AllowedCPUs=0-11
systemctl set-property --runtime -- init.scope AllowedCPUs=0-11

# Unbind VTconsoles
for vtcon in /sys/class/vtconsole/vtcon*; do
    echo 0 > "$vtcon/bind"
done

# Avoid race condition by waiting a few seconds
sleep 2

# Rebind primary gpu
modprobe amdgpu
driver-rebind "$VIRSH_GPU_VIDEO" amdgpu

# Unbind secondary gpu
driver-rebind "$VIRSH_SECONDARY_GPU_VIDEO" vfio-pci
modprobe -r radeon

# Rebind gpu audio
#modprobe snd_hda_intel
#driver-rebind "$VIRSH_GPU_AUDIO" snd_hda_intel

# Unbind secondary gpu audio
#driver-rebind "$VIRSH_SECONDARY_GPU_AUDIO" vfio-pci

# Avoid race condition
sleep 4

# Rebind VTConsoles
for vtcon in /sys/class/vtconsole/vtcon*; do
    echo 1 > "$vtcon/bind"
done

# Start display manager
systemctl restart gdm.service
