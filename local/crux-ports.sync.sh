#!/bin/bash
ver=3.6
noupdate="filesystem"
echo -n sync $ver ports: ''
for p in core opt xorg contrib; do
  ( echo -n $p ''
    rsync -aqz --del crux.nu::ports/crux-$ver/$p/ $p > /dev/null 2>&1 &&
    find $p \( -name COPY* -o -name contrib.pub \) -delete &&
    find $p -name Pkgfile | xargs sed -i 's/pkginfo -i/pkz -i list/'
  ) || echo -n FAIL ''
done
echo
if [ -n "$noupdate" ]; then
  for p in $noupdate ; do
    echo not updated $p
    find -name $p | xargs rm -r
  done
fi
