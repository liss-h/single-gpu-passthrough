#!/bin/bash

# Display each command after execution
set -x

# Treat undefined variables as error
set -u

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"

# Exit if already in correct state
if [[ -e "/sys/bus/pci/drivers/vfio-pci/$VIRSH_GPU_VIDEO" ]] && [[ -e "/sys/bus/pci/drivers/radeon/$VIRSH_SECONDARY_GPU_VIDEO" ]]; then
    echo "GPUs already bound to correct drivers, nothing to do" >&2
    exit 0
fi

# Save current gnome session
su -c "gnome-session-restore --dbus-address $VIRSH_USER_DBUS_ADDR save" - $VIRSH_USER

# Kill the display manager
systemctl stop gdm.service
killall gdm-wayland-session

systemctl kill user@1000.service

# Kill pipewire
#su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user stop pipewire pipewire-pulse" - $VIRSH_USER

# Isolate CPU Cores from host
systemctl set-property --runtime -- user.slice AllowedCPUs=0,1,6,7

# Unbind VTconsoles
for vtcon in /sys/class/vtconsole/vtcon*; do
   echo 0 > "$vtcon/bind"
done

# Avoid a race condition by waiting a couple of seconds
sleep 2

# Rebind secondary GPU
#modprobe radeon
driver-rebind "$VIRSH_SECONDARY_GPU_VIDEO" amdgpu

# Unbind primary GPU
driver-rebind "$VIRSH_GPU_VIDEO" vfio-pci
#modprobe -r amdgpu

# Unbind gpu audio
#driver-rebind "$VIRSH_GPU_AUDIO" vfio-pci

# Rebind secondary gpu audio
#modprobe snd_hda_intel
#driver-rebind "$VIRSH_SECONDARY_GPU_AUDIO" snd_hda_intel

# Avoid race condition
sleep 4

# Rebind VTConsoles
for vtcon in /sys/class/vtconsole/vtcon*; do
    echo 1 > "$vtcon/bind"
done

# Restart users dbus, to prevent gnome from not starting
#su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user restart dbus" - $VIRSH_USER

# Start display manager
#systemctl restart gdm.service

systemctl restart gdm.service

# Start scream
#su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user start scream" - $VIRSH_USER
