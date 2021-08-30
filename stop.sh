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
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind

# Avoid race condition by waiting a few seconds
sleep 4

# Unload all the vfio modules; not nessesary for me since i have them permanently loaded
#modprobe -r vfio_pci
#modprobe -r vfio_iommu_type1
#modprobe -r vfio

# Reattach the gpu
modprobe amdgpu
virsh nodedev-reattach $VIRSH_GPU_VIDEO

# Detach secondary gpu
virsh nodedev-detach $VIRSH_SECONDARY_GPU_VIDEO
modprobe -r radeon

# Reattach gpu audio; not needed for me since mine is permanently detached 
#virsh nodedev-reattach $VIRSH_GPU_AUDIO

# Unbind secondary gpu audio
#virsh nodedev-detach $VIRSH_SECONDARY_GPU_AUDIO

# Avoid race condition
sleep 2

# Rebind VTConsoles
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

# Restart the users dbus, to prevent gnome from not starting
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user restart dbus" - $VIRSH_USER

# Start display manager
systemctl restart gdm.service

# Stop scream
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user stop scream" - $VIRSH_USER
