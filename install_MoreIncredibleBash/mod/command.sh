#!/bin/sh
# M.I.B. -> Advanced Settings -> "Run individual script" executes /mod/command.sh.
# In this package that entry is the LOG EXPORTER: it copies the current power
# cycle's CarPlay logs from the unit's RAM (/tmp) to the SD card under
# logs_export/.
#
# IMPORTANT: M.I.B.'s GEM also SOURCES /mod/command.sh when it scans a mod SD.
# In that case $0 is the launcher, and this file must do ABSOLUTELY NOTHING -
# no exit, no return, no fallback - or GEM itself dies and the M.I.B. menu
# disappears from the unit.
case ${0##*/} in
    command.sh)
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
        ;;
esac
