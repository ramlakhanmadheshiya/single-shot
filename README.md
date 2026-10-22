# Single Shot

*A quiet ricochet puzzle.* Drag to aim, release, and bank one orb off the walls to pop every target in the room. You get one shot.

Made with Godot 4.7.2 (GDScript, Compatibility renderer, so it also runs on the web). It is portrait-first and works with touch, mouse, keyboard and gamepad.

**Play / download:** https://theramlakhan.com/single-shot/ — Android APK, or play in the browser on any phone.

## The game

- **360 rooms in 9 chapters of 40.** Each chapter has its own palette, music and animated chapter card, and adds one new idea:

  | # | Chapter | Mood | New mechanic |
  |---|---|---|---|
  | 1 | Dawn | warm cream | walls and bank shots |
  | 2 | Glass | mint | glass panes bounce you once, then shatter |
  | 3 | Gate | sage | a switch dissolves the gate walls |
  | 4 | Drift | sky | platforms never stop sliding: time your release |
  | 5 | Turn | rose | pivot walls turn 90° each time they're hit |
  | 6 | Shift | dusk violet | portals carry the orb across the room |
  | 7 | Void | indigo night | dark blocks swallow the orb; round bumpers bounce it |
  | 8 | Prism | midnight | prisms split one orb into two; ringed targets need two passes |
  | 9 | Spark | amber night | flying through a spark adds one bounce |

  (Internal ids keep their original numbering, e.g. Drift is `ch9`; `Palette.ORDER` sets the play order.)

- **One shot per room.** A miss resets the room at once; the missed path stays faintly visible with the reason ("Out of bounces · 2 targets left"), so the next try can adjust.
- **Stars:** first try ★★★, within three tries (or first try with a hint) ★★, after that ★. The HUD shows TRY and the STARS still on offer, live. Restart is a fresh start at try 1.
- **The dots over the launcher** show exactly how many bounces the solution needs.
- **Pacing:** every chapter is a learning journey. Level 1 is a tutorial room for the chapter's new idea (a floating card with an animated diagram, then the element spotlit and the path shown once). Bounces then climb from 1 to 8: levels 1–5 easy, 6–10 easy–medium, 11–15 medium, 16–20 medium–hard, 21–25 hard, 26–30 hard–very hard, 31–35 very hard, 36–39 extreme, 40 the peak.
- **Progress:** rooms unlock one at a time (clear room N to open room N + 1). A chapter unlocks after 15 clears in the one before it.
- **Help:** Restart, tap to fast-forward a shot, and hints that show the exact solving path (it stays until you release a shot; in Drift it also outlines where the platform must be). You get 3 free hints, refilled to 3 at local midnight. With none left, the game asks before playing a rewarded ad for +1 hint. If no ad is available, the hint is free.
- **After a clear:** a result card with Next, Watch (replays your shot), Share, Again and Levels. Share renders a 1080×1350 card of the room with your winning path, stars and a QR code, and opens the system share sheet (Android), the browser share sheet (web) or saves it (desktop). **Save** puts that picture in the gallery (Pictures › Single Shot); on Android both go through a small plugin (`plugins_src/singleshot_share`, built into `addons/singleshot_share/bin` by CI).
- **Shop** (the bag on the home screen), all one-time purchases with Restore:

  | Product id | What it gives |
  |---|---|
  | `complete_pack` | supporter + orbs + themes + 5 level keys, for less |
  | `supporter_pack` | no banner ads, every hint free |
  | `keys_1` … `keys_10` | consumable level keys, ₹30 each, 10% off for 5+ (one also comes from a video, 5 a day) |
  | `orb_pack` | 6 orb styles with their own trails (1-hour trial from a video) |
  | `theme_pack` | 11 colour themes (1-hour trial from a video) |
  | `tip_10` … `tip_10000` | 190 consumable tips, priced in ₹ in Play Console: ₹10 steps up to ₹1,000, then ₹100 steps to ₹10,000. The tip jar shows four presets and a picker (minus / price / plus, with a slider across every amount, starting at the ₹500 product), all labelled in the player's own currency |

  Each product id must exist in the Play Console. Every price on screen comes from `Store.price(id)`: Google Play's localised price (the buyer's own currency), or a regional fallback from the device locale until Play answers; no rupee amount is hard-coded in the UI. The shop, every buy card and the tip jar show a small line: "Purchases are made through Google Play. Sorry, we can't refund or undo a purchase." (also on the help page and in the store listing).
- **Ads (Android only):**
  - a bottom banner on every screen, with layout space reserved so it never covers a button;
  - rewarded ads only when you ask for a hint;
  - one full-screen ad after every 10 wins, shown when you tap Next (never mid-room). The Supporter or Complete pack removes all ads.
- **Settings** (a floating card on every screen): music and sound volume, vibration, screen shake, a longer aim guide (on by default), colour and orb pickers, How to play, Shop, About and Credits. Reset progress is hidden while you're playing a level.
- **First play:** Dawn level 1 runs a hands-on tutorial with an animated hand. You can replay it from How to play.

### Controls

| Input | Action |
|---|---|
| Drag and release (touch or mouse) | Aim, then shoot |
| ← / → (hold Shift for fine steps) | Nudge the aim |
| Space | Shoot (or fast-forward a shot in flight) |
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
   - `single-shot.apk` is the Android app;
   - `play/` is the browser version;
   - `privacy/` and `help/` are the privacy policy and help pages (from `web/`).

APK signing uses three repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEYSTORE_ALIAS`. If they are missing, the workflow signs with a throwaway key. Phones then can't install updates over an older version.

## Check

```sh
./tests/run_all.sh        # simulation, level fairness, end-to-end UI flow, boot smoke
godot --path . res://tests/capture.tscn -- /tmp/ocs_shots   # screenshots of every screen (not committed)
```

Store graphics (`store/`): `godot --fixed-fps 60 --disable-vsync --always-on-top --path . res://tests/capture.tscn -- build/store/raw --store-raw`, then `.venv/bin/python -I tools/store_art.py install C` (needs numpy and pillow) and `godot --headless --path . -s res://tools/render_icon.gd -- store/icon_512.png`. Use `tools/store_art.py`, never the kit's compose.py.

## How it works

| Piece | File |
|---|---|
| Deterministic ricochet simulation, shared by gameplay, aim preview, hints, generator and tests | `game/core/ricochet_sim.gd` |
| Board: drawing, aiming, playback and juice (trauma shake, final-hit slow motion, pentatonic pops, rings, particles, haptics) | `game/board/board.gd` |
| App shell, screens, design system and palettes | `game/ui/` |
| Save data, level catalogue and unlocks, audio, haptics | `game/autoload/` |
| Level generator and solver | `tools/level_lab.gd` |
| Audio synthesiser | `tools/synth_audio.py` (see `docs/AUDIO.md`) |

**How the levels are made.** The generator builds each room backwards from a shot. It lays out walls in one of ten archetypes (shelves, pillars, corridor, open box, funnel, zigzag, frame, diagonals, mirrored, scatter), fires a shot with the bounce allowance the slot calls for, and places targets along the ricochet path, always one on the last leg so every bounce counts.

The solver then sweeps all 360° of aim and grades the room. It is rejected if:
- its widest solving window is too narrow for its band (from 4° in the first rooms down to 0.5° at level 40; bumper rooms, which magnify aiming error, get a lower bar);
- too many angles solve it;
- the chapter's idea doesn't matter (with the glass made solid, platforms frozen or the bumper removed, the shot must fail or must at least use it);
- a much cheaper shot also clears it.

Picking the 40: bounces follow `1 + round((n-1)·7/39)`, difficulty rises strictly from level 2 to 40, neighbours never share a layout archetype, an aiming direction or a bounce pattern. `tests/levels_test.gd` enforces all of this.

Moving platforms never stop: they follow a world clock that starts when the room opens. A shot is a pure function of its angle and the clock when it's fired (`state.t0`), so it stays deterministic, and the aim line shows where platforms will be. Every platform in the game moves at the same constant medium speed (18% of the orb's speed, about 270 px/s), all platforms in a room share one rhythm so the winning moment comes round every second or two, no platform ever comes within 18 px of another wall, and the generator also requires a fair timing window (from 0.3 s down to 0.08 s).

```sh
godot --headless --path . -s res://tools/level_lab.gd            # all chapters
godot --headless --path . -s res://tools/level_lab.gd -- ch3     # one chapter
```

## Credits

| Asset | Source | Licence |
|---|---|---|
| Font: [Outfit](https://github.com/google/fonts/tree/main/ofl/outfit) | Google Fonts | SIL OFL 1.1, `assets/fonts/OFL.txt` |
| Icons: [Lucide](https://lucide.dev) | lucide-static 0.460.0 | ISC, `assets/icons/LICENSE.txt` |
| Music and sound effects | Made for Single Shot by `tools/synth_audio.py`, no samples | Released with the project |
| QR code on the share card | Generated with [segno](https://github.com/heuer/segno) | Generated output |

The game-dev agent skills used while building this are in `.claude/skills/`. They come from [GodotPrompter](https://github.com/jame581/GodotPrompter) (MIT), [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) (Apache-2.0) and [godot-skills](https://github.com/vl4dt/godot-skills) (MIT).
