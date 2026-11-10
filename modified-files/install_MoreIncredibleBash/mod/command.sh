#!/bin/sh
# M.I.B. -> Advanced Settings -> "Run individual script" executes /mod/command.sh.
# In this package that entry is the LOG EXPORTER: it copies the current power
# cycle's CarPlay logs from the unit's RAM (/tmp) to the SD card under
# logs_export/.  "Run Custom Script" (/mod/custom.sh) stays the installer.
# M.I.B.'s own launcher sources this file while installing M.I.B.; $0 is then
# the launcher, and this file does nothing.
case ${0##*/} in
    command.sh) ;;
    *) return 0 2>/dev/null || exit 0 ;;
esac

OUTDIR=
for d in /mnt/sdcard10t12 /mnt/sdcard /fs/sdcard0 /mnt/usb0; do
    if [ -d "$d" ]; then OUTDIR=$d/logs_export; break; fi
done
if [ -z "$OUTDIR" ]; then
    echo "log export: no SD card mount found"
    exit 1
fi
mkdir -p "$OUTDIR" || { echo "log export: cannot create $OUTDIR"; exit 1; }
for f in carplay_java.log carplay_hook.log maneuver_render.log carplay_wrapper.log carplay_settings; do
    if [ -f "/tmp/$f" ]; then
        cp "/tmp/$f" "$OUTDIR/" && echo "log export: saved /tmp/$f"
    fi
done
echo "log export: done -> $OUTDIR (take the SD out and read it on a computer)"
