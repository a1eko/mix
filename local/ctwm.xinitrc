setxkbmap -layout se
setxkbmap -option terminate:ctrl_alt_bksp
xsetroot -bg grey10 -fg grey20 -mod 4 4
xrdb -merge $HOME/.Xresources
conky &
exec ctwm -W
