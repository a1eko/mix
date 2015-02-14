MiX Installation Manual
=======================

System requirements
-------------------

* A 32-bit CPU i686 or higher is required. MiX is tested on x86_64
architecture.

* The core system is about 400 MB (1 GB with sources) and needs 5 GB of
the disk space to build.

* Host system should be relatively up-to-date. This distribution is
known to build successfully in a *stable* Debian environment, with GNU
`awk` instead of the default `mawk` installed. Development packages
should be available too.

* Installation is done by a non-privileged user with `sudo` rights.

* Active network connection is assumed throughout the process.


Installing MiX
--------------

Mount Linux partition on `/mnt`. Set target directory `MIX`, optionally
disable running test suites, build and install the base system.

	export MIX=/mnt
	export TST=:
	./install.sh

Mount virtual file systems and enter `chroot`.

	sudo mount --bind /dev $MIX/dev
	sudo mount -vt devpts devpts $MIX/dev/pts -o gid=5,mode=620
	sudo mount -vt proc proc $MIX/proc
	sudo mount -vt sysfs sysfs $MIX/sys
	sudo mount -vt tmpfs tmpfs $MIX/run

	sudo chroot "$MIX" /usr/bin/env -i \
	  HOME=/root TERM=linux PS1='\u-in-chroot:\w\$ ' \
	  PATH=/bin:/usr/bin:/sbin:/usr/sbin \
	  /bin/bash --login

Set password for user *root*.

	passwd root

Add user *build*. User *build* must be a member of the group *wheel*
to be able to execute `sudo` commands.

	useradd -m -g users -G floppy,audio,video,cdrom,wheel -s /bin/bash build
	passwd build

	chown -R build /usr/bin/pkgz
	chown -R build /usr/{packages,sources}
	chown -R build /var/log/{packages,sources}

Add regular users.

Edit `/etc/config.site`. Set default values of `CFLAGS`, `CXXFLAGS`
and `MAKEFLAGS`.

Edit `/etc/fstab` to set correct values for devices and filesystem
types (for example, `/dev/sda9`, `ext3`, etc.). Uncomment `swap`
and `/boot` instances, if applicable.

Inspect file `/etc/rc.conf` and set variables `FONT`, `KEYMAP`, `TIMEZONE`
and `HOSTNAME`. The array variable `SERVICES` will contain names of the
service scripts from the directory `/etc/rc.d` to start automatically
in the multi-user runlevel.

Edit script `net` in the directory `/etc/rc.d` to set up wired network.

Edit `/etc/host.conf`, `/etc/hosts` and `/etc/resolv.conf` files. File
`/etc/resolv.conf` will be configured automatically if dynamic IP is used.


### Making the system bootable ###

Inspect package *linux*. A default kernel has been installed
already. Adjust configuration in `local.config` and reinstall the kernel,
if necessary.

	pkz build linux
	pkz -f install linux

Set up the system bootloader.

**NOTE:** Instructions in this section are optional and refer to
the first-time installation of `extlinux`. If `extlinux` or any other
bootloader is used already, adjust its configuration files, exit *chroot*
and skip to *Rebooting*.

Create configuration file `extlinux.conf`.

	cat > /boot/extlinux/extlinux.conf << EOF
	prompt 1
	timeout 30
	totaltimeout 3000
	default mix
	label mix
	      kernel /vmlinuz-mix
	      append root=/dev/XXXN ro
	label debian
	      kernel /vmlinuz-2.6.38-2-amd64
	      append root=/dev/YYYN initrd=/initrd.img-2.6.38-2-amd64 ro quiet
	EOF

Edit `extlinux.conf` to specify correct values for `label`, `kernel`, `root`
and `initrd` options (`/dev/sda9`, etc.).

Exit *chroot*.

	logout

**WARNING:** In this example, `extlinux` installs to the master boot record
(MBR) of the disk. This overwrites an existing bootloader. Errors in
the commands below can make the system unbootable.

Become user *root*

	su

Find MBR image `mbr.bin` in `syslinux` directories within the `$MIX`
tree and install it to the hard drive. Specify boot device appropriately,
e.g. `/dev/sda`

	cat mbr.bin > /dev/XXX

Find `extlinux` binary under `$MIX/sbin/` and run the installer.
Installer runs on a mounted filesystem.

	./extlinux --install /boot/extlinux 

Exit *root*.

	exit

That's it.


### Rebooting ###

If the `/boot` directory is on a separate partition, copy installed
files from `$MIX/boot` to the actual destination `/boot`.

Unmount virtual file systems and the target directory.

	sudo umount -v $MIX/dev/pts
	sudo umount -v $MIX/dev
	sudo umount -v $MIX/run
	sudo umount -v $MIX/proc
	sudo umount -v $MIX/sys

	sudo umount -v $MIX
	unset MIX

Backup important files, prepare a rescue media.

Reboot the system ...


Setting up the new system
-------------------------

Start `net` or `wifi` script.

	sudo /etc/rc.d/net start

Inspect and configure packages *iproute2*, *dhcpcd* and
*wpa_supplicant* to get it working. See also optional *net-tools* and
*wireless_tools*. Wireless network cards may require firmware to be
loaded from `/lib/firmware`.

Clean up the package trees.

	sudo pkz clean

Delete unneeded files in `/usr/sources`.

Get the CRUX ports and build the rest of the system. Be careful with
the toolchain packages: *binutils*, *gcc*, *glibc* and *linux-headers*
don't need to be upgraded.
