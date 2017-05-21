#!/bin/bash -e
#
# MiX Installation
# ================
#
# Alexander Kozlov <akozlov@kth.se>
#

test -n "$MIX"
test "$MIX" != '/'
test $(id -u) != 0
test "$MIX_TST" != no || export TST=:
sudo -v

#
# Toolchain building environment
#

sudo chown $USER $MIX
mkdir -pv sources
mkdir -pv $MIX/usr/{packages,sources}
mkdir -pv $MIX/{tools/bin,var/log/{packages,sources}}
cp -r sources $MIX/usr/
rsync -rqz crux.nu::ports/crux-3.2/core/ $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.2/opt/ $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.2/opt/linux-firmware $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.2/contrib/tcl $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.2/contrib/lynx $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.2/contrib/libvpx $MIX/usr/packages
rsync -rqz crux.nu::ports/crux-3.2/contrib/rtmpdump $MIX/usr/packages
cp -r {ports,tools}/* $MIX/usr/packages/
rm -f $MIX/usr/packages/C*

sudo ln -sfv $MIX/tools /
echo | gzip -c > $MIX/var/log/packages/dummy.gz

MIX_TGT=$(uname -m)-mix-linux-gnu

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

P=$MIX/usr/packages

BASE1="linux-headers glibc tzdata"
BASE2="zlib file m4 binutils libgmp libmpfr libmpc gcc"
BASE3="bzip2 pkg-config ncurses attr acl libcap sed shadow psmisc \
  iana-etc bison flex grep readline bash bc libtool gdbm gperf \
  inetutils perl tcl expect dejagnu check autoconf automake xz kmod \
  gettext procps e2fsprogs coreutils diffutils gawk findutils groff less \
  gzip kbd libpipeline make man-pages patch sudo sysklogd sysvinit eudev \
  util-linux man-db tar texinfo vim"

BOOT="linux nasm syslinux rc"

$toolsh "pkz source $BASE1 $BASE2 $BASE3 $BOOT"
$toolsh "pkz source include $MIX/usr/sources/coreopt.mix"

#
# Making tools
#

$toolsh "pkz -p $P/binutils-tool-pass1 -f install binutils"
$toolsh "pkz -p $P/gcc-tool-pass1      -f install gcc"
$toolsh "pkz -p $P/linux-headers-tool  -f install linux-headers"
$toolsh "pkz -p $P/glibc-tool          -f install glibc"

$toolsh "pkz -p $P/binutils-tool-pass1 clean binutils"
$toolsh "pkz -p $P/gcc-tool-pass1      clean gcc"
$toolsh "pkz -p $P/linux-headers-tool  clean linux-headers"
$toolsh "pkz -p $P/glibc-tool          clean glibc"

$toolsh "
  echo 'main(){}' | $MIX_TGT-gcc -x c -
  readelf -l a.out | grep ': /tools'
  rm a.out
"

$toolsh "pkz -p $P/gcc-tool-libstdcxx  -f install gcc"
$toolsh "pkz -p $P/binutils-tool-pass2 -f install binutils"
$toolsh "pkz -p $P/gcc-tool-pass2      -f install gcc"

$toolsh "pkz -p $P/gcc-tool-libstdcxx  clean gcc"
$toolsh "pkz -p $P/binutils-tool-pass2 clean binutils"
$toolsh "pkz -p $P/gcc-tool-pass2      clean gcc"

$toolsh "
  echo 'main(){}' | cc -x c -
  readelf -l a.out | grep ': /tools'
  rm a.out
"

$toolsh "pkz -p $P/tcl-tool     -f install tcl"
$toolsh "pkz -p $P/expect-tool  -f install expect"
$toolsh "pkz -p $P/dejagnu-tool -f install dejagnu"
$toolsh "pkz -p $P/check-tool   -f install check"

$toolsh "pkz -p $P/tcl-tool     clean tcl"
$toolsh "pkz -p $P/expect-tool  clean expect"
$toolsh "pkz -p $P/dejagnu-tool clean dejagnu"
$toolsh "pkz -p $P/check-tool   clean check"

$toolsh "pkz -p $P/ncurses-tool    -f install ncurses"
$toolsh "pkz -p $P/bash-tool       -f install bash"
$toolsh "pkz -p $P/bison-tool      -f install bison"
$toolsh "pkz -p $P/bzip2-tool      -f install bzip2"
$toolsh "pkz -p $P/coreutils-tool  -f install coreutils"
$toolsh "pkz -p $P/diffutils-tool  -f install diffutils"
$toolsh "pkz -p $P/file-tool       -f install file"
$toolsh "pkz -p $P/findutils-tool  -f install findutils"
$toolsh "pkz -p $P/gawk-tool       -f install gawk"
$toolsh "pkz -p $P/gettext-tool    -f install gettext"
$toolsh "pkz -p $P/grep-tool       -f install grep"
$toolsh "pkz -p $P/gzip-tool       -f install gzip"
$toolsh "pkz -p $P/m4-tool         -f install m4"
$toolsh "pkz -p $P/make-tool       -f install make"
$toolsh "pkz -p $P/patch-tool      -f install patch"
$toolsh "pkz -p $P/perl-tool       -f install perl"
$toolsh "pkz -p $P/sed-tool        -f install sed"
$toolsh "pkz -p $P/tar-tool        -f install tar"
$toolsh "pkz -p $P/texinfo-tool    -f install texinfo"
$toolsh "pkz -p $P/util-linux-tool -f install util-linux"
$toolsh "pkz -p $P/xz-tool         -f install xz"

$toolsh "pkz -p $P/ncurses-tool    clean ncurses"
$toolsh "pkz -p $P/bash-tool       clean bash"
$toolsh "pkz -p $P/bzip2-tool      clean bzip2"
$toolsh "pkz -p $P/coreutils-tool  clean coreutils"
$toolsh "pkz -p $P/diffutils-tool  clean diffutils"
$toolsh "pkz -p $P/file-tool       clean file"
$toolsh "pkz -p $P/findutils-tool  clean findutils"
$toolsh "pkz -p $P/gawk-tool       clean gawk"
$toolsh "pkz -p $P/gettext-tool    clean gettext"
$toolsh "pkz -p $P/grep-tool       clean grep"
$toolsh "pkz -p $P/gzip-tool       clean gzip"
$toolsh "pkz -p $P/m4-tool         clean m4"
$toolsh "pkz -p $P/make-tool       clean make"
$toolsh "pkz -p $P/patch-tool      clean patch"
$toolsh "pkz -p $P/perl-tool       clean perl"
$toolsh "pkz -p $P/sed-tool        clean sed"
$toolsh "pkz -p $P/tar-tool        clean tar"
$toolsh "pkz -p $P/texinfo-tool    clean texinfo"
$toolsh "pkz -p $P/util-linux-tool clean util-linux"
$toolsh "pkz -p $P/xz-tool         clean xz"

( cd / && tar czf $MIX/usr/sources/tools.tar.gz tools/* )

sudo rm -r $MIX/usr/packages/*-tool{,-*}
sudo rm $MIX/var/log/packages/dummy.gz
sudo chown -R root:root $MIX
sudo chown -R $USER $MIX/{usr,var/log}/sources

#
# Base system building environment
#

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

$chrootsh "
  mkdir -pv /bin
  mkdir -pv /usr/lib
"

$chrootsh "
  ln -sv /tools/bin/{bash,cat,dd,echo,ln,pwd,rm,stty} /bin
  ln -sv /tools/bin/{install,perl} /usr/bin
  ln -sv /tools/lib/libgcc_s.so{,.1} /usr/lib
  ln -sv /tools/lib/libstdc++.so{,.6} /usr/lib
  sed 's/tools/usr/' /tools/lib/libstdc++.la > /usr/lib/libstdc++.la
  ln -sv bash /bin/sh
"

$chrootsh "pkz install filesystem"
$chrootsh "rm /etc/issue /usr/bin/crux"
$chrootsh "ln -sv ../man /usr/share/man"

$chrootsh "
  touch /var/log/{btmp,lastlog,faillog,wtmp}
  chgrp -v utmp /var/log/lastlog
  chmod -v 664 /var/log/lastlog
  chmod -v 600 /var/log/btmp
"

$chrootsh "
  echo 127.0.0.1 localhost $(hostname) > /etc/hosts
"

#
# Building base system
#

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

$chrootsh "pkz -f install $BOOT"
$chrootsh "pkz clean $BOOT"

$chrootsh "
  install -v -m 700 -o root -g sys -d /var/lib/sshd
  groupadd -g 50 sshd
  useradd -c 'privacy separation' -d /var/lib/sshd -g sshd -s /bin/false -u 50 sshd
"

$chrootsh "pkz install include /usr/sources/coreopt.mix"
$chrootsh "pkz clean include /usr/sources/coreopt.mix"

$chrootsh "cat > /etc/config.site << 'EOF'
test -z \"\$CFLAGS\" && export CFLAGS=\"-O2 -pipe -mtune=native\" || true
test -z \"\$CXXFLAGS\" && export CXXFLAGS=\"\$CFLAGS\" || true
test -z \"\$MAKEFLAGS\" && export MAKEFLAGS=\"-j4\" || true
EOF
"

sudo rm -v /tools
sudo rm -r $MIX/tools
sudo umount -v $MIX/dev/pts
sudo umount -v $MIX/dev
sudo umount -v $MIX/run
sudo umount -v $MIX/proc
sudo umount -v $MIX/sys

echo Base system built in $MIX
