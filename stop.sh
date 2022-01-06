#!/bin/bash

# Display each command after execution
set -x

# Treat undefined variables as error
set -u

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"


if [[ -f "/home/liss/.win10debugshutdown" ]]; then
    echo "doing debug stop, nothing to do"
    exit 0
fi

# Save current gnome session
su -c "gnome-session-restore --dbus-address $VIRSH_USER_DBUS_ADDR save" - $VIRSH_USER

# Kill the display manager
systemctl stop gdm.service

# Kill pipewire
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user stop pipewire pipewire-pulse" - $VIRSH_USER

# Reverse cpu core isolation
systemctl set-property --runtime -- user.slice AllowedCPUs=0-11

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
sleep 2

# Rebind VTConsoles
for vtcon in /sys/class/vtconsole/vtcon*; do
    echo 1 > "$vtcon/bind"
done

# Restart the users dbus, to prevent gnome from not starting
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user restart dbus" - $VIRSH_USER

# Start display manager
systemctl restart gdm.service

# Stop scream
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user stop scream" - $VIRSH_USER
