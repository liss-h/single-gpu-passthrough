#!/bin/bash

# Helpful to read output when debugging
set -x

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"


# Save current gnome session
su -c "/home/liss/CLionProjects/session-restore/target/release/session-restore --dbus-address $VIRSH_USER_DBUS_ADDR save" - $VIRSH_USER

# Kill the display manager
systemctl stop gdm.service

# Kill pipewire
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user stop pipewire pipewire-pulse" - $VIRSH_USER

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
virsh nodedev-reattach "$VIRSH_GPU_VIDEO"

# Reattach gpu audio; not needed for me since mine is permanently detached
#virsh nodedev-reattach "$VIRSH_GPU_AUDIO"

# Load all previously unloaded radeon drivers
modprobe  amdgpu
#modprobe  gpu_sched
#modprobe  ttm
#modprobe  drm_kms_helper
#modprobe  i2c_algo_bit
#modprobe  drm
#modprobe  snd_hda_intel

# Avoid race condition
sleep 2

# Rebind VTConsoles
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

# Restart the users dbus, to prevent gnome from not starting
su -c "DBUS_SESSION_BUS_ADDRESS=$VIRSH_USER_DBUS_ADDR systemctl --user restart dbus" - $VIRSH_USER

# Start display manager
systemctl restart gdm.service
