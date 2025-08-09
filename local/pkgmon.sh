#!/bin/bash

M=(http://www.kernel.org/pub/linux/kernel/v6.x/
  http://crux.nu/files/distfiles/)
S=/var/log/sources/pkgmon.log
T=/tmp/pkgmon.log
P=$(pwd)

dist_files() {
  local url=$1
  wget -qO- $url | fmt -w1 | grep href= | grep -v http \
    | grep -e "\.tar\." -e zip -e patch -e diff | cut -d'"' -f2 \
    | grep -v -e '.asc$' -e '.sign$' -e '.sig$'
}

monitor() {
  cd /tmp
  rm -f .listing* index.html* distfiles-list

  echo -n "monitoring "

  for m in ${M[@]}; do
    echo -n "$m... "
    wget -qO- $m | fmt -w1 | grep href= | cut -d'"' -f2 >>.listing-tmp
  done

  pypi=https://pypi.python.org/
  echo -n "$pypi... "
  wget -qO- $pypi/pypi?%3Aaction=index \
    | grep 'href="/pypi/' | cut -d'"' -f2 \
    | sed -e 's,/pypi/,,'i -e 's,/,-,' \
      >>.listing-tmp

  lfs=http://www.linuxfromscratch.org/
  echo -n "$lfs... "
  if [ ! -e /tmp/wget-list ]; then
    wget -q --timeout=5 $lfs/lfs/downloads/development/wget-list || (echo no /tmp/wget-list && exit)
  fi

  dist=https://distfiles.gentoo.org/distfiles/
  echo -n "$dist..."
  dirs=$(wget -qO- $dist | fmt -w1 | grep href= | grep -v https | cut -d'"' -f2 | grep -E '^../')
  for d in $dirs; do
    dist_files $dist/$d &
  done >>distfiles-list
  wait

  basename -a $(cat wget-list distfiles-list) >>.listing-tmp
  sort -u .listing-tmp >.listing-files
  echo " done"

  if [ -d $P/ports ]; then
    for p in $P/ports/*; do
      if [ -e $p/Pkgfile ]; then
        source $p/Pkgfile
        echo $name $version-$release:
        grep "^$name[-_]" .listing-files
        echo
      fi
    done >$T
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
