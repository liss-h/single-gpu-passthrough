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

- **Related:** If you **don't** want to use [gnome-session-restore](https://github.com/Clueliss/gnome-session-restore) remove or comment out the lines mentioning it.

- If you **don't** use the `pipewire` audio server edit the lines mentioning `pipewire` and `pipewire-pulse` accordingly.

- If you have more than two files in `/sys/class/vtconsole` you need to add additional lines where they are mentioned.

<br>

## Creating the Directory Structure
Create this directory structure based with the provided files.
**Replace `YOUR_VM_NAME` with the actual name of your VM.**

```cs
📦/etc/libvirt
|__📁hooks
|  |__⚙️kvm.conf
|  |__📃qemu
|  |__📁qemu.d
|  |  |__📁YOUR_VM_NAME
|  |  |  |__📁prepare
|  |  |  |  |__📁begin
|  |  |  |  |  |__📃start.sh
|  |  |  |__📁release
|  |  |  |  |__📁end
|  |  |  |  |  |__📃stop.sh
```

<br>

## Installing driver-rebind.sh
For the scripts to work you need to copy driver-rebind.sh to a directory in your $PATH and rename it to driver-rebind, this is typically
done by.

> ### install ./driver-rebind.sh /usr/local/bin/driver-rebind

<br>

## Troubleshooting

### Primary monitor switches to Windows just fine but secondary stays black
> If you are using a KVM switch like I am then it's possible that
> if you press the switch button too slowly, the secondary GPU won't initialize properly, since it thinks there is no
> display connected. So to solve that just press the switch button faster, like immediatly after
> beginning to start the VM or ideally before.

### Race conditions
> There are a few places in `start.sh` and `stop.sh` where artitficial delays are 
> inserted via `sleep` to avoid race conditions, if the handover isn't working correctly
> you could try increasing these values. I personally haven't extensively tested how low I can go
> on these, since it works and once in my life I convinced myself that I should not touch a running system.

### Xorg/X11 weirdness: startup issues
> If for some reason Xorg does not want to start up after the VM stole the GPU
> but always works when the GPU is given back
> you might want to try setting your primary GPU 
> (aka. the first GPU to output to a display) to your secondary GPU in the BIOS.


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
- Monitor 2 plugged into a KVM switch that is plugged into both the Vega and HD 5450

The reasoning behind this rather weird configuration is that I want
to be able to access Linux even when the VM is booted, so only my primary Monitor
gets stolen by the VM. The advantage of this is that I don't have to trust Windows
to handle Discord and other applications, so it can focus solely on the game I am running and hopefully do less weird things.

So my setup seemlessly* transitions from being a dual monitor Linux setup to
a one monitor Linux, one monitor Windows setup.

*: It's obviously not completely seemless since gdm needs to be restarted on every GPU handover. And I need to press
    the switch button on my KVM switch.

<br>

## Groups
My user is in the following groups

- `input` : for evdev passthrough
- `kvm`, `qemu`, `libvirt` : for general vm stuff

<br>

## Kernel parameters

- `amd_iommu=on` : for full virtualization
- `rd.driver.pre=vfio-pci` : force loading vfio-pci

> ### /etc/default/grub
> ```
> GRUB_CMDLINE_LINUX="rhgb quiet amd_iommu=on rd.driver.pre=vfio-pci"
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

> ### lspci -nnv
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

I use a tool called [gnome-session-restore](https://github.com/Clueliss/gnome-session-restore) to restore
my gnome session after getting logged out by the VM being started or stopped. Since I found it annoying that I had to
start every application by hand afterwards.

<br>

## VM Configuration

I added the XML for my VM for reference.
Most notably it has **CPU Pinning**, **[Looking Glass](https://looking-glass.io) shm**, **Keyboard/Mouse EVDev Passthrough** and **[Scream](https://github.com/duncanthrax/scream) over Ethernet** configured.
(I actually don't use [Looking Glass](https://looking-glass.io/) I just tried it out and was too lazy to remove the shm device after I found a better setup).
