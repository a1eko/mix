#!/bin/bash

M=(http://trumpetti.atm.tut.fi/gentoo/distfiles/
   http://www.kernel.org/pub/linux/kernel/v5.x/
   http://crux.nu/files/distfiles/)
S=/var/log/sources/pkgmon.log
T=/tmp/pkgmon.log
P=$(pwd)

monitor() {
  cd /tmp
  rm -f .listing* index.html*
  for m in ${M[@]}; do
    wget -qO- $m | fmt -w1 | grep href= | cut -d'"' -f2 >> .listing-tmp
  done
  wget -qO- https://pypi.python.org/pypi?%3Aaction=index \
    | grep 'href="/pypi/' | cut -d'"' -f2 \
    | sed -e 's,/pypi/,,'i -e 's,/,-,' \
    >> .listing-tmp
  lynx -source "http://www.linuxfromscratch.org/lfs/downloads/development/wget-list" > wget-list
  for f in $(cat wget-list); do
      basename $f >> .listing-tmp
  done
  sort -u .listing-tmp > .listing-files
  if [ -d $P/ports ]; then
    for p in $P/ports/*; do
      if [ -e $p/Pkgfile ]; then
        source $p/Pkgfile
        echo $name $version-$release:
        grep "^$name" .listing-files
        echo
      fi
    done > $T
  fi
  rm -f .listing* index.html* wget-list
  touch $S
  comm -13 <(sort $S) <(sort $T)
}

if [ "$1" = update ]; then
  test -f $T || monitor
  cp -bv $T $S
else
  monitor
fi
