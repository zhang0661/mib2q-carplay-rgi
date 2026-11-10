# Turn-card background transparency

The cockpit turn-by-turn card gets a user-adjustable background opacity.

## Why the plate is drawn by the renderer

The cluster composes three layers (`java_patch/.../cluster/ClusterLayerController.java`):

| id | owner | content |
| --- | --- | --- |
| 98 | `maneuver_render` (ours) | turn arrow, road, lane panel - **transparent background** |
| 101 | stock | 987 KDK backing, 328x180 (in-tube stage) |
| 102 | stock | 987 KDK backing, 210x153 (popup stage) |

`IDisplayManagerKombiControl.setOpacity` carries only 0 or 100 and 101/102 are
stock artwork, so the backing cannot be made translucent. Layer 98 sits on top
of it with a transparent frame, so the plate is drawn there instead - and it
removes the visual dependency on the stock backing.

## Contract

| item | value |
| --- | --- |
| storage | namespace `1009`, key `1008` (1007 reserved for `KEY_RGI_VC`, documented but not implemented) |
| HMI model | `2500507` |
| text slots | `2501525`..`2501531` (1500-1524 taken) |
| runtime file | `/tmp/carplay_settings`, line `card_alpha=<0..100>` |
| meaning | percent of the plate; `100` = unchanged, `0` = no plate |
| default | `100`; missing file, missing line or out-of-range value keeps the current value |

`/tmp/carplay_settings` is the existing Java-to-C file (`SPA_SETTINGS_FILE` in
`hook/audio/audio_hook.h`), written by `CarPlaySettingsUi.writeSettingsFile()`.
The renderer re-reads it once per second, so a change lands within ~1 s without
a renderer restart and without any new bus command.

## Changes

- `java_patch/com/luka/carplay/connectivity/CarPlaySettingsUi.java`
  - `KEY_CARD_ALPHA = 1008`, `MODEL_CARD_ALPHA = 2500507`, `INTERNAL_ID_CARD_ALPHA = 2509917`,
    texts `TEXT_CARD_ALPHA` (2501525) .. `TEXT_CARD_ALPHA_0` (2501531).
  - `CARD_ALPHA_DEFAULT = 100`, `CARD_ALPHA_STEPS = {100, 75, 50, 25, 0}`.
  - `selectCardAlpha` / `selectCardAlphaChoice` / `showCardAlpha` / `getCardAlpha`;
    `getText`/`getTextStatus` fallback range widened to `TEXT_CARD_ALPHA_0`.
  - `boot()`: register + read (bounded 0..100) + show; boot log carries `card_alpha`.
  - `formatSettings(...)` 8-argument overload used by `writeSettingsFile()`; the
    7-argument form is unchanged so `tests/UpmixSettingTest.java` keeps passing.
  - Row 8 in `buildCarPlaySettingsScreen` (combo box, after Guidance Maneuver
    Preview), enabled by the same `rgiOn` rule in `syncMenuEnabledStates()`.
  - `Bank.EXTRA_MODELS` + `createModel` branch; `FALLBACK_TEXTS` extended by 7 strings.
- `maneuver_render/render.h`, `maneuver_render/render.c`
  - `render_card_backdrop(float alpha)`: one flat, untextured, full-frame quad
    through the existing flat pass, drawn first in the frame. Depth writes are
    off so it cannot occlude the road composite. No new GL program, so the
    program-binary cache needs no version bump.
- `maneuver_render/main.c`
  - `read_card_alpha()`: re-reads `/tmp/carplay_settings` once per second next to
    the heartbeat and once at start after `clear_maneuver()`; sets
    `g_engine.dirty` only when the value changes. Drawn right after
    `render_begin_frame()`, before `maneuver_draw()`.
- `deploy/lang/upmix_lang.py`
  - Slots 25..31 documented and appended to the `en` list. Other locales fall
    back to the English `FALLBACK_TEXTS` until translated.
- `docs/reference/HOOK_TO_JAVA_BUS.md`
  - Key table: `1008 card_alpha` added, `1007` marked reserved.

## Build and test

- Java: `./scripts/build_java.sh` (both jars); `tests/UpmixSettingTest` guards
  the settings serializer.
- Renderer: `./scripts/build_renderers.sh` (Docker image `qnx65-armv7-toolchain`,
  see `scripts/build_renderers.sh` header).
- On-car: MMI row visible and enabled with Route Guidance on;
  `cat /tmp/carplay_settings` shows `card_alpha=100`; selecting 25 % fades the
  plate within ~1 s with no renderer restart; `0 %` returns to the stock backing;
  the value survives a replug.
