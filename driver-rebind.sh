#!/bin/bash

set -u

device="$1"
new_driver="/sys/bus/pci/drivers/$2"
old_driver="$(find /sys/bus/pci/drivers -name $1 -exec dirname {} \; 2> /dev/null)"

if [[ -e "$new_driver/$device" ]]; then
    echo "Notice: Device already bound to $new_driver. Exiting"
    exit 0
fi

# Unbind
if [[ -n  "$old_driver" ]]; then
  if ! echo "$device" >| "$old_driver/unbind"; then
      echo "Error: Device was not bound to $old_driver or could not unbind. Aborting" >&2
      exit 1
  fi
else
    echo "Notice: Device is not bound to any driver. Skipping unbind"
fi

# Bind
if ! echo "$device" >| "$new_driver/bind"; then
    echo "Error: Could not bind to $new_driver. Attempting to revert to $old_driver" >&2

    if ! echo "$device" >| "$old_driver/bind"; then
        echo "Error: Unable to revert" >&2
        exit 1
    fi
fi

exit 0
