#!/bin/bash

# Display each command after execution
set -x

# Treat undefined variables as error
set -u

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"

if [[ -e /sys/bus/pci/drivers/vfio-pci/"$VIRSH_GPU_VIDEO" ]]; then
	echo "primary gpu already claimed by vfio-pci, nothing to do"
	exit 0
fi

# Save current gnome session
su -c "gnome-session-restore --dbus-address $VIRSH_USER_DBUS_ADDR save" - $VIRSH_USER

# Kill the display manager
systemctl stop gdm.service

# Kill pipewire
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user stop pipewire pipewire-pulse" - $VIRSH_USER

# Isolate CPU Cores from host
systemctl set-property --runtime -- user.slice AllowedCPUs=0,1,6,7

# Unbind VTconsoles
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind

# Avoid a race condition by waiting a couple of seconds
sleep 4

# Load VFIO kernel module; not nessesary for me since i have them permanently loaded
#modprobe vfio
#modprobe vfio_pci
#modprobe vfio_iommu_type1

# Unbind the GPU from display driver
driver-rebind "$VIRSH_GPU_VIDEO" amdgpu vfio-pci # virsh nodedev-detach $VIRSH_GPU_VIDEO
modprobe -r amdgpu

# Reattach secondary gpu
modprobe radeon
driver-rebind "$VIRSH_SECONDARY_GPU_VIDEO" vfio-pci radeon # virsh nodedev-reattach $VIRSH_SECONDARY_GPU_VIDEO

# Unbind gpu audio, not needed for me since mine is permanently detached 
#driver-rebind "$VIRSH_GPU_AUDIO" snd_hda_intel vfio-pci

# Bind secondary gpu audio
#driver-rebind "$VIRSH_SECONDARY_GPU_AUDIO" vfio-pci snd_hda_intel

# Avoid race condition
sleep 2

# Rebind VTConsoles
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

# Restart users dbus, to prevent gnome from not starting
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user restart dbus" - $VIRSH_USER

# Start display manager
systemctl restart gdm.service

# Start scream
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user start scream" - $VIRSH_USER
