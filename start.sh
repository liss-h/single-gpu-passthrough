#!/bin/bash

# Helpful to read output when debugging
set -x

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"

# save current gnome session
su -c "/home/liss/Development/session-restore/save-session.py --dbus-address unix:path=/run/user/1000/bus" - liss

# kill the display manager
systemctl stop gdm.service
killall gdm-x-session

# kill pipewire
pipewire_pid=$(pgrep -u liss pipewire)
kill $pipewire_pid

# Unbind VTconsoles
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind

# Avoid a race condition by waiting a couple of seconds
sleep 4


# Unload all Radeon drivers
modprobe -r amdgpu
#modprobe -r snd_hda_intel
#modprobe -r gpu_sched
#modprobe -r ttm
#modprobe -r drm_kms_helper
#modprobe -r i2c_algo_bit
#modprobe -r drm


# Unbind the GPU from display driver
virsh nodedev-detach $VIRSH_GPU_VIDEO
virsh nodedev-detach $VIRSH_GPU_AUDIO

# Load VFIO kernel module
modprobe vfio
modprobe vfio_pci
modprobe vfio_iommu_type1

# idk if this is nessesary
sleep 4

# rebind VTConsoles
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

# start gdm
systemctl restart gdm.service

# restart users dbus, to prevent gnome from not being able to register the session
su -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus systemctl --user restart dbus" - liss
