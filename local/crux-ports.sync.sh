#!/bin/bash
ver=3.6
noupdate="filesystem rc"
echo -n sync $ver ports: ''
for p in core opt xorg contrib; do
  ( echo -n $p ''
    rsync -aqz --del crux.nu::ports/crux-$ver/$p/ $p > /dev/null 2>&1 &&
    find $p \( -name COPY* -o -name contrib.pub \) -delete &&
    sed -e 's/pkginfo -i/pkz -i list/g' -e 's/prt-get isinst/pkz -i list/g' -i */*/Pkgfile */*/*-install
  ) || echo -n FAIL ''
done
echo
if [ -n "$noupdate" ]; then
  echo -n not updated: ''
  for p in $noupdate ; do
    [ -d $p ] && find -name $p | xargs rm -r
    echo -n $p ''
  done
  echo
fi

if grep -q prt-get */*/Pkgfile */*/*-install; then
  echo -n beware prt-get: $(grep -lw prt-get */*/Pkgfile */*/*-install | cut -d'/' -f2 | tr '\n' ' ')
  echo
fi

if grep -q unpack_source */*/Pkgfile; then
  echo -n beware unpack_source: $(grep -lw unpack_source */*/Pkgfile | cut -d'/' -f2 | tr '\n' ' ')
  echo
fi
