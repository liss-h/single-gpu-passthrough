#!/bin/bash

# Helpful to read output when debugging
set -x

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"


# save current gnome session
su -c "/home/liss/Development/session-restore/save-session.py --dbus-address unix:path=/run/user/1000/bus" - liss

# kill display manager
systemctl stop gdm.service

# kill pipewire
su -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus systemctl --user stop pipewire pipewire-pulse" - liss

# Unbind VTconsoles
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind

# avoid race condition
sleep 3

# Unload all the vfio modules
modprobe -r vfio_pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

# Reattach the gpu
virsh nodedev-reattach $VIRSH_GPU_VIDEO
virsh nodedev-reattach $VIRSH_GPU_AUDIO

# Load all Radeon drivers
modprobe  amdgpu
modprobe  gpu_sched
modprobe  ttm
modprobe  drm_kms_helper
modprobe  i2c_algo_bit
modprobe  drm
modprobe  snd_hda_intel


#rebind VTConsoles
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

# restart users dbus, to prevent gnome from not starting
su -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus systemctl --user restart dbus" - liss

# start display manager
systemctl restart gdm.service
