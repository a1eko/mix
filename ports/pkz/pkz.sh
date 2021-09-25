#!/bin/bash

: ${PKZ=''}

ROOT=${PKZROOT-$PKZ}
zconf=${PKZCONF-$PKZ/etc/pkz.conf}
zsources=${PKZSOURCES-$PKZ/usr/sources}
zpackages=${PKZPACKAGES-$PKZ/usr/packages}
zregs=${PKZREGS-$PKZ/var/log/packages}
zbuilds=${PKZBUILDS-$PKZ/var/log/sources}

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

forced_exec=no
compress_manuals=yes
strip_shared=
strip_static=
strip_binaries=
use_mirror=
suggest_pkgs=no
resolve_deps=yes
clean_pkgbin=yes

list_notinstalled=no
list_installed=no
list_updated=no
list_all=yes
list_url=no

GZIP=$(command -v pigz)
GZIP=${GZIP:-gzip}

usage() {
  cat << EOF 
Usage: 	pkz [options] <command> <packages>
       	pkz [-h|--help]
EOF
}

help() {
  usage
  cat << EOF 
Package manager for scripted source-based distribution.

Options:
  -h, --help		help
  -f			forced execution
  -c conf		configuration file [/etc/pkz.conf]
  -p path		packages directory [/usr/packages]
  -s path		sources directory [/usr/sources]
  -a			show all packages (list)
  -i			show installed packages (list)
  -n			show not-installed packages (list)
  -u			show updated packages (list)
  -l			show source URL of packages (list)
  -o			include optional dependencies (resolve, provide, depend)

Command:
  clean			delete working directory
  source		populate source directory
  build			make binary package
  install		install binary package
  remove		uninstall binary package
  upgrade		upgrade binary package
  list			show packages
  provide		show provided packages
  depend		show dependencies
  resolve		show unresolved dependencies

Packages:
  <name> [<name> ...]	package name or list of packages
  inclide <file>	file with list of packages
EOF
}

error() {
  local err=$?
  test $err -eq 0 && err=1
  echo pkz error: ${1-'?'}
  exit $err
}

message() {
  local n=
  test "$1" = "-n" && n=$1 && shift
  echo $n $name $revision: $*
}

standard_files() {
  echo \
    {,usr/{,local/}}lib64 etc/{group,mtab,passwd} \
    usr/{,local/}{doc,info,man} usr/local/share/man \
    var/{lock,run} var/log/{btmp,lastlog,wtmp} \
  | tr ' ' '\n'
}

standard_dirs() {
  echo \
    {bin,boot,dev,home,lib{,/firmware},media,mnt,opt}/ \
    {proc,root,run,sbin,srv,sys,tmp}/ \
    etc/ etc/{X11,init.d,rc.d,opt,sgml,sysconfig,xml}/ \
    usr/ usr/{X11R6,libexec}/ usr/{,local/}{bin,doc,include,info,lib,sbin,src}/ \
    usr/{,local/}share/{color,dict,doc,info,locale,misc,terminfo,zoneinfo}/ \
    usr/{,local/{,share/}}man/man{1..9}/ usr/share/{sgml,xml}/ \
    var/ var/{account,cache,crash,games,local,log,mail,opt,spool,tmp,yp}/ \
    var/lib/ var/lib/{color,hwclock,misc,locate}/ var/spool/{cron,lpd,rwho}/ \
  | tr ' ' '\n'
}

compress_files() {
  local d f
  for d in $(find "$1" -type d -wholename "$2"); do
    find $d -type f | xargs $GZIP &>/dev/null
    for f in $(find $d -type l); do
      ln -sf $(readlink $f).gz $f.gz
      rm -f $f
    done
  done
}

strip_objects() {
  local f
  find $PKG -type f -perm -u+w 2>/dev/null | while read f ; do
    case $(file -bi $f) in
      *application/x-sharedlib*)
        test -n "$strip_shared" && strip $strip_shared $f ;;
      *application/x-archive*)
        test -n "$strip_static" && strip $strip_static $f ;;
      *application/x-executable*)
        test -n "$strip_binaries" && strip $strip_binaries $f ;;
    esac
  done
}

do_clean() {
  rm -rf $pkgwork
  test "$clean_pkgbin" = yes && rm -f $pkgbin
}

do_source() {
  local f s
  mkdir -p $SRC $PKG
  if [ ${#source[*]} -gt 0 ]; then
    for s in ${source[*]}; do
      f=$(basename $s)
      if [ ! -f $SRC/$f ]; then
        if [ -f $pkgdir/$f ]; then
          ln -Lf $pkgdir/$f $SRC
        else
          if [ -f $zsources/$f ]; then
            ln -sf $zsources/$f $SRC
  	  else
	    message -n "fetching $s ..."
	    ( cd /tmp
	      rm -f $(basename $s)*
	        (wget -q -t 3 $s && mv $(basename $s) $zsources/) \
		  || ( test -n "$use_mirror" && \
		       ( rm -f $(basename $s)*
		         ( wget -nv $use_mirror/$(basename $s) \
			     && mv $(basename $s) $zsources/
		         )
		       )
		     )
	    ) || error "cannot fetch $(basename $s)"
	    echo \ done
	    if [ -f $pkgsum ]; then
	      grep -qw "$(cd $zsources; md5sum $f)" $pkgsum \
	        || error "md5sum failed"
	    fi
            ln -sf $zsources/$f $SRC
          fi
        fi
      fi
    done
  fi
}

do_build() { 
  local f
  mkdir -p $SRC $PKG
  rm -rf $SRC/* $PKG/*
  cd $SRC
  if [ ${#source[*]} -gt 0 ]; then
    do_source 
      for s in ${source[*]}; do
      f=$(basename $s)
      case $f in 
        *.tar | *.tar.* | *.tbz2 | *.tbz | *.tgz | *.txz)
          tar --no-same-owner -xf $f || error "corrupt source $f" ;;
        *.zip | *.ZIP)
          unzip -q $f ;;
      esac
    done
  fi
  test ! -f $pkgdir/pre-install || bash -e $pkgdir/pre-install \
    || error "pre-install failed"
  message -n "building ..."
  set -E; trap 'error "build failed"' ERR
  time -p (build > pkgbuild) >> pkgbuild 2>&1
  set +E; trap - ERR
  du -sk $PKG | cut -f1 | sed "s/^/size /" >> pkgbuild
  $GZIP -c pkgbuild > $pkgbuild.gz
  test $compress_manuals = yes && compress_files $PKG '*/man/man*'
  test -n "$strip_shared""$strip_static""$strip_binaries" \
    -a ! -e $pkgdir/.nostrip && strip_objects
  (cd $PKG; tar --sort=name -cf - . | $GZIP -c > $SRC/pkgbin) || error "packaging failed"
  tar tvvf pkgbin | awk '{if(NR>1) print $1, $2, $6, $7, $8, $9}' \
    | sed -e 's/ /\t/' -e 's/ \.\//\t/' -e 's/  *$//' > pkgcont
  mv -f pkgbin $pkgbin && mv -f pkgcont $pkgcont \
    || error "package placement failed"
  echo \ done
  zcat $pkgbuild.gz | tail -n4 | grep -e real -e size \
    | sed -e "s/real/$name $revision: build time/" \
          -e "s/size/$name $revision: build &/"
  rm -rf $PKG/*
}

do_install() {
  test -w $ROOT/ || error "permission denied"
  mkdir -p $pkgwork
  cd $pkgwork
  if [ ! -f $pkgreg.gz -o $forced_exec = yes ]; then
    if [ ! -f $zregs/$name#*.gz -o $forced_exec = yes ]; then
      test -f $pkgbin -a -f $pkgcont || do_build
      if [ ! $forced_exec = yes ]; then
        cat  $pkgcont    | grep -v "^d" | awk '{print $3}' | sort -u \
	  > package_files$$
        zcat $zregs/*.gz | grep -v "^d" | awk '{print $3}' | sort -u \
	  > installed_files$$
        comm -12 package_files$$ installed_files$$ > conflict_files$$
        test -s conflict_files$$ && cat conflict_files$$ \
	  && error "package conflict"
      fi
      tar tf $pkgbin &> /dev/null || error "corrupt binary"
      tar xf $pkgbin -C $ROOT/ -h || error "installation failed"
      rm -f *_files$$ *_dirs$$
      rm -f $zregs/$name#*.gz
      $GZIP -c $pkgcont > $pkgreg.gz
      message "installed"
      test ! -f $pkgdir/post-install || bash -e $pkgdir/post-install \
        || error "post-install failed"
      if ls $pkgdir/*README* &>/dev/null; then
        cat $pkgdir/*README* | sed 's/^/# /'
      fi
    else
      message "another release installed, skipping"
    fi
  else
    message "installed already, ignored"
  fi
}

do_remove() {
  local f
  test -w $ROOT/ || error "permission denied"
  mkdir -p $pkgwork
  cd $pkgwork
  if [ -f $pkgreg.gz ]; then
    zcat $pkgreg.gz | grep -v "^d" | awk '{print $3}' | sort -u \
      > package_files$$
    zcat $pkgreg.gz | grep    "^d" | awk '{print $3}' | sort -u \
      > package_dirs$$
    if [ ! $forced_exec = yes ]; then
      mv $pkgreg.gz{,.bak}
      zcat $zregs/*.gz | grep -v "^d" | awk '{print $3}' > installed_files$$
      zcat $zregs/*.gz | grep    "^d" | awk '{print $3}' > installed_dirs$$
      mv $pkgreg.gz{.bak,}
    else
      touch installed_files$$ installed_dirs$$
    fi
    standard_files > standard_files$$
    standard_dirs  > standard_dirs$$
    cat standard_files$$ installed_files$$ | sort -u > preserve_files$$
    cat standard_dirs$$  installed_dirs$$  | sort -u > preserve_dirs$$
    comm -23 --nocheck-order package_files$$ preserve_files$$ > delete_files$$
    comm -23 --nocheck-order package_dirs$$ preserve_dirs$$ > delete_dirs$$
    cat delete_files$$ | while read f; do rm -f $ROOT/$f; done
    cat delete_dirs$$ | sort -r \
      | while read f; do rmdir --ignore-fail-on-non-empty $ROOT/$f; done
    rm -f *_files$$ *_dirs$$
    rm -f $pkgreg.gz
    message "removed"
  else
    message "not installed, ignored"
  fi
}

do_upgrade() {
  local oldreg oldrev newreg newrev
  if [ ! -f $pkgreg.gz ]; then
    if [ -f $zregs/$name#*.gz ]; then
      oldreg=$zregs/$(basename $zregs/$name#* .gz)
      oldrev=$(echo $(basename $oldreg) | cut -d# -f2)
      mv $oldreg.gz{,.bak}
      do_install
      if [ ! $forced_exec = yes ]; then
        mv $oldreg.gz{.bak,}
	newreg=$pkgreg;   pkgreg=$oldreg
	newrev=$revision; revision=$oldrev
	do_remove
	pkgreg=$newreg
	revision=$newrev
      else
        rm -f $zregs/$oldreg.gz.bak
      fi
    else
      message "not installed, cannot upgrade, ignored"
    fi
  else
    message "installed already, cannot upgrade, ignored"
  fi
}

installed() {
  local ver err=0
  if [ -f $pkgreg.gz ]; then
    echo "(installed)"
  elif [ -f $zregs/$name#* ]; then
    ver=$(echo $(basename $zregs/$name#* .gz) | cut -d'#' -f2)
    echo "($ver)"
  else
    err=1
  fi
  return $err
}

do_list() {
  if [ $list_all = yes -o \
    $list_installed = yes -a "$(installed)" = '(installed)' \
    -o $list_updated = yes -a "$(installed)" != '(installed)' \
    -a "$(installed)" != '' \
    -o $list_notinstalled = yes -a "$(installed)" = '' ]; then
    if [ $list_url = no ]; then
      echo $name $version-$release $(eval installed) \
        "-$(grep Description: $pkgfile | cut -d: -f2)"
    else
      echo $name $version-$release $(eval installed) \
        "URL:$(echo $source | cut -d' ' -f1)"
    fi
  fi
  return $(installed >/dev/null)
}

do_resolve()
{
  export LC_ALL=C
  dep=$zbuilds/$$_pkgdep
  required='Depends on:'
  if [ $suggest_pkgs == yes ]; then
    opt1='Nice to have:'
    opt2='Optional:'
  else
    opt1=$$$$$$
    opt2=$$$$$$
  fi
  find $zpackages -name Pkgfile \
    | xargs grep -e "$required" -e "$opt1" -e "$opt2" \
      | cut -d: -f1,3 \
      | sed -e 's/://' -e 's:.*\/\(.*\)\/Pkgfile:\1:' -e 's/,/ /g' \
        -e 's/[ \t][ \t]*/ /g' -e "s/ $//" | sort -u > $dep.db
  rm -f $dep
  touch $dep
  echo $name > $dep.in
  while [ -s $dep.in ]; do
    cat $dep.in | while read n; do
      grep "^$n " $dep.db
    done | sed 's: :\n:g' | sort -u > $dep.out
    cat $dep.in $dep | sort -u >> $dep.tmp
    mv $dep.tmp $dep
    comm -13 --nocheck-order $dep $dep.out | sort -u > $dep.in
  done
  if [ $resolve_deps == yes ]; then
    (cd $zregs; ls -1 *.gz | cut -d# -f1 | sort -u > $dep.inst)
    comm -13 --nocheck-order $dep.inst $dep > $dep.tmp
    mv $dep.tmp $dep
    rm $dep.inst
  fi
  echo $name: $(cat $dep | grep -v "^$name$")
  rm -f $dep $dep.{db,in,out}
}

_dep()
{
  required='Depends on:'
  if [ $suggest_pkgs == yes ]; then
    opt1='Nice to have:'
    opt2='Optional:'
  else
    opt1=$$$$$$
    opt2=$$$$$$
  fi
  for f in $(grep -e "$required" -e "$opt1" -e "$opt2" $zpackages/$1/Pkgfile \
    | cut -d: -f2 | sed 's/,/ /g'); do echo $f; done
}

_deps() { for f in $(_dep $1); do echo $f; _dep $f; done }

do_depend()
{
  lst=$(_deps $name)
  lst=$(echo $lst | sed 's/ /\n/g' | sort -u | sed 's/\n/ /')
  echo $name: $lst
}

_prov()
{
  required='Depends on:'
  if [ $suggest_pkgs == yes ]; then
    opt1='Nice to have:'
    opt2='Optional:'
  else
    opt1=$$$$$$
    opt2=$$$$$$
  fi
  find $zpackages -name Pkgfile \
    | xargs grep -e "$required" -e "$opt1" -e "$opt2" \
      | grep -e " $1 " -e " $1$" | sed -E 's/.*\/(.*)\/Pkgfile:.*/\1/'
}

do_provide()
{
  lst=$(_prov $name)
  lst=$(echo $lst | sed -e "s/ $name / /g" -e "s/ ${name}$//g")
  lst=$(echo $lst | sed 's/ /\n/g' | sort -u | sed 's/\n/ /')
  echo $name: $lst
}

test $# -eq 0 && usage && exit
while true; do
  case "$1" in
    -h | --help) help && exit ;;
    -f) forced_exec=yes ;;
    -c) shift; test -r "$1" && zconf=$1 || error "no file $1" ;;
    -p) shift; test -d "$1" && zpackages=$(cd $1; pwd) \
        || error "no directory $1" ;;
    -s) shift; test -d "$1" && zsources=$(cd $1; pwd) \
        || error "no directory $1" ;;
    -m) shift; test -n "$1" && use_mirror=$1 ;;
    -o) suggest_pkgs=yes; ;;
    -n) list_notinstalled=yes; list_all=no ;;
    -i) list_installed=yes; list_all=no ;;
    -u) list_updated=yes; list_all=no ;;
    -a) list_all=yes ;;
    -l) list_url=yes ;;
    *) break ;;
  esac
  shift
done

case $1 in 
  source | clean | build | install | remove | upgrade \
    | list | provide | depend | resolve) cmd=$1; shift ;;
  *) error "unknown command $1" ;;
esac

test \( $cmd = clean -o $cmd = list \) -a $# -eq 0 && set $(cd $zpackages; ls)
test -r $zconf && source $zconf

err=0
while [ $# -gt 0 ]; do
  test "$1" = include -a -f "$2" && shift && set $(sed 's/#.*$//' $1)
  pkgdir=$zpackages/$1
  pkgfile=$pkgdir/Pkgfile
  test -d $pkgdir || error "no directory $pkgdir"
  test -f $pkgfile || error "no file $pkgfile"
  source $pkgfile 
  test "$name" = $1 || error "corrupt $pkgfile"
  revision=$version-$release
  pkgwork=$pkgdir/files
  pkgcont=$pkgdir/.footprint
  pkgsum=$pkgdir/.md5sum
  pkgreg=$zregs/$name#$revision
  pkgbuild=$zbuilds/$name#$revision
  pkgbin=$zsources/$name#$revision.pkg.tar.gz

  # crux compatibility
  SRC=$pkgwork/source
  PKG=$pkgwork/install
  PKGMK_ROOT=$pkgdir
  PKGMK_SOURCE_DIR=$SRC
  #PKGMK_WORK_DIR unset (unknown)

  do_$cmd || err=1
  shift
done
exit $err
