set -x

COMMAND=$1
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/OpenRGB"
PROFILE_NAME=".openrgb"


turn_on ()
{
  openrgb -p "/tmp/${PROFILE_NAME}.orp"
  rm "/tmp/${PROFILE_NAME}.orp"
}

turn_off ()
{
  openrgb -sp "/tmp/${PROFILE_NAME}"
  openrgb --mode static -c 000000
}


state ()
{
  if [ -f "/tmp/${PROFILE_NAME}.orp" ]; then
    return 0
  else
    return 1
  fi
}

toggle ()
{
  state
  if [ $? -eq 0 ]; then
    turn_on
  else
    turn_off
  fi
}


case $1 in
  on)
    turn_on
    ;;
  off)
    turn_off
    ;;
  toggle)
    toggle
    ;;
  *)
    echo "Usage: $0 {on|off|toggle}"
    exit 1
    ;;
esac
