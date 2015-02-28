#!/bin/bash

P=$(pwd)
cd /tmp
rm -f .listing* index.html*
echo Using mirrors:
for m in ftp://trumpetti.atm.tut.fi/gentoo/distfiles ftp://ftp.kernel.org/pub/linux/kernel/v3.x; do
  echo $m
  wget -q --no-remove-listing $m/
  awk '{ print $9 }' .listing >> .listing-tmp
done
echo
sort -u .listing-tmp > .listing-files
if [ -d $P/ports ]; then
  for p in $P/ports/*; do
    source $p/Pkgfile
    echo $name $version-$release:
    grep "^$name" .listing-files
    echo
  done
fi
rm -f .listing* index.html*
