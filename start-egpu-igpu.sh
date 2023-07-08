#!/bin/bash

# Display each command after execution
set -x

# Treat undefined variables as error
set -u

# Load the config file
source "/etc/libvirt/hooks/kvm.conf"

# Exit if already in correct state
if [[ -e "/sys/bus/pci/drivers/vfio-pci/$VIRSH_GPU_VIDEO" ]]; then
    echo "GPUs already bound to correct drivers, nothing to do"
    exit 0
fi

# Kill display manager
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

# Unbind primary GPU
driver-rebind "$VIRSH_GPU_VIDEO" vfio-pci
modprobe -r amdgpu

# Avoid GPU not being initialized before rebinding framebuffer
sleep 2

# Rebind framebuffer
for vtcon in ${bound_framebuffers[@]}; do
    echo 1 > "$vtcon/bind"
done

# Isolate CPU cores from host
systemctl set-property --runtime -- user.slice AllowedCPUs=12-31
systemctl set-property --runtime -- system.slice AllowedCPUs=12-31
systemctl set-property --runtime -- init.scope AllowedCPUs=12-31

# Avoid Framebuffer not being bound before gdm is started
sleep 2

# Start display manager
systemctl restart gdm.service

