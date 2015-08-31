#!/bin/bash

M=(ftp://trumpetti.atm.tut.fi/gentoo/distfiles
   ftp://ftp.kernel.org/pub/linux/kernel/v3.x) 
S=/var/log/sources/pkgmon.log
T=/tmp/pkgmon.log
P=$(pwd)

monitor() {
  cd /tmp
  rm -f .listing* index.html*
  for m in ${M[@]}; do
    wget -q --no-remove-listing $m/
    awk '{ print $9 }' .listing >> .listing-tmp
  done
  wget -q -O - https://pypi.python.org/pypi?%3Aaction=index \
    | grep 'href="/pypi/' | cut -d'"' -f2 \
    | sed -e 's,/pypi/,,'i -e 's,/,-,' \
    >> .listing-tmp
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
}

if [ "$1" = update ]; then
  test -f $T || monitor
  cp -bv $T $S
else
  monitor
fi
