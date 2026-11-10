# Cockpit turn card: background transparency + display mode

Two user-facing features on the cockpit turn-by-turn card:

1. **Background opacity** - 30 % / 50 % / 100 % (100 = stock look).
2. **Display mode** - Always visible | Auto-hide when far | Hidden; the
   steering-wheel **star key** cycles 显示 -> 隐藏 -> 位置左/中/右 -> 显示
   (the positions ride the existing `alt_layout` setting).

## Why the plate is drawn by the renderer

The cluster composes three layers (`java_patch/.../cluster/ClusterLayerController.java`):

| id | owner | content |
| --- | --- | --- |
| 98 | `maneuver_render` (ours) | turn arrow, road, lane panel - **transparent background** |
| 101 | stock | 987 KDK backing, 328x180 (in-tube stage) |
| 102 | stock | 987 KDK backing, 210x153 (popup stage) |

`IDisplayManagerKombiControl.setOpacity` carries only 0 or 100 and 101/102 are
stock artwork, so the backing cannot be made translucent. Layer 98 sits on top
of it with a transparent frame, so the plate is drawn there instead.

## Contract

| item | value |
| --- | --- |
| storage | namespace `1009`, keys `1007` (`rgi_vc`) and `1008` (`card_alpha`) |
| HMI models | `2500507` (opacity), `2500508` (mode) |
| text slots | `2501525`..`2501529` (opacity), `2501530`..`2501533` (mode) |
| runtime file | `/tmp/carplay_settings`: `card_alpha=<0..100>` and `card_mode=<0\|1>` |
| meaning | `card_alpha`: percent of the plate, `100` = unchanged.  `card_mode`: 0 always visible, 1 auto-hide while the maneuver is far, 2 hidden |
| defaults | `100` / `0`; missing or invalid values keep the current ones |

`/tmp/carplay_settings` is the existing Java-to-C file (`SPA_SETTINGS_FILE` in
`hook/audio/audio_hook.h`), written by `CarPlaySettingsUi.writeSettingsFile()`.
`maneuver_render` re-reads it once per second, so a settings change or a star-key
cycle lands within ~1 s with no renderer restart and no new bus command.

## Changes

- `java_patch/com/luka/carplay/connectivity/CarPlaySettingsUi.java`
  - `KEY_RGI_VC = 1007` / `KEY_CARD_ALPHA = 1008`, models `2500507`/`2500508`,
    texts 2501525..2501533, internal ids 2509917/2509918.
  - `CARD_ALPHA_DEFAULT = 100`, `CARD_ALPHA_STEPS = {30, 50, 100}` (ascending;
    snapping rounds up to the next step).
  - `RGI_VC_ALWAYS = 0`, `RGI_VC_AUTO = 1`, `RGI_VC_HIDDEN = 2`, default ALWAYS
    (backward compatible).
  - `selectCardAlpha` / `selectCardAlphaChoice` / `showCardAlpha`,
    `selectRgiVc` / `selectRgiVcChoice` / `showRgiVc` / `getRgiVc`,
    and `cycleCardState()` (the star-key entry: 显示 -> 隐藏 -> 位置左/中/右 -> 显示).
  - `formatSettings(...)` 9-argument overload used by `writeSettingsFile()`
    writes both `card_alpha=` and `card_mode=` lines; the 7-argument form is
    unchanged so `tests/UpmixSettingTest.java` keeps passing.
  - Rows 8/9 in `buildCarPlaySettingsScreen`, both enabled by the `rgiOn` rule.
  - `Bank.EXTRA_MODELS` + `createModel` branches; `FALLBACK_TEXTS` extended.
- `java_patch/com/luka/carplay/core/SteeringWheelInputModule.java`
  - The MFW **star key** (key code 41, candidate) calls
    `CarPlaySettingsUi.cycleCardState()` on press.  Any other unknown MFW key code
    is logged once ("unhandled MFW key code=N"), so the real star-key code can be
    confirmed from one log if 41 is wrong on this unit.
- `maneuver_render/render.h`, `maneuver_render/render.c`
  - `render_card_backdrop(float alpha)`: one flat, untextured, full-frame quad
    through the existing flat pass, drawn first in the frame. Depth writes are
    off. No new GL program, so the program-binary cache needs no version bump.
- `maneuver_render/main.c`
  - `read_card_alpha()` also parses `card_mode=`.  The backdrop is skipped while
    the card is hidden.  In mode 1, when the maneuver's progress level is
    `>= CARD_AUTO_FAR_LEVEL` (15 of 0..16, 16 = far) the card slides out; below
    it slides back in (`maneuver_set_slide`).  Mode 0 keeps it always visible.
- `deploy/lang/upmix_lang.py`
  - Slots 25..33 documented and appended to the `en` list; other locales fall
    back to the English `FALLBACK_TEXTS` until translated.
- `docs/reference/HOOK_TO_JAVA_BUS.md`
  - Key table: `1007 rgi_vc` and `1008 card_alpha` documented.

## Build and test

- Java: `./scripts/build_java.sh` (both jars); `tests/UpmixSettingTest` guards
  the settings serializer.
- Renderer: `./scripts/build_renderers.sh` (Docker image `qnx65-armv7-toolchain`).
- On-car:
  1. MMI row "Turn Card Background" (30/50/100) and "Cockpit Turn Card"
     (Always visible / Auto-hide when far), both enabled with Route Guidance.
  2. `cat /tmp/carplay_settings` shows `card_alpha=` and `card_mode=`.
  3. Selecting 30 % fades the plate within ~1 s, no renderer restart.
  4. Star key press toggles the mode; in Auto the card slides out while far
     (`engine: card hidden ... level=15/16`) and slides back in on approach.
  5. If the star key log never fires, check `/tmp/carplay_java.log` for
     "unhandled MFW key code=N" and update `KEY_MFW_STAR`.
