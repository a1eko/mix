#!/bin/bash

M=(ftp://trumpetti.atm.tut.fi/gentoo/distfiles
   ftp://ftp.kernel.org/pub/linux/kernel/v3.x) 
S=/var/log/sources/pkgmon.log
T=/tmp/pkgmon.log
P=$(pwd)

cd /tmp
rm -f .listing* index.html*
for m in ${M[@]}; do
  wget -q --no-remove-listing $m/
  awk '{ print $9 }' .listing >> .listing-tmp
done
sort -u .listing-tmp > .listing-files
if [ -d $P/ports ]; then
  for p in $P/ports/*; do
    source $p/Pkgfile
    echo $name $version-$release:
    grep "^$name" .listing-files
    echo
  done > $T
fi
rm -f .listing* index.html*
touch $S
comm -13 <(sort $S) <(sort $T)
if [ "$1" = update ]; then
  cp -bv $T $S
fi
