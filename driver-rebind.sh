#!/bin/bash

set -u

pci_device="$1"
old_driver="$2"
new_driver="$3"

if [[ -e /sys/bus/pci/drivers/$new_driver/"$pci_device" ]]; then
    echo "Already bound to requested driver. Exiting"
    exit 0
fi

if ! echo "$pci_device" >| /sys/bus/pci/drivers/"$old_driver"/unbind; then
    echo "Error: Could not unbind from old driver. Aborting"
    exit 1
fi

if ! echo "$pci_device" >| /sys/bus/pci/drivers/"$new_driver"/bind; then
    echo "Error: Could not bind to new driver. Attempting to revert"
    
    if ! echo "$pci_device" >| /sys/bus/pci/drivers/"$old_driver"/bind; then
        echo "Error: Unable to revert"
        exit 1
    fi
fi

exit 0
