# Add-on to ~/.xinitrc
setxkbmap -layout se
setxkbmap -option terminate:ctrl_alt_bksp
xsetroot -bg grey10 -fg grey20 -mod 4 4
xrdb -merge $HOME/.Xresources
while true; do
  BATT=$(echo `cat /sys/class/power_supply/BAT0/charge_{now,full}` | awk '{printf "BAT: %.2f", $1/$2}')
  LOAD=$(awk '{print "CPU:", $1}' /proc/loadavg)
  USED=$(free -m | awk '/Mem:/ {printf "%s %-6.2f", "RAM:", $3/$2}')
  TIME=$(date '+%a %b %d %Y %Z %R')
  xsetroot -name "$BATT $LOAD $USED $TIME"
  sleep 10
done &
dwm
