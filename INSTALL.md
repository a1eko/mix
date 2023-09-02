MiX Installation Manual
=======================

System requirements
-------------------

* MiX is tested on x86_64 architecture.

* The core system is about 3 GB (4.3 GB with sources and tools) and
needs 15 GB of the disk space to build.

* Host system should be relatively up-to-date. This distribution is
known to build successfully in a *stable* Debian environment, with GNU
`awk` instead of the default `mawk` installed and `/bin/sh` linked to
`bash`. Development packages should be available too.

* Installation is done by a non-privileged user with `sudo` rights.

* Active network connection is assumed throughout the process.


Installing MiX
--------------

Mount empty Linux partition on `/mnt`. Set the target directory `MIX`.

	export MIX=/mnt

Build and install the base system.

	./install.sh

Mount virtual file systems and enter `chroot`.

	sudo mount --bind /dev $MIX/dev
	sudo mount -vt devpts devpts $MIX/dev/pts -o gid=5,mode=620
	sudo mount -vt proc proc $MIX/proc
	sudo mount -vt sysfs sysfs $MIX/sys
	sudo mount -vt tmpfs tmpfs $MIX/run

	sudo chroot "$MIX" /usr/bin/env -i \
	  HOME=/root TERM=$TERM PS1='\u-in-chroot:\w\$ ' \
	  PATH=/bin:/usr/bin:/sbin:/usr/sbin \
	  /bin/bash --login

Set password for user *root*.

	passwd root

Add user *build*. 

	useradd -m -u 1000 -g users -G floppy,audio,video,cdrom,wheel -s /bin/bash build
	passwd build

User *build* must be a member of the group *wheel* to be able to execute
`sudo` commands. Run `visudo` to configure *sudo*.

	visudo

Make user *build* the owner of the build sources.

	chown -R build {/usr,/var/log}/sources

Add regular users.

Edit `/etc/config.site`. Set default values of `CFLAGS`, `CXXFLAGS` and
`MAKEFLAGS` if needed.

Edit `/etc/fstab` to set correct values for devices and filesystem types
(for example, `/dev/sda9`, `ext3`, etc.). Uncomment `swap` and `/boot`
instances, if applicable.

Inspect file `/etc/rc.conf` and set variables `FONT`, `KEYMAP`, `TIMEZONE`
and `HOSTNAME`. The array variable `SERVICES` contains names of the
service scripts from the directory `/etc/rc.d` to start automatically
in the multi-user runlevel.

Edit scripts `net` and `wlan` in the directory `/etc/rc.d` to be used
for setting up the network.

Edit `/etc/host.conf`, `/etc/hosts` and `/etc/resolv.conf` files. File
`/etc/resolv.conf` will be configured automatically if dynamic IP is used.


### Making the system bootable ###

#### Build the kernel ####

Inspect package *linux* in `/usr/packages`. To adjust kernel to the local
hardware, a user-defined file `config.local` is used. This configuration
file defines additional options or overwrites default options generated
for the current architecture by the automatic kernel configuration
procedure. Edit `config.local` and install the new kernel.

	pkz build linux
	pkz install linux

The next step is to set up the system bootloader.

**NOTE:** Instructions in the followup section are optional and refer to
the first-time installation of the bootloader. Here a non-UEFI bootloader
`extlinux` for legacy BIOS booting is considered. If `extlinux` or any
other bootloader on a multiboot host computer is used already, adjust
its configuration files, exit *chroot* and skip to *Rebooting*.


#### Setting up the legacy BIOS boot process ####

Install the bootloader (`extlinux` is a part of the collection of the
bootloaders `syslinux`).

	pkz -f install nasm syslinux

Create configuration file `extlinux.conf`.

	cat > /boot/extlinux/extlinux.conf << EOF
	prompt 1
	timeout 50
	totaltimeout 9000
	default mix
	label mix
	      kernel /vmlinuz-mix
	      append root=/dev/XXXN ro
	label debian
	      kernel /vmlinuz-NNN-amd64
	      append root=/dev/YYYN initrd=/initrd.img-NNN-amd64 ro quiet
	EOF

Edit `extlinux.conf` to specify correct values for `label`, `kernel`,
`root` and `initrd` options (`/dev/sda9`, etc.).

Exit *chroot*.

	logout

**WARNING:** In this example, `extlinux` installs to the master boot
record (MBR) of the disk. This overwrites an existing bootloader. Errors
in the commands below can make the system unbootable.

Become user *root*

	su

Find MBR image `mbr.bin` in `syslinux` directories within the `$MIX`
tree and install it to the hard drive. Specify boot device appropriately,
e.g. `/dev/sda`

	cat mbr.bin > /dev/XXX

Find `extlinux` binary under `$MIX/sbin/` and run the installer.
Installer runs on a mounted filesystem.

	./extlinux --install /boot/extlinux 

That's it.


### Rebooting ###

Exit *root*.

	exit

If the `/boot` directory is on a separate partition, copy installed
files from `$MIX/boot` to the actual destination `/boot`.

Unmount virtual file systems and the target directory.

    cd
	sudo umount -v $MIX/dev{/pts,}
	sudo umount -v $MIX/{sys,proc,run}

	sudo umount -v $MIX
	unset MIX

Backup important files, prepare a rescue media.

Reboot the system ...


Setting up the new system
-------------------------

Start `net` or `wlan` script.

	sudo /etc/rc.d/net start

**NOTE:** Inspect and configure packages *iproute2*, *dhcpcd* and
*wpa_supplicant* to get it working. See also optional *ca-certificates*,
*net-tools* and *wireless_tools*. Wireless network cards may require
firmware to be loaded from `/lib/firmware` and *wpa_supplicant*
get started before invocation of the `net` script (`wlan` starts
*wpa_supplicant* automaticaly).

Clean up the package trees.

	sudo pkz clean

Delete unneeded files in `/usr/sources` (nothing is required by the
system).

Get the CRUX ports and build the rest of the system. Ports can be copied
to `/usr/packages` without the leading subdirectories `core/`, `opt/`
etc. Use `*.mix` files from `mix/sources/` for building optional packages
in proper order. Be careful with toolchain packages: *binutils*, *gcc*,
*glibc*, and *linux-headers* don't need to be upgraded. CRUX package
*filesystem* also installs only once. Often *perl* is difficult to
upgrade and it is better to keep the installed version. MiX
packages from the `mix/ports/` directory should replace corresponding
CRUX ports. It is recommended to overwrite them in `/usr/packages` to
avoid confusion.  MiX and CRUX packages are to be upgraded regularly to
keep the system up-to-date.

Alexander Kozlov <akozlov@kth.se>  
