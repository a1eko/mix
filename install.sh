#!/bin/bash -e

cat > /dev/stdout << EOF

#
# MiX Installation
#

EOF

test -n "$MIX"
test "$MIX" != '/'
test $(id -u) != 0
sudo -v

MIX_TGT=$(uname -m)-mix-linux-gnu
MIX_TST=${MIX_TST-no}
MIX_SRC=${MIX_SRC-yes}
MIX_CLEAN=${MIX_CLEAN-yes}

echo MIX_TGT=$MIX_TGT
echo MIX_TST=$MIX_TST
echo MIX_SRC=$MIX_SRC
echo MIX_CLEAN=$MIX_CLEAN

test "$MIX_TST" = no && export TST=:

P=$MIX/usr/packages

BASE1="iana-etc glibc lzip tzdata zlib bzip2 xz zstd readline m4 \
  bc flex tcl expect dejagnu binutils libgmp libmpfr libmpc linux-firmware \
  attr acl libcap linux-pam shadow gcc"

BASE2="ncurses sed psmisc gettext bison grep bash libtool gdbm \
  gperf tar expat inetutils less perl autoconf automake file openssl kmod elfutils \
  libffi python3 python3-setuptools python3-wheel meson coreutils check diffutils gawk findutils groff \
  gzip kbd libpipeline make patch man-pages man-db texinfo vim \
  eudev procps util-linux e2fsprogs sysklogd sysvinit sudo rc"

BIOS_BOOT="nasm syslinux"
UEFI_BOOT="libpng freetype libdevmapper grub2 grub2-efi efivar efibootmgr"
BOOT="$BIOS_BOOT $UEFI_BOOT"
KERNEL=linux

toolsh="env -i MIX=$MIX PKZ=$MIX PKZCONF=$MIX/usr/sources/pkz.conf \
  CONFIG_SITE=$MIX/usr/sources/config.site \
  MIX_TGT=$MIX_TGT HOME=$HOME TERM=linux LC_ALL=C \
  PATH=$MIX/tools/bin:/bin:/usr/bin \
  /bin/bash -e +h -c"

JOBS=$(nproc)
MAKEFLAGS="-j${JOBS-1}"

chrootsh="sudo chroot $MIX /usr/bin/env -i \
  PKZCONF=/usr/sources/pkz.conf HOME=/root TERM=linux LC_ALL=C \
  CONFIG_SITE=/usr/sources/config.site \
  ${MAKEFLAGS+"MAKEFLAGS=$MAKEFLAGS"} \
  PATH=/bin:/usr/bin:/sbin:/usr/sbin \
  /bin/bash -e +h -c"

cat > /dev/stdout << EOF

#
# Toolchain building environment
#

EOF

sudo chown $USER $MIX
sudo chown -Rf $USER $MIX/[a-km-z]* $MIX/lib* || true

mkdir -pv $MIX/{bin,etc{,/cron.d},lib,sbin,usr,var}
case $(uname -m) in
  x86_64)
    mkdir -pv $MIX{,/usr}/lib
    ln -sv lib $MIX/lib64
    ln -sv lib $MIX/usr/lib64
    ;;
esac

mkdir -pv $MIX/tools
mkdir -pv $MIX/usr/{packages,sources}
mkdir -pv $MIX/{tools/bin,var/log/{packages,sources}}
cp -r sources $MIX/usr/
rsync -rqz crux.nu::ports/crux-3.7/core/ $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.7/opt/ $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.7/contrib/check $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.7/contrib/tcl $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.7/contrib/lynx $MIX/usr/packages
cp -r {ports,tools}/* $MIX/usr/packages/
sed -e 's/pkginfo -i/pkz -i list/g' \
    -e 's/prt-get isinst/pkz -i list/g' \
    -i $MIX/usr/packages/*/{Pkgfile,*-install}
rm -f $MIX/usr/packages/C*

sudo ln -sfv $MIX/tools /
echo | gzip -c > $MIX/var/log/packages/dummy.gz

install -v -m 755 -D $MIX/usr/packages/pkz/pkz.sh $MIX/usr/bin/pkz
ln -sfv ../../usr/bin/pkz $MIX/tools/bin/

cat > $MIX/usr/sources/config.site << EOF
enable_nls=no
EOF

cat > $MIX/usr/sources/pkz.conf << EOF
TST="$TST"
EOF

if [ "$MIX_CLEAN" = no ]; then
  cat >> $MIX/usr/sources/pkz.conf << EOF
clean_pkgbin=no
EOF
fi

if [ "$MIX_SRC" = yes ]; then
  $toolsh "pkz source $BASE1 $BASE2 $KERNEL $BOOT"
  $toolsh "pkz source include $MIX/usr/sources/coreopt.mix"

  $toolsh "pkz -p $P/binutils-mixtool-pass1 source binutils"
  $toolsh "pkz -p $P/gcc-mixtool-pass1      source gcc"
  $toolsh "pkz -p $P/linux-headers-mixtool  source linux-headers"
  $toolsh "pkz -p $P/glibc-mixtool          source glibc"
  $toolsh "pkz -p $P/gcc-mixtool-libstdcxx source gcc"

  $toolsh "pkz -p $P/m4-mixtool         source m4"
  $toolsh "pkz -p $P/ncurses-mixtool    source ncurses"
  $toolsh "pkz -p $P/bash-mixtool       source bash"
  $toolsh "pkz -p $P/coreutils-mixtool  source coreutils"
  $toolsh "pkz -p $P/diffutils-mixtool  source diffutils"
  $toolsh "pkz -p $P/file-mixtool       source file"
  $toolsh "pkz -p $P/findutils-mixtool  source findutils"
  $toolsh "pkz -p $P/gawk-mixtool       source gawk"
  $toolsh "pkz -p $P/grep-mixtool       source grep"
  $toolsh "pkz -p $P/gzip-mixtool       source gzip"
  $toolsh "pkz -p $P/make-mixtool       source make"
  $toolsh "pkz -p $P/patch-mixtool      source patch"
  $toolsh "pkz -p $P/sed-mixtool        source sed"
  $toolsh "pkz -p $P/tar-mixtool        source tar"
  $toolsh "pkz -p $P/xz-mixtool         source xz"

  $toolsh "pkz -p $P/binutils-mixtool-pass2 source binutils"
  $toolsh "pkz -p $P/gcc-mixtool-pass2      source gcc"

  $toolsh "pkz -p $P/pkgconf-mixtool source pkgconf"
  $toolsh "pkz -p $P/cmake-mixtool source cmake"
  $toolsh "pkz -p $P/ninja-mixtool source ninja"

  $toolsh "pkz -p $P/gettext-mixtool    source gettext"
  $toolsh "pkz -p $P/bison-mixtool      source bison"
  $toolsh "pkz -p $P/perl-mixtool       source perl"
  $toolsh "pkz -p $P/python3-mixtool    source python3"
  $toolsh "pkz -p $P/texinfo-mixtool    source texinfo"
  $toolsh "pkz -p $P/util-linux-mixtool source util-linux"
fi

cat > /dev/stdout << EOF

#
# Making tools
#

EOF

$toolsh "pkz -p $P/binutils-mixtool-pass1 -f install binutils"
$toolsh "pkz -p $P/gcc-mixtool-pass1      -f install gcc"
$toolsh "pkz -p $P/linux-headers-mixtool  -f install linux-headers"
$toolsh "pkz -p $P/glibc-mixtool          -f install glibc"

$toolsh "pkz -p $P/binutils-mixtool-pass1 clean binutils"
$toolsh "pkz -p $P/gcc-mixtool-pass1      clean gcc"
$toolsh "pkz -p $P/linux-headers-mixtool  clean linux-headers"
$toolsh "pkz -p $P/glibc-mixtool          clean glibc"

$toolsh "
  echo 'int main(){}' | $MIX_TGT-gcc -x c -
  readelf -l a.out | grep '/ld-linux'
  rm a.out
"

$toolsh "
  $MIX/tools/libexec/gcc/$MIX_TGT/*/install-tools/mkheaders
"

$toolsh "pkz -p $P/gcc-mixtool-libstdcxx -f install gcc"
$toolsh "pkz -p $P/gcc-mixtool-libstdcxx clean gcc"

$toolsh "pkz -p $P/m4-mixtool         -f install m4"
$toolsh "pkz -p $P/ncurses-mixtool    -f install ncurses"
$toolsh "pkz -p $P/bash-mixtool       -f install bash"
$toolsh "pkz -p $P/coreutils-mixtool  -f install coreutils"
$toolsh "pkz -p $P/diffutils-mixtool  -f install diffutils"
$toolsh "pkz -p $P/file-mixtool       -f install file"
$toolsh "pkz -p $P/findutils-mixtool  -f install findutils"
$toolsh "pkz -p $P/gawk-mixtool       -f install gawk"
$toolsh "pkz -p $P/grep-mixtool       -f install grep"
$toolsh "pkz -p $P/gzip-mixtool       -f install gzip"
$toolsh "pkz -p $P/make-mixtool       -f install make"
$toolsh "pkz -p $P/patch-mixtool      -f install patch"
$toolsh "pkz -p $P/sed-mixtool        -f install sed"
$toolsh "pkz -p $P/tar-mixtool        -f install tar"
$toolsh "pkz -p $P/xz-mixtool         -f install xz"

$toolsh "pkz -p $P/m4-mixtool         clean m4"
$toolsh "pkz -p $P/ncurses-mixtool    clean ncurses"
$toolsh "pkz -p $P/bash-mixtool       clean bash"
$toolsh "pkz -p $P/coreutils-mixtool  clean coreutils"
$toolsh "pkz -p $P/diffutils-mixtool  clean diffutils"
$toolsh "pkz -p $P/file-mixtool       clean file"
$toolsh "pkz -p $P/findutils-mixtool  clean findutils"
$toolsh "pkz -p $P/gawk-mixtool       clean gawk"
$toolsh "pkz -p $P/grep-mixtool       clean grep"
$toolsh "pkz -p $P/gzip-mixtool       clean gzip"
$toolsh "pkz -p $P/make-mixtool       clean make"
$toolsh "pkz -p $P/patch-mixtool      clean patch"
$toolsh "pkz -p $P/sed-mixtool        clean sed"
$toolsh "pkz -p $P/tar-mixtool        clean tar"
$toolsh "pkz -p $P/xz-mixtool         clean xz"

$toolsh "pkz -p $P/binutils-mixtool-pass2 -f install binutils"
$toolsh "pkz -p $P/gcc-mixtool-pass2      -f install gcc"

$toolsh "pkz -p $P/binutils-mixtool-pass2 clean binutils"
$toolsh "pkz -p $P/gcc-mixtool-pass2      clean gcc"

$toolsh "pkz -p $P/pkgconf-mixtool -f install pkgconf"
$toolsh "pkz -p $P/cmake-mixtool -f install cmake"
$toolsh "pkz -p $P/ninja-mixtool -f install ninja"

$toolsh "pkz -p $P/pkgconf-mixtool clean pkgconf"
$toolsh "pkz -p $P/cmake-mixtool clean cmake"
$toolsh "pkz -p $P/ninja-mixtool clean ninja"

sudo chown -R root:root $MIX
sudo chown -R $USER $MIX/{usr,var/log}/sources

sudo mkdir -pv $MIX/{dev,proc,sys,run}
sudo mknod -m 600 $MIX/dev/console c 5 1
sudo mknod -m 666 $MIX/dev/null c 1 3
sudo mount -v --bind /dev $MIX/dev
sudo mount -v --bind /dev/pts $MIX/dev/pts
sudo mount -vt proc proc $MIX/proc
sudo mount -vt sysfs sysfs $MIX/sys
sudo mount -vt tmpfs tmpfs $MIX/run
if [ -h $MIX/dev/shm ]; then
  sudo mkdir -pv $MIX/$(readlink $MIX/dev/shm)
fi

sudo bash -c "echo export JOBS=$JOBS >> $MIX/usr/sources/pkz.conf"
sudo bash -c "echo 127.0.0.1 localhost $(hostname) > $MIX/etc/hosts"

$chrootsh "pkz install filesystem"
$chrootsh "pkz clean   filesystem"

$chrootsh "rm -v /etc/{issue,os-release} /usr/bin/crux"
$chrootsh "rm -v /var/log/packages/dummy.gz"
$chrootsh "ln -sv share/man /usr/man"
$chrootsh "
  touch /var/log/{btmp,lastlog,faillog,wtmp}
  chmod -v 664 /var/log/lastlog
  chmod -v 600 /var/log/btmp
"

$chrootsh "pkz -p /usr/packages/gettext-mixtool    -f install gettext"
$chrootsh "pkz -p /usr/packages/bison-mixtool      -f install bison"
$chrootsh "pkz -p /usr/packages/perl-mixtool       -f install perl"
$chrootsh "pkz -p /usr/packages/python3-mixtool    -f install python3"
$chrootsh "pkz -p /usr/packages/texinfo-mixtool    -f install texinfo"
$chrootsh "pkz -p /usr/packages/util-linux-mixtool -f install util-linux"

$chrootsh "pkz -p /usr/packages/gettext-mixtool    clean gettext"
$chrootsh "pkz -p /usr/packages/bison-mixtool      clean bison"
$chrootsh "pkz -p /usr/packages/perl-mixtool       clean perl"
$chrootsh "pkz -p /usr/packages/python3-mixtool    clean python3"
$chrootsh "pkz -p /usr/packages/texinfo-mixtool    clean texinfo"
$chrootsh "pkz -p /usr/packages/util-linux-mixtool clean util-linux"

$chrootsh "find /usr/{lib,libexec} -name \*.la -delete"

echo tool system built in $MIX

cat > /dev/stdout << EOF

#
# Base system building environment
#

EOF

mkdir -pv $MIX/usr/sources/tools
sudo mv $MIX/usr/packages/*-mixtool{,-*} $MIX/usr/sources/tools/

sudo rm -r $MIX/tools
sudo rm -v /tools

cat > /dev/stdout << EOF

#
# Building base system
#

EOF

$chrootsh "pkz -f install $BASE1"
$chrootsh "pkz clean $BASE1"

$chrootsh "
  cd /usr/sources
  echo 'main(){}' | cc -v -x c -Wl,--verbose - &> dummy.log
  readelf -l a.out | grep ': /lib'
  grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
  grep -B4 '^ /usr/include' dummy.log
  grep ' /lib.*/libc.so.6 succeeded' dummy.log
  grep 'found ld-linux.*.so.2 at /lib.*/ld-linux.*.so.2' dummy.log
  grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g' > dummy2.log
  grep 'SEARCH_DIR(\"/usr/lib\")' dummy2.log
  grep 'SEARCH_DIR(\"/lib\")' dummy2.log
  rm -f a.out dummy{,2}.log
"

cat >> $MIX/usr/sources/pkz.conf << EOF
strip_static=--strip-debug
strip_shared=--strip-unneeded
strip_binaries=--strip-all
EOF

cat >> $MIX/usr/sources/config.site << 'EOF'
test -z "$CFLAGS" && export CFLAGS="-O2 -pipe -mtune=native" || true
test -z "$CXXFLAGS" && export CXXFLAGS="$CFLAGS" || true
EOF

$chrootsh "pkz -f install $BASE2"
$chrootsh "pkz clean $BASE2"

echo base system built in $MIX

cat > /dev/stdout << EOF

#
# Building optional core packages
#

EOF

$chrootsh "pkz -f install include /usr/sources/coreopt.mix"
$chrootsh "pkz clean include /usr/sources/coreopt.mix"

$chrootsh "cat > /etc/config.site << 'EOF'
test -z \"\$CFLAGS\" && export CFLAGS=\"-O2 -pipe -mtune=native\" || true
test -z \"\$CXXFLAGS\" && export CXXFLAGS=\"\$CFLAGS\" || true
EOF
"

echo core system built in $MIX

$chrootsh "find /usr -depth -name $(uname -m)-mix-linux-gnu\* | xargs rm -rf"

sudo umount -v $MIX/dev{/pts,}
sudo umount -v $MIX/{sys,proc,run}

cat > /dev/stdout << EOF

$0 done.

EOF
