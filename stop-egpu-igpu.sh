#!/bin/bash

# Display each command after execution
set -x

# Treat undefined variables as error
set -u

# Load the config file with our environmental variables
source "/etc/libvirt/hooks/kvm.conf"

if [[ -f "/home/$VIRSH_USER/.vmdebugshutdown" ]]; then
    echo "doing debug stop, nothing to do"
    exit 0
fi

# Kill display manager
systemctl stop gdm.service

# Avoid framebuffers being used while unbinding
sleep 2

# Unbind framebuffers
declare -a bound_framebuffers

for vtcon in /sys/class/vtconsole/vtcon*; do
   if [[ $(cat "$vtcon/bind") == 1 ]]; then
       echo 0 > "$vtcon/bind"
       bound_framebuffers+=("$vtcon")
   fi
done

# Avoid framebuffer still being bound while GPU is unbinding
sleep 2

# Rebind primary gpu
modprobe amdgpu
driver-rebind "$VIRSH_GPU_VIDEO" amdgpu

# Avoid GPU not being initialized while rebinding framebuffer
sleep 2

# Rebind framebuffers
for vtcon in ${bound_framebuffers[@]}; do
    echo 1 > "$vtcon/bind"
done

# Reverse cpu core isolation
systemctl set-property --runtime -- user.slice AllowedCPUs=0-31
systemctl set-property --runtime -- system.slice AllowedCPUs=0-31
systemctl set-property --runtime -- init.scope AllowedCPUs=0-31

# Avoid framebuffer not being bound while gdm is starting
sleep 2

# Start display manager
systemctl restart gdm.service

