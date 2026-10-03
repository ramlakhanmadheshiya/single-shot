# One Clean Shot

*A quiet ricochet puzzle.* Drag to aim, release, and bank one orb off the walls to pop every target in the room.

Made with Godot 4.7.2 (GDScript, Compatibility renderer, so it also runs on the web). It is portrait-first and works with touch, mouse, keyboard and gamepad.

**Play / download:** https://theramlakhan.com/one-clean-shot/ — Android APK, or play in the browser on any phone.

## The game

- **320 rooms in 8 chapters of 40.** Each chapter has its own palette and music, and adds one new idea:

  | Chapter | Mood | New mechanic |
  |---|---|---|
  | Dawn | warm cream | walls and bank shots |
  | Glass | mint | glass panes bounce you once, then shatter |
  | Void | indigo night | dark blocks swallow the orb; round bumpers bounce it |
  | Shift | dusk violet | portals carry the orb across the room |
  | Prism | midnight | prisms split one orb into two; ringed targets need two passes |
  | Gate | sage | a switch dissolves the gate walls |
  | Spark | amber night | flying through a spark adds one bounce |
  | Turn | rose | pivot walls turn 90° each time they're hit |

- **Stars:** 1 shot gives ★★★, 2 shots ★★, 3 shots ★. Every room can be cleared in one shot.
- **The dots over the launcher** show how many bounces each shot may make.
- **Progress:** rooms unlock one at a time (clear room N to open room N + 1). A chapter unlocks after 15 clears in the one before it. Difficulty rises steadily from room to room, measured by the solver.
- **Help:** Undo, Restart, and hints that show the exact solving path. You get 3 free hints, refilled to 3 at local midnight. With none left, the game asks before playing a rewarded ad for +1 hint. If no ad is available, the hint is free.
- **Supporter Pack** (the heart on the home screen): a one-time purchase that removes the banner ad and makes every hint free, with a Restore purchase button. The price is shown in the player's local currency (Google Play's localised price, or a regional fallback from the device locale; no permissions needed).
- **Ads (Android only, no interstitials):**
  - a bottom banner on every screen, with layout space reserved so it never covers a button;
  - rewarded ads only when you ask for a hint.
- **Settings** (on every screen): music and sound volume sliders, vibration, screen shake, a longer aim guide (on by default), How to play, Support the game, About and Credits. Reset progress is hidden while you're playing a level.
- **First play:** Dawn level 1 runs a hands-on tutorial with an animated hand. You can replay it from How to play.

### Controls

| Input | Action |
|---|---|
| Drag and release (touch or mouse) | Aim, then shoot |
| ← / → (hold Shift for fine steps) | Nudge the aim |
| Space | Shoot |
| Z | Undo |
| R | Restart |
| H | Hint |
| Esc, or Back on Android | Back |

## Run

```sh
./play.sh            # launches the game window directly (no editor)
```

## Build & publish

Every push to `main` runs `.github/workflows/build.yml`. The workflow:

1. Runs the tests.
2. Exports a signed Android APK and a web build with Godot 4.7.2.
3. Publishes them to the `gh-pages` branch:
   - `index.html` is the download page, built from `web/index.html`;
   - `one-clean-shot.apk` is the Android app;
   - `play/` is the browser version.

APK signing uses three repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEYSTORE_ALIAS`. If they are missing, the workflow signs with a throwaway key. Phones then can't install updates over an older version.

## Check

```sh
./tests/run_all.sh        # simulation, level fairness, end-to-end UI flow, boot smoke
godot --path . res://tests/capture.tscn -- /tmp/ocs_shots   # screenshots of every screen (not committed)
```

## How it works

| Piece | File |
|---|---|
| Deterministic ricochet simulation, shared by gameplay, aim preview, hints, generator and tests | `game/core/ricochet_sim.gd` |
| Board: drawing, aiming, playback and juice (trauma shake, final-hit slow motion, pentatonic pops, rings, particles, haptics) | `game/board/board.gd` |
| App shell, screens, design system and palettes | `game/ui/` |
| Save data, level catalogue and unlocks, audio, haptics | `game/autoload/` |
| Level generator and solver | `tools/level_lab.gd` |
| Audio synthesiser | `tools/synth_audio.py` (see `docs/AUDIO.md`) |

**How the levels are made.** The generator builds each room backwards from a shot. It lays out walls on a 40-unit grid, often mirror-symmetric, then fires a random shot and places targets along the ricochet path.

The solver then sweeps all 360° of aim and records the width of every solving window. A room is rejected if its widest window is under about 0.5–1.4°, because that is too fiddly by touch. A room is also rejected if more than 6% of all angles solve it, because that is too easy.

Difficulty is scored from the solving fraction, the bounce count and the target count. Each chapter is then sorted into a rising curve.

```sh
godot --headless --path . -s res://tools/level_lab.gd            # all chapters
godot --headless --path . -s res://tools/level_lab.gd -- ch3     # one chapter
```

## Credits

| Asset | Source | Licence |
|---|---|---|
| Font: [Outfit](https://github.com/google/fonts/tree/main/ofl/outfit) | Google Fonts | SIL OFL 1.1, `assets/fonts/OFL.txt` |
| Icons: [Lucide](https://lucide.dev) | lucide-static 0.460.0 | ISC, `assets/icons/LICENSE.txt` |
| Music and sound effects | Made for One Clean Shot by `tools/synth_audio.py`, no samples | Released with the project |

The game-dev agent skills used while building this are in `.claude/skills/`. They come from [GodotPrompter](https://github.com/jame581/GodotPrompter) (MIT), [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) (Apache-2.0) and [godot-skills](https://github.com/vl4dt/godot-skills) (MIT).
