# The What and Why of Single GPU passthrough

This is a variant of the popular `Single GPU Passthrough` method
adapted for people who have one powerful and one mediocre eGPU/iGPU.
This allows you to  use Windows and Linux in parallel,
instead of being confined to Windows as soon as the VM starts. 

**Note: This isn't a comprehensive guide on how to do GPU passthrough, just everything (I think)
there is to know about my specific setup and how to replicate it. Please refer to the [Arch Wiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF) if you are new to GPU Passthrough.**

**Note: The scripts are adapted to AMD hardware. I don't own any NVidia GPUs and as far as I know the 
scripts will definitely not work with NVidia setups and would need additional commands for that.
Please refer to related `Single GPU Passthrough` repos for more information.**


# General Setup

## Required File Editing
Edit the provided `kvm.conf`, `start.sh` and `stop.sh` to match your setup.

For `start.sh` and `stop.sh` you need to keep the following in mind.

- If you are **not** an AMD user you might need to add some NVidia specific stuff to `start.sh` and `stop.sh`, but since I don't own any NVidia GPUs I can't tell you what or where you need to add this. Please refer to other repos in the `Single GPU Passthrough` space.

- If you **don't** use `gdm/gnome` edit the lines mentioning `gdm.service` accordingly.

<br>

## Creating the Directory Structure
Create this directory structure based with the provided files.
**Replace `YOUR_VM_NAME` with the actual name of your VM.**

```cs
📦 /etc/libvirt
|__📁 hooks
|  |__⚙️ kvm.conf
|  |__📃 qemu
|  |__📁 qemu.d
|  |  |__📁 YOUR_VM_NAME
|  |  |  |__📁 prepare
|  |  |  |  |__📁 begin
|  |  |  |  |  |__📃 start.sh
|  |  |  |__📁 release
|  |  |  |  |__📁 end
|  |  |  |  |  |__📃 stop.sh
```

<br>

## Installing driver-rebind.sh
For the scripts to work you need to copy driver-rebind.sh to a directory in your $PATH (typically /usr/local/bin) and rename it to driver-rebind, this can be
done by.

> ### # install ./driver-rebind.sh /usr/local/bin/driver-rebind

<br>

`driver-rebind` is a custom script I wrote that rebinds a given device to a different driver. I found this works better than the other solutions I found online.

## Troubleshooting

### VirtIO driver taking infinite time to install or error about class not being initialized
> This seems to be some kind of bug in some versions of Windows 10.
> Changing the machine type to ```<type arch="x86_64" machine="pc-q35-5.1">hvm</type>``` might fix this bug.

### GPU enters infinite reset loop once it has been used by VM (```*ERROR* atombios stuck in loop for more than 20secs aborting```)
> I am not sure why this happens, if I had to guess it has something to do with the GPU not being uninitialized properly.
> The fix is to install the AMD GPU drivers in the VM, once they are installed this behaviour stops. This means you should probably do the windows install
> without GPU passthrough since everytime the installer forces a restart this bug apperears and requires a full machine reboot.

### Primary monitor switches to Windows just fine but secondary stays black (KVM switch used)
> If you are using a KVM switch then it's possible that
> if you press the switch button too slowly, the secondary GPU won't initialize properly, since it thinks there is no
> display connected. So to solve that just press the switch button faster, like immediatly after
> beginning to start the VM or ideally before.

### Race conditions
> There are a few places in `start.sh` and `stop.sh` where artitficial delays are 
> inserted via `sleep` to avoid race conditions, if the handover isn't working correctly
> you could try increasing these values. I personally haven't extensively tested how low I can go
> on these.

<br>

# My Setup

## Software
- Fedora 38 Workstation
- Gnome
- Pipewire
- Wayland
- SELinux enabled

<br>

## Known working Hardware
### Dual eGPU
- Gigabyte B550 AORUS Pro
- AMD Ryzen R5 3600
- AMD Radeon Vega 64 (to be passed through)
- AMD Radeon R5 240 OEM (as the replacement gpu when the Vega is passed through)
### eGPU + iGPU
- Asus ROG STRIX Z790-F
- Intel i9-13900k
- AMD Radeon RX 6800
- Intel iGPU

<br>

## Monitor Setup Variants
### With KVM switch
- Monitor 1 plugged into primary GPU
- Monitor 2 plugged into a KVM switch that is plugged into both primary and secondary GPU

### Without KVM switch
- Monitor 1 plugged into primary GPU
- Monitor 2 plugged into secondary GPU

The reasoning behind this rather weird configuration is that I want
to be able to access Linux even when the VM is booted, so only my primary Monitor
gets claimed by the VM. The advantage of this is that I don't have to trust Windows
to handle Discord and other applications, so it can focus solely on the game I am running and hopefully do less weird things.

So my setup seemlessly* transitions from being a dual monitor Linux setup to
a one monitor Linux, one monitor Windows setup.

*: It's obviously not completely seemless since gdm needs to be restarted on every GPU handover. And you may need to press
    the switch button on the KVM switch.

<br>

## UEFI Setup

### Asus Strix Z790-F
```cs
📁 Advanced
|__📁 PCI Subsystem Settings
|  |__⚙ Above 4G Decoding := Disabled [leaving this enabled causes crashes in kernel >=6.13]
|  |__⚙ Re-Size BAR Support := Disabled [same as above]
|__📁 System Agent (SA) Configuration
|  |__⚙ VT-d := Enabled
|  |__⚙ Control Iommu Pro-boot Behavior := Enable IOMMU
📁 Boot
|__📁 CSM (Compatibility Support Module)
|  |__⚙ Launch CSM := Disabled
```


### Gigabyte B550 Aorus Pro
```cs
📁 Tweaker
|__📁 Advanced CPU Settings
|  |__⚙ SVM Mode := Enabled
📁 Settings
|__📁 IO Ports
|  |__⚙ Initial Display Output := PCIe 1 Slot
|  |__⚙ Above 4G Decoding := Disabled [breaks GPU reinit after VM shutdown; '*ERROR* atombios stuck in loop for more than 20secs aborting']
|  |__⚙ Re-Size BAR Support := Disabled [same as above]
|__📁 Miscellaneous
|  |__⚙ IOMMU := Enabled
📁 Boot
|__⚙ CSM Support := Disabled [to prevent black screen during bootup process]
```

<br>

## Groups
My user is in the following groups

- `input` : for evdev passthrough
- `kvm`, `qemu`, `libvirt` : for general vm stuff

<br>

## Dracut
> ### /etc/dracut.conf.d/vfio.conf
> ```
> force_drivers+=" vfio vfio-pci vfio_iommu_type1 vfio_virqfd "
> ```

<br>

## Kernel parameters

- `amd_iommu=on`/`intel_iommu=on` : enable IOMMU support
- `iommu=pt` : prevent linux from touching devices which cannot be passed through

> ### /etc/default/grub (AMD)
> ```
> GRUB_CMDLINE_LINUX="rhgb quiet amd_iommu=on iommu=pt"
> ```

> ### /etc/default/grub (Intel)
> ```
> GRUB_CMDLINE_LINUX="rhgb quiet intel_iommu=on iommu=pt"
> ```

<br>

## Permanent Claims

I have my both my GPU HDMI-Audio devices permanently claimed, since i don't use them anyways.
That also ensures that all needed vfio kernel modules are permanently loaded.

> ### /etc/modprobe.d/vfio.conf (optional)
> ```
> options vfio-pci ids=OPTIONAL_IDS_OF_THINGS_TO_PERMANENTLY_CLAIM
> ```

You can get the PCI device ids via `lspci -nnv`. Importantly this has to be the id in the square brackets at the end and not the one in front.
So in this case `1002:aaf8` and **not** `08:00.1`.

> ### $ lspci -nnv
> ```
> -- snip --
>
> 08:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Vega 10 HDMI Audio [Radeon Vega 56/64] [1002:aaf8]
>	Subsystem: Advanced Micro Devices, Inc. [AMD/ATI] Vega 10 HDMI Audio [Radeon Vega 56/64] [1002:aaf8]
>	Flags: fast devsel, IRQ 58, IOMMU group 17
>	Memory at fcea0000 (32-bit, non-prefetchable) [size=16K]
>	Capabilities: <access denied>
>	Kernel driver in use: amdgpu
>	Kernel modules: snd_hda_intel
>
> -- snip --
> ```

**Don't forget to run `dracut -fv` or equivalent afterwards.**

<br>

## Resizeable BAR (No longer works on my system with kernel >=6.13)
QEMU currently does not support exposing ReBAR capabilities fully. I.e. the VM cannot resize the BARs itself.
This means we must resize the BARs ourselves. This [guide from Level1Techs](https://forum.level1techs.com/t/vfio-2023-radeon-7000-edition-wip/199252) however pointed me to this solution.

First check that ReBAR is even working
> ### # lspci -vv
> ```
> -- snip --
> 03:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Navi 21 [Radeon RX 6800/6800 XT / 6900 XT] (rev c3) (prog-if 00 [VGA controller])
>   Subsystem: Advanced Micro Devices, Inc. [AMD/ATI] Radeon RX 6900 XT
>   -- snip --
>   
>   Capabilities: [200 v1] Physical Resizable BAR
>       BAR 0: current size: 16GB, supported: 256MB 512MB 1GB 2GB 4GB 8GB 16GB
>       BAR 2: current size: 256MB, supported: 2MB 4MB 8MB 16MB 32MB 64MB 128MB 256MB
>   
>   -- snip --
>     
> -- snip --
> ```

<br>

Now that we confirmed that ReBAR indeed works, we now need to find working sizes for BAR 0 and BAR 2.
On my system `8GB`/`8MB` works flawlessly, and according to Level1Techs those values should work
for most systems. For some unknown reason the default sizes for my RX 6800 of `256GB`/`16MB` do not work and
result in a black screen in the VM.

The start script (only the egpu-igpu one, because I never got it to work on the other system) contains
some lines that resize the BARs to their respective sizes before VM bootup. The values echoed into the pseudo-files correspond to powers of two (in megabytes) of the wanted BAR size. For example a wanted BAR size of `8GB` corresponds to the value `13` echoed into the pseudo-file because `2^13MB = 8192MB = 8GB`.

When setting the BAR sizes it is important that the GPU is not used by _anything_, not even the driver. To achieve
this I have placed the BAR resizing after the GPU was successfully bound to `vfio-pci`. Of course `vfio-pci` counts as a driver using the card, so it needs to be unloaded first after which the BARs can be resized and
then `vfio-pci` can be reloaded.

<br>
