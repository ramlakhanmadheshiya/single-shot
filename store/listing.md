# Google Play store listing: Single Shot

Paste these into Play Console > Grow users > Store presence > Main store listing.
Lengths are checked by `python3 store/check_listing.py`.

## App name (30 max)

Single Shot: Ricochet Puzzle

## Short description (80 max)

Aim, bank off the walls and pop every target in a single shot.

## Full description (4000 max)

Single Shot is a calm ricochet puzzle. Drag to aim, let go, and watch your orb bank off the walls. Pop every target in the room with that one shot.

Miss, and the room resets right away. Your last path stays faintly on screen, so you can see what went wrong and adjust. Clear it on the first try for three stars.

NINE IDEAS, ONE AT A TIME
Each chapter adds one new idea and opens with a short tutorial room:
• Dawn: walls and bank shots
• Glass: panes that bounce you once, then break
• Gate: a switch that dissolves the gates
• Drift: platforms that never stop sliding, so time your release
• Turn: pivot walls that turn when you hit them
• Shift: portals that carry the orb across the room
• Void: dark blocks that swallow the orb, and round bumpers
• Prism: prisms that split the orb in two
• Spark: sparks that give you an extra bounce

360 ROOMS, A STEADY CLIMB
Every chapter has 40 rooms. They start gentle and grow harder, with the number of bounces climbing from one to eight. Every room is checked by a solver and can be cleared with one shot.

CALM BY DESIGN
• Just one short ad every 10 levels, and none mid-level
• Optional videos only when you choose them
• Three free hints a day, and a hint shows the exact path
• Progress stays on your device, with no account to make

SHARE YOUR SHOTS
After a clear, save or share a picture of your shot, with the room and the path you took, and ask your friends: can you do it in one shot?

Made with Godot by Ramlakhan Madheshiya. Questions or ideas: support@theramlakhan.com

Purchases are made through Google Play and can't be refunded or undone.

## Category and tags

- Category: Games > Puzzle
- Tags (up to 5, from the Console's list): Puzzle, Logic, Casual, Physics, Offline. Avoid "Brain games" or "brain training": the guide warns these read as health claims.

## Contact details

- Email: support@theramlakhan.com
- Website: https://theramlakhan.com/single-shot/
- Privacy policy: https://theramlakhan.com/single-shot/privacy/

## Graphics

Made from the real game by `tests/capture.gd --store-raw` and `tools/store_art.py` (direction C, Geometry: graph paper, taped screens, a protractor and the real shot angles).

| Asset | File |
|---|---|
| App icon, 512 x 512 PNG (32-bit, full bleed) | `store/icon_512.png` |
| Feature graphic, 1024 x 500 PNG | `store/feature_graphic.png` |
| Phone screenshots, 1080 x 1920 PNG | `store/screenshots/*.png` (8, in order) |
| 7-inch tablet screenshots, 1920 x 1080 PNG | `store/screenshots/tablet7/*.png` (8, in order) |
| 10-inch tablet screenshots, 2560 x 1440 PNG | `store/screenshots/tablet10/*.png` (8, in order) |

## Screenshot alt text (one plain sentence each)

The phone and tablet shots share names and order, so the same text fits both.

1. `01_aim.png`: A finger drags to aim in a Dawn room, with the dotted aim line and a protractor showing the angle.
2. `02_clear.png`: An orb banks back and forth through a Glass room, popping targets along its path.
3. `03_hint.png`: A hint draws the exact path through a Dawn room, with a lens on one bounce and target.
4. `04_chapters.png`: Four rooms side by side, labelled Glass, Drift, Prism and Shift.
5. `05_drift.png`: A Drift room's hint path, with the outline the sliding platform must reach at release.
6. `06_prism.png`: An orb splits in two at a prism in a dark Prism room, the split angle marked.
7. `07_share.png`: The level complete card with three stars, and the shareable picture of the shot lifted off it.
8. `08_title.png`: The home screen with the title and a Play button, beside chips for no timers, offline play and daily hints.
