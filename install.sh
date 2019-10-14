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
MIX_TST=${MIX_TST-yes}
MIX_DIST=${MIX_DIST-no}
if [ "$MIX_DIST" = yes ]; then
  MIX_TOOLS=no
  MIX_CORE=yes
  MIX_CORE_CLEAN=yes
fi
MIX_TOOLS=${MIX_TOOLS-yes}
MIX_CORE=${MIX_CORE-yes}
MIX_CORE_CLEAN=${MIX_CORE_CLEAN-yes}

echo MIX_TGT=$MIX_TGT
echo MIX_TST=$MIX_TST
echo MIX_TOOLS=$MIX_TOOLS
echo MIX_CORE=$MIX_CORE
echo MIX_CORE_CLEAN=$MIX_CORE_CLEAN
echo MIX_DIST=$MIX_DIST

test "$MIX_TST" = no && export TST=:

P=$MIX/usr/packages

BASE1="linux-headers glibc lzip tzdata"
BASE2="zlib file readline m4 bc binutils libgmp libmpfr libmpc shadow gcc"
BASE3="bzip2 pkg-config ncurses attr acl libcap sed psmisc iana-etc bison \
  flex grep bash libtool gdbm gperf expat inetutils perl tcl expect \
  dejagnu check autoconf automake xz kmod gettext elfutils libffi openssl python3 \
  coreutils diffutils gawk findutils groff less gzip kbd libpipeline linux-firmware \
  make man-pages patch man-db tar texinfo vim procps util-linux e2fsprogs \
  sudo sysklogd sysvinit eudev"

BOOT="linux nasm syslinux rc"

cat > /dev/stdout << EOF

#
# Toolchain building environment
#

EOF

sudo chown $USER $MIX
mkdir -pv sources
mkdir -pv $MIX/usr/{packages,sources}
mkdir -pv $MIX/{tools/bin,var/log/{packages,sources}}
cp -r sources $MIX/usr/
rsync -rqz crux.nu::ports/crux-3.5/core/ $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.5/opt/ $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.5/contrib/tcl $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.5/contrib/lynx $MIX/usr/packages
cp -r {ports,tools}/* $MIX/usr/packages/
rm -f $MIX/usr/packages/C*

sudo ln -sfv $MIX/tools /
echo | gzip -c > $MIX/var/log/packages/dummy.gz

sudo install -v -m 755 -D $MIX/usr/packages/pkz/pkz.sh $MIX/usr/bin/pkz
ln -sv ../../usr/bin/pkz $MIX/tools/bin/

cat > $MIX/usr/sources/pkz.conf << EOF
TST="$TST"
EOF

cat > $MIX/usr/sources/config.site << EOF
enable_nls=no
EOF

toolsh="env -i MIX=$MIX PKZ=$MIX PKZCONF=$MIX/usr/sources/pkz.conf \
  CONFIG_SITE=$MIX/usr/sources/config.site \
  MIX_TGT=$MIX_TGT HOME=$HOME TERM=linux LC_ALL=C \
  PATH=/tools/bin:/bin:/usr/bin \
  /bin/bash -e +h -c"

if [ "$MIX_DIST" != yes ]; then
  $toolsh "pkz source $BASE1 $BASE2 $BASE3 $BOOT"
  $toolsh "pkz source include $MIX/usr/sources/coreopt.mix"
fi

cat > /dev/stdout << EOF

#
# Making tools
#

EOF

if [ "$MIX_TOOLS" = yes ]; then  # MIX_TOOLS [

$toolsh "pkz -p $P/binutils-mixtool-pass1 -f install binutils"
$toolsh "pkz -p $P/gcc-mixtool-pass1      -f install gcc"
$toolsh "pkz -p $P/linux-headers-mixtool  -f install linux-headers"
$toolsh "pkz -p $P/glibc-mixtool          -f install glibc"

$toolsh "pkz -p $P/binutils-mixtool-pass1 clean binutils"
$toolsh "pkz -p $P/gcc-mixtool-pass1      clean gcc"
$toolsh "pkz -p $P/linux-headers-mixtool  clean linux-headers"
$toolsh "pkz -p $P/glibc-mixtool          clean glibc"

$toolsh "
  echo 'main(){}' | $MIX_TGT-gcc -x c -
  readelf -l a.out | grep ': /tools'
  rm a.out
"

$toolsh "pkz -p $P/gcc-mixtool-libstdcxx  -f install gcc"
$toolsh "pkz -p $P/binutils-mixtool-pass2 -f install binutils"
$toolsh "pkz -p $P/gcc-mixtool-pass2      -f install gcc"

$toolsh "pkz -p $P/gcc-mixtool-libstdcxx  clean gcc"
$toolsh "pkz -p $P/binutils-mixtool-pass2 clean binutils"
$toolsh "pkz -p $P/gcc-mixtool-pass2      clean gcc"

$toolsh "
  echo 'main(){}' | cc -x c -
  readelf -l a.out | grep ': /tools'
  rm a.out
"

$toolsh "pkz -p $P/tcl-mixtool     -f install tcl"
$toolsh "pkz -p $P/expect-mixtool  -f install expect"
$toolsh "pkz -p $P/dejagnu-mixtool -f install dejagnu"

$toolsh "pkz -p $P/tcl-mixtool     clean tcl"
$toolsh "pkz -p $P/expect-mixtool  clean expect"
$toolsh "pkz -p $P/dejagnu-mixtool clean dejagnu"

$toolsh "pkz -p $P/m4-mixtool         -f install m4"
$toolsh "pkz -p $P/ncurses-mixtool    -f install ncurses"
$toolsh "pkz -p $P/bash-mixtool       -f install bash"
$toolsh "pkz -p $P/bison-mixtool      -f install bison"
$toolsh "pkz -p $P/bzip2-mixtool      -f install bzip2"
$toolsh "pkz -p $P/coreutils-mixtool  -f install coreutils"
$toolsh "pkz -p $P/diffutils-mixtool  -f install diffutils"
$toolsh "pkz -p $P/file-mixtool       -f install file"
$toolsh "pkz -p $P/findutils-mixtool  -f install findutils"
$toolsh "pkz -p $P/gawk-mixtool       -f install gawk"
$toolsh "pkz -p $P/gettext-mixtool    -f install gettext"
$toolsh "pkz -p $P/grep-mixtool       -f install grep"
$toolsh "pkz -p $P/gzip-mixtool       -f install gzip"
$toolsh "pkz -p $P/make-mixtool       -f install make"
$toolsh "pkz -p $P/patch-mixtool      -f install patch"
$toolsh "pkz -p $P/perl-mixtool       -f install perl"
$toolsh "pkz -p $P/python3-mixtool    -f install python3"
$toolsh "pkz -p $P/sed-mixtool        -f install sed"
$toolsh "pkz -p $P/tar-mixtool        -f install tar"
$toolsh "pkz -p $P/texinfo-mixtool    -f install texinfo"
$toolsh "pkz -p $P/xz-mixtool         -f install xz"

$toolsh "pkz -p $P/ncurses-mixtool    clean ncurses"
$toolsh "pkz -p $P/bash-mixtool       clean bash"
$toolsh "pkz -p $P/bison-mixtool      clean bison"
$toolsh "pkz -p $P/bzip2-mixtool      clean bzip2"
$toolsh "pkz -p $P/coreutils-mixtool  clean coreutils"
$toolsh "pkz -p $P/diffutils-mixtool  clean diffutils"
$toolsh "pkz -p $P/file-mixtool       clean file"
$toolsh "pkz -p $P/findutils-mixtool  clean findutils"
$toolsh "pkz -p $P/gawk-mixtool       clean gawk"
$toolsh "pkz -p $P/gettext-mixtool    clean gettext"
$toolsh "pkz -p $P/grep-mixtool       clean grep"
$toolsh "pkz -p $P/gzip-mixtool       clean gzip"
$toolsh "pkz -p $P/m4-mixtool         clean m4"
$toolsh "pkz -p $P/make-mixtool       clean make"
$toolsh "pkz -p $P/patch-mixtool      clean patch"
$toolsh "pkz -p $P/perl-mixtool       clean perl"
$toolsh "pkz -p $P/python3-mixtool    clean python3"
$toolsh "pkz -p $P/sed-mixtool        clean sed"
$toolsh "pkz -p $P/tar-mixtool        clean tar"
$toolsh "pkz -p $P/texinfo-mixtool    clean texinfo"
$toolsh "pkz -p $P/xz-mixtool         clean xz"

( cd / && tar czf $MIX/usr/sources/tools.tar.gz tools/* )

echo tool system built in $MIX

fi  # MIX_TOOLS ]

sudo rm -r $MIX/usr/packages/*-mixtool{,-*}
sudo rm $MIX/var/log/packages/dummy.gz

cat > /dev/stdout << EOF

#
# Base system building environment
#

EOF

if [ "$MIX_CORE" = yes ]; then  # MIX_CORE [

if [ "$MIX_DIST" = yes ]; then
    sudo tar -C $MIX -xf $MIX/usr/sources/tools.tar.gz
fi

sudo chown -R root:root $MIX
sudo chown -R $USER $MIX/{usr,var/log}/sources

sudo mkdir -pv $MIX/{dev,proc,sys,run}
sudo mknod -m 600 $MIX/dev/console c 5 1
sudo mknod -m 666 $MIX/dev/null c 1 3
sudo mount -v --bind /dev $MIX/dev
sudo mount -vt devpts devpts $MIX/dev/pts -o gid=5,mode=620
sudo mount -vt proc proc $MIX/proc
sudo mount -vt sysfs sysfs $MIX/sys
sudo mount -vt tmpfs tmpfs $MIX/run
if [ -h $MIX/dev/shm ]; then
  sudo mkdir -pv $MIX/$(readlink $MIX/dev/shm)
fi

MAKEFLAGS="-j$(getconf _NPROCESSORS_ONLN)"

chrootsh="sudo chroot $MIX /tools/bin/env -i \
  PKZCONF=/usr/sources/pkz.conf HOME=/root TERM=linux LC_ALL=C \
  ${MAKEFLAGS+"MAKEFLAGS=$MAKEFLAGS"} \
  PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
  /tools/bin/bash -e +h -c"

if [ "$MIX_CORE_CLEAN" != yes ]; then
    $chrootsh "echo clean_pkgbin=no >> /usr/sources/pkz.conf"
fi

$chrootsh "
  mkdir -pv /bin
  mkdir -pv /usr/lib
"

$chrootsh "
  ln -sv /tools/bin/{bash,cat,chmod,dd,echo,ln,imkdir,pwd,rm,stty,touch} /bin
  ln -sv /tools/bin/{env,install,perl} /usr/bin
  ln -sv /tools/lib/libgcc_s.so{,.1} /usr/lib
  ln -sv /tools/lib/libstdc++.so{,.6} /usr/lib
  ln -sv bash /bin/sh
"

$chrootsh "pkz install filesystem"
$chrootsh "pkz clean   filesystem"
$chrootsh "rm /etc/issue /usr/bin/crux"
$chrootsh "ln -sv share/man /usr/man"

$chrootsh "
  touch /var/log/{btmp,lastlog,faillog,wtmp}
  chmod -v 664 /var/log/lastlog
  chmod -v 600 /var/log/btmp
"

$chrootsh "
  echo 127.0.0.1 localhost $(hostname) > /etc/hosts
"

cat > /dev/stdout << EOF

#
# Building base system
#

EOF

$chrootsh "pkz -f install $BASE1"
$chrootsh "pkz clean $BASE1"

$chrootsh "
  mv -v /tools/bin/{ld,ld-old}
  mv -v /tools/$($chrootsh 'uname -m')-pc-linux-gnu/bin/{ld,ld-old}
  mv -v /tools/bin/{ld-new,ld}
  ln -sv /tools/bin/ld /tools/$($chrootsh 'uname -m')-pc-linux-gnu/bin/ld
"

SPECS=$(dirname $($chrootsh 'gcc --print-libgcc-file-name'))/specs
$chrootsh "gcc -dumpspecs" | sed -e 's@/tools@@g' \
  -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
  -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' \
  > $MIX/tmp/specs
$chrootsh "cd /tmp; cp -v specs $SPECS"
unset SPECS

$chrootsh "
  cd /usr/sources
  echo 'main(){}' | cc -v -x c -Wl,--verbose - &> dummy.log
  readelf -l a.out | grep ': /lib'
  grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
  grep -B1 '^ /usr/include' dummy.log
  grep ' /lib.*/libc.so.6 succeeded' dummy.log
  grep 'found ld-linux.*.so.2 at /lib.*/ld-linux.*.so.2' dummy.log
  grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g' > dummy2.log
  grep 'SEARCH_DIR(\"/usr/lib\")' dummy2.log
  grep 'SEARCH_DIR(\"/lib\")' dummy2.log
  rm -f a.out dummy{,2}.log
"

$chrootsh "pkz -f install $BASE2"
$chrootsh "pkz clean $BASE2"

$chrootsh "
  cd /usr/sources
  echo 'main(){}' | cc -v -x c -Wl,--verbose - &> dummy.log
  readelf -l a.out | grep ': /lib'
  grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
  grep -B4 '^ /usr/include' dummy.log
  grep ' /lib.*/libc.so.6 succeeded' dummy.log
  grep 'found ld-linux.*.so.2 at /lib.*/ld-linux.*.so.2' dummy.log
  grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g' > dummy2.log
  grep 'SEARCH_DIR(\"/usr/.*-linux-gnu/lib.*\")' dummy2.log
  grep 'SEARCH_DIR(\"/usr/local/lib.*\")' dummy2.log
  grep 'SEARCH_DIR(\"/usr/lib.*\")' dummy2.log
  grep 'SEARCH_DIR(\"/lib.*\")' dummy2.log
  rm -f a.out dummy{,2}.log
"

cat >> $MIX/usr/sources/pkz.conf << EOF
strip_shared=--strip-debug
strip_static=--strip-debug
strip_binaries=--strip-unneeded
EOF

cat >> $MIX/usr/sources/config.site << 'EOF'
test -z "$CFLAGS" && export CFLAGS="-O2 -pipe -mtune=native" || true
test -z "$CXXFLAGS" && export CXXFLAGS="$CFLAGS" || true
EOF

$chrootsh "pkz -f install $BASE3"
$chrootsh "pkz clean $BASE3"

echo base system built in $MIX

cat > /dev/stdout << EOF

#
# Building boot system
#

EOF

$chrootsh "pkz -f install $BOOT"
$chrootsh "pkz clean $BOOT"

echo boot system built in $MIX

cat > /dev/stdout << EOF

#
# Building optional core packages
#

EOF

$chrootsh "pkz -f install include /usr/sources/coreopt.mix"
$chrootsh "pkz clean include /usr/sources/coreopt.mix"

$chrootsh "
  install -v -m 700 -o root -g sys -d /var/lib/sshd
  groupadd -g 50 sshd
  useradd -c 'privacy separation' -d /var/lib/sshd -g sshd -s /bin/false -u 50 sshd
"

$chrootsh "cat > /etc/config.site << 'EOF'
test -z \"\$CFLAGS\" && export CFLAGS=\"-O2 -pipe -mtune=native\" || true
test -z \"\$CXXFLAGS\" && export CXXFLAGS=\"\$CFLAGS\" || true
test -z \"\$MAKEFLAGS\" && export MAKEFLAGS=\"-j4\" || true
EOF
"

echo core system built in $MIX

sudo rm -v /tools
sudo rm -r $MIX/tools
sudo umount -v $MIX/dev/pts
sudo umount -v $MIX/dev
sudo umount -v $MIX/run
sudo umount -v $MIX/proc
sudo umount -v $MIX/sys

fi  # MIX_CORE ]

cat > /dev/stdout << EOF

#
# $0 done.

EOF
