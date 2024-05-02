#!/bin/bash

# Display each command after execution
set -x

# Treat undefined variables as error
set -u


# Load the config file
source "/etc/libvirt/hooks/kvm.conf"

# Exit if already in correct state
if [[ -e "/sys/bus/pci/drivers/vfio-pci/$VIRSH_GPU_VIDEO" ]] && [[ -e "/sys/bus/pci/drivers/radeon/$VIRSH_SECONDARY_GPU_VIDEO" ]]; then
    echo "GPUs already bound to correct drivers, nothing to do" >&2
    exit 0
fi

# Stop display manager
systemctl stop gdm.service

# Avoid framebuffer still being used while unbinding
sleep 2

# Unbind framebuffer
declare -a bound_framebuffers

for vtcon in /sys/class/vtconsole/vtcon*; do
   if [[ $(cat "$vtcon/bind") == 1 ]]; then
       echo 0 > "$vtcon/bind"
       bound_framebuffers+=("$vtcon")
   fi
done

# Avoid framebuffer still being bound while GPU is unbinding
sleep 2

# Rebind secondary GPU
modprobe radeon
driver-rebind "$VIRSH_SECONDARY_GPU_VIDEO" radeon

# Unbind primary GPU
driver-rebind "$VIRSH_GPU_VIDEO" vfio-pci
modprobe -r amdgpu

# Unbind gpu audio
#driver-rebind "$VIRSH_GPU_AUDIO" vfio-pci

# Rebind secondary gpu audio
#modprobe snd_hda_intel
#driver-rebind "$VIRSH_SECONDARY_GPU_AUDIO" snd_hda_intel

# Avoid GPU not being initialized before rebinding framebuffer
sleep 2

# Rebind framebuffer
for vtcon in "${bound_framebuffers[@]}"; do
    echo 1 > "$vtcon/bind"
done

# Isolate CPU cores from host
systemctl set-property --runtime -- user.slice AllowedCPUs=0,1,6,7
systemctl set-property --runtime -- system.slice AllowedCPUs=0,1,6,7
systemctl set-property --runtime -- init.scope AllowedCPUs=0,1,6,7

# Avoid Framebuffer not being bound before gdm is started
sleep 2

# Start display manager
systemctl restart gdm.service
