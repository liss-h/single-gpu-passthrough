#!/bin/bash

# Helpful to read output when debugging
set -x

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"

# Check for correctly set variables
if [[ -z "$VIRSH_GPU_VIDEO" ]] || [[ -z "$VIRSH_GPU_AUDIO" ]]; then
	echo "VIRSH_GPU_VIDEO or VIRSH_GPU_AUDIO not specified, unable to continue"
	exit 1
fi

if [[ -z $VIRSH_USER ]] || [[ -z $VIRSH_USER_DBUS_ADDR ]]; then
	echo "VIRSH_USER or VIRSH_USER_DBUS_ADDR not specified, unable to continue"
	exit 1
fi

if ! id -u $VIRSH_USER > /dev/null; then
	echo "specified VIRSH_USER does not exist, unable to continue"
	exit 1
fi


# Save current gnome session
su -c "/home/liss/CLionProjects/session-restore/target/release/session-restore --dbus-address $VIRSH_USER_DBUS_ADDR save" - $VIRSH_USER

# Kill the display manager
systemctl stop gdm.service

# Kill pipewire
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user stop pipewire pipewire-pulse" - $VIRSH_USER

# Unbind VTconsoles
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind

# Avoid a race condition by waiting a couple of seconds
sleep 4

# Unload all nessesary radeon drivers
modprobe -r amdgpu
#modprobe -r snd_hda_intel
#modprobe -r gpu_sched
#modprobe -r ttm
#modprobe -r drm_kms_helper
#modprobe -r i2c_algo_bit
#modprobe -r drm

# Unbind the GPU from display driver
virsh nodedev-detach "$VIRSH_GPU_VIDEO"

# Unbind gpu audio, not needed for me since mine is permanently detached
#virsh nodedev-detach "$VIRSH_GPU_AUDIO"

# Load VFIO kernel module; not nessesary for me since i have them permanently loaded
#modprobe vfio
#modprobe vfio_pci
#modprobe vfio_iommu_type1

# Avoid race condition
sleep 2

# Rebind VTConsoles
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

# Restart users dbus, to prevent gnome from not starting
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user restart dbus" - $VIRSH_USER

# Start display manager
systemctl restart gdm.service
