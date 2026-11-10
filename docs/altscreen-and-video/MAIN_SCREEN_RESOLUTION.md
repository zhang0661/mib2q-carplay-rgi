# Main-screen CarPlay resolution override

iOS renders the main CarPlay UI (stream 110) at the size the head unit advertises
in the `/info` display tree.  The hook already rewrites the stock main-display
dictionary (`main_disp_modernize`, `hook/altscreen/altscreen_hook.c`), so the
resolution knob lives there.

## How to change it

Set **both** environment variables before `dio_manager` starts
(`deploy/smartphone_integrator/carplay_startup.sh`):

```sh
export CARPLAY_MAIN_W=1440
export CARPLAY_MAIN_H=540
```

- Unset or malformed values keep the stock resolution (no behaviour change).
- Accepted range: 320..4096 per axis; anything else is ignored.
- The physical size pair (`widthPhysical`/`heightPhysical`) is scaled by the same
  factor **only** when the stock pair is non-zero, so the density iOS derives
  stays truthful.
- The hook logs both the stock pair (always, first `/info`) and the override
  (`main display: resolution override stock WxH -> WxH px`).  Production runs at
  WARN: `touch /mnt/app/carplay_verbose` makes the lines visible.

## What the override does and does not do

- **Does**: changes the display size CarKit builds its model from, i.e. the
  logical CarPlay UI size and the size the phone targets when encoding stream 110.
- **Does not**: touch the stock video SETUP configuration
  (`AirPlayReceiverSessionVideoConfiguration` in libairplay) - the phone may still
  apply its own encode-size heuristics, and the stock OMX decoder follows the
  stream's SPS either way.
- **Does not**: rescale the stock touch path.  Stock HMI touch events are
  absolute coordinates in the stock display space; the phone maps them onto the
  advertised size.  A non-stock size therefore rescales where touches land -
  verify both on the car, never ship one without the other.

## Known stock facts (capture before changing)

Stock main values are unknown to this repo: the hook prints them on the first
`/info` under `stock main panel: ...`.  Known from decompile: stock advertises
the **physical** pair from `AbstractTerminalModeConfiguration`
(`sysConst(522) == 2 ? 188 : 152 / 88 : 91` mm).  The pixel pair was never
measured here; capture it first so the override's scale factor and touch
consequences are deliberate.

## Rebuild

`libcarplay_hook.so` must be rebuilt (`./scripts/build_renderers`-style Docker
image `qnx65-armv7-toolchain`, `./scripts/build_hook.sh`, output
`build/unprotected/libcarplay_hook.so`) and the unit rebooted: the hook runs
inside `dio_manager`, which reads the environment from
`carplay_startup.sh`.
