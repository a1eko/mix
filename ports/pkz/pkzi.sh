#!/bin/bash

VERSION=0.1exp

: ${PKZ=''}

ROOT=${PKZROOT-$PKZ}
#zconf=${PKZCONF-$PKZ/etc/pkz.conf}
#zsources=${PKZSOURCES-$PKZ/usr/sources}
zpackages=${PKZPACKAGES-$PKZ/usr/packages}
zregs=${PKZREGS-$PKZ/var/log/packages}
#zbuilds=${PKZBUILDS-$PKZ/var/log/sources}

pkgbin=
pkgbuild=
pkgcont=
pkgdir=
pkgfile=
pkgreg=
pkgsum=
pkgwork=

PKG=
SRC=

name=
version=
release=
source=()
build() { :; }

formatted_output=no
list_notinstalled=no
list_installed=no
list_updated=no
list_all=yes

usage() {
  cat << EOF 
Usage: 	pkzi [options] <command> [<packages>]
EOF
}

help() {
  usage
  cat << EOF 
Package metadata viewer.

Options:
  -h, --help		help
  -V, --version		version
  -md			markdown formatted output
  -p path		packages directory [/usr/packages]

Command:
  list			show available packages

Packages:
  <name> [<name2> ...]	package name or list of packages
  inclide <file>	file with list of packages
EOF
}

error() {
  local err=$?
  test $err -eq 0 && err=1
  echo pkzi error: ${1-'?'}
  exit $err
}

message() {
  local n=
  test "$1" = "-n" && n=$1 && shift
  echo $n $name $revision: $*
}

installed() {
  local ver
  if [ -f $pkgreg.gz ]; then
    echo "(installed)"
  elif [ -f $zregs/$name#* ]; then
    ver=$(echo $(basename $zregs/$name#* .gz) | cut -d'#' -f2)
    echo "($ver)"
  fi
}

do_list() {
  if [ $formatted_output = yes ]; then
    if [ $list_all = yes \
      -o $list_installed = yes -a "$(installed)" = '(installed)' \
      -o $list_updated = yes -a "$(installed)" != '(installed)' -a "$(installed)" != '' \
      -o $list_notinstalled = yes -a "$(installed)" = '' ]; then
      echo "* [$name]($pkgdir) $version-$release $(eval installed) -$(grep Description: $pkgfile | cut -d: -f2)"
    fi
  else
    if [ $list_all = yes -o \
      $list_installed = yes -a "$(installed)" = '(installed)' \
      -o $list_updated = yes -a "$(installed)" != '(installed)' -a "$(installed)" != '' \
      -o $list_notinstalled = yes -a "$(installed)" = '' ]; then
      echo $name $version-$release $(eval installed) -$(grep Description: $pkgfile | cut -d: -f2)
    fi
  fi
}


test $# -eq 0 && usage && exit
while true; do
  case "$1" in
    -h | --help) help && exit ;;
    -V | --version) echo $VERSION && exit ;;
    -md) formatted_output=yes ;;
    -n) list_notinstalled=yes; list_all=no ;;
    -i) list_installed=yes; list_all=no ;;
    -u) list_updated=yes; list_all=no ;;
    -a) list_all=yes ;;
    -p) shift; test -d "$1" && zpackages=$(cd $1; pwd) || error "no directory $1" ;;
    *) break ;;
  esac
  shift
done

test $# -eq 0 && set list
case $1 in 
  list) cmd=$1; shift ;;
  *) error "unknown command $1" ;;
esac

#test -r $zconf && source $zconf
test $cmd = list -a $# -eq 0 && set $(cd $zpackages; ls)

while [ $# -gt 0 ]; do
  test "$1" = include -a -f "$2" && shift && set $(cat $1 | grep -v "^#")
  patt="$1"
  if ls -d $zpackages/*${patt}* &>/dev/null; then
    for d in $(ls -d $zpackages/*${patt}*); do
      pkgdir=$d
      pkgfile=$pkgdir/Pkgfile
      test -d $pkgdir || error "no directory $pkgdir"
      test -f $pkgfile || error "no file $pkgfile"
      source $pkgfile 
      revision=$version-$release
      pkgreg=$zregs/$name#$revision
      do_$cmd
      shift
    done
  else
    shift
  fi
done
