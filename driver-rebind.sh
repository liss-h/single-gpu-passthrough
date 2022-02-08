#!/bin/bash

set -u

device_id="$1"
vendor="$(cat /sys/bus/pci/devices/$device_id/vendor)"
device="$(cat /sys/bus/pci/devices/$device_id/device)"

new_driver="/sys/bus/pci/drivers/$2"
old_driver="$(find /sys/bus/pci/drivers -name $1 -exec dirname {} \; 2> /dev/null)"

if [[ -e "$new_driver/$device_id" ]]; then
    echo "Notice: Device already bound to $new_driver. Exiting" >&2
    exit 0
fi

echo "$vendor $device" >| "$new_driver/new_id" || true

# Unbind
if [[ -n  "$old_driver" ]]; then
  if ! echo "$device_id" >| "$old_driver/unbind"; then
      echo "Error: Device was not bound to $old_driver or could not unbind. Aborting" >&2
      exit 1
  fi
else
    echo "Notice: Device is not bound to any driver. Skipping unbind" >&2
fi

# Bind
if ! echo "$device_id" >| "$new_driver/bind"; then
    echo "Error: Could not bind to $new_driver. Attempting to revert to $old_driver" >&2

    if ! echo "$device_id" >| "$old_driver/bind"; then
        echo "Error: Unable to revert" >&2
        exit 1
    fi
fi

exit 0
