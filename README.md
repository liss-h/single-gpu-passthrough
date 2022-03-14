# The What and Why of Single GPU passthrough

This is a variant/modification of the popular `Single GPU Passthrough` method 
adapted for people who have one powerful and one mediocre/garbage GPU (like me).
This allows you to  use Windows and Linux in parallel,
instead of being confined to Windows as soon as the VM starts. 

**Note: This isn't a comprehensive guide on how to do GPU passthrough, just everything (i think)
there is to know about my specific setup and how to replicate it. Please refer to the [Arch Wiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF) if you are new to GPU Passthrough.**

**Note: The scripts are adapted to AMD hardware. I don't own and NVidia GPUs and as far as I know the 
scripts will definitely not work with NVidia setups and would need additional commands for that.
Please refer to related `Single GPU Passthrough` repos for more information.**


# General Setup

## Required File Editing
Edit the provided `kvm.conf`, `start.sh` and `stop.sh` to match your setup.

For `start.sh` and `stop.sh` you need to keep the following in mind.

- If you are **not** an AMD user you might need to add some NVidia specific stuff to `start.sh` and `stop.sh`, but since I don't own any NVidia GPUs I can't tell you what or where you need to add this. Please refer to other repos in the `Single GPU Passthrough` space.

- If you **don't** use `gdm/gnome` edit the lines mentioning `gdm.service` accordingly.

- **Related:** If you **don't** want to use [gnome-session-restore](https://github.com/Clueliss/gnome-session-restore) or **don't** use gnome remove or comment out the lines mentioning it.

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

## Troubleshooting

### VirtIO driver taking infinite time to install or error about class not being initialized
> This seems to be some kind of bug in Windows. 
> Changing the machine type to ```<type arch="x86_64" machine="pc-q35-5.1">hvm</type>``` fixes this bug.

### GPU enters infinite reset loop once it has been used by VM (```*ERROR* atombios stuck in loop for more than 20secs aborting```)
> I am not sure why this happens, if I had to guess it has something to do with the GPU not being uninitialized properly.
> The fix is to install the AMD GPU drivers in the VM, once they are installed this behaviour stops. This means you should probably do the windows install
> without GPU passthrough since everytime the installer forces a restart this bug apperears and requires a full machine reboot.

### Primary monitor switches to Windows just fine but secondary stays black
> If you are using a KVM switch like I am then it's possible that
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
- Fedora 35 Workstation
- Gnome
- Pipewire
- Wayland
- SELinux enabled

<br>

## Hardware
- Gigabyte B550 AORUS Pro
- AMD Ryzen R5 3600
- AMD Radeon Vega 64 (to be passed through)
- AMD Radeon R5 240 OEM (as the replacement gpu when the Vega is passed through)

<br>

## Monitor Setup
- Monitor 1 plugged into Vega 64
- Monitor 2 plugged into a KVM switch that is plugged into both the Vega and R5 240

The reasoning behind this rather weird configuration is that I want
to be able to access Linux even when the VM is booted, so only my primary Monitor
gets stolen by the VM. The advantage of this is that I don't have to trust Windows
to handle Discord and other applications, so it can focus solely on the game I am running and hopefully do less weird things.

So my setup seemlessly* transitions from being a dual monitor Linux setup to
a one monitor Linux, one monitor Windows setup.

*: It's obviously not completely seemless since gdm needs to be restarted on every GPU handover. And I need to press
    the switch button on my KVM switch.

<br>

## UEFI Setup (Gigabyte B550 Aorus Pro)
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

- `amd_iommu=on` : for full virtualization
- `rd.driver.pre=vfio-pci` : force loading vfio-pci

> ### /etc/default/grub (required)
> ```
> GRUB_CMDLINE_LINUX="rhgb quiet amd_iommu=on rd.driver.pre=vfio-pci"
> ```

> ### /etc/default/grub (my config)
> ```
> GRUB_CMDLINE_LINUX="rhgb quiet preempt=full amd_iommu=on rd.driver.pre=vfio-pci systemd.unified_cgroup_hierarchy=1 crashkernel=auto"
> ```

<br>

## Permanent Claims

I have my both my GPU HDMI-Audio devices permanently claimed, since i don't use them anyways.
That also ensures that all needed vfio kernel modules are permanently loaded.

> ### /etc/modprobe.d/vfio.conf
> ```
> options vfio-pci ids=VEGA_AUDIO_DEVICE_ID,R5_240_VIDEO_DEVICE_ID,R5_240_AUDIO_DEVICE_ID
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
>	Kernel driver in use: vfio-pci
>	Kernel modules: snd_hda_intel
>
> -- snip --
> ```

**Don't forget to run `dracut -fv` or equivalent afterwards.**

<br>

## Session Restore

I use a tool called [gnome-session-restore](https://github.com/Clueliss/gnome-session-restore) (also written by me) to restore
my gnome session after getting logged out by the VM being started or stopped. Since I found it annoying that I had to
start every application by hand afterwards.

<br>
