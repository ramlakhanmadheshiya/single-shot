# One Clean Shot: game design

## High concept
One Clean Shot is a minimalist portrait ricochet puzzle. You fire one orb that travels at a constant speed and banks off walls. The aim is to clear every target in the room, ideally in a single shot.

## Market references
- **Ricochet One, Ricochet Kills, Bouncy Bullet:** the proven "bounce to clear all targets" loop, a visible trajectory preview, and limited shots.
- **Two Dots, I Love Hue, Alto's Odyssey, Monument Valley:** calm palettes, generous whitespace, one obvious primary action per screen, and audio that is part of the reward.

## Player promise
You read the room, find the angle, and watch one perfect shot chain through every target with a rising run of notes.

## Core loop
1. Drag to aim. A dotted line shows the path to the first contact, plus a short stub after the bounce.
2. Release to shoot.
3. The orb ricochets, using up its bounce allowance. Each target pops on contact and plays the next note on a pentatonic ladder.
4. Clear the room within 3 shots: 1 shot earns ★★★.
5. If you miss: undo, restart, or use a hint, which shows the full solving path.

## Rules
| Rule | Detail |
|---|---|
| Speed | Constant. Distance stands in for time, so every shot is deterministic. |
| Bounces | Each room sets a bounce allowance, shown as dots over the launcher. When it runs out, the next wall contact dissolves the orb. |
| Targets | The orb passes through them. Ringed targets need two passes. |
| Glass | Reflects once, then shatters. It stays broken for later shots in the same attempt. |
| Void blocks | Absorb the orb. |
| Bumpers | Round reflectors. |
| Portals | The orb keeps its heading and leaves the twin portal. |
| Prisms | Split the orb ±32°. Each half keeps the remaining bounces. |
| Switches and gates | Crossing a switch dissolves every gate wall for the rest of the attempt. |
| Sparks | Flying through a spark adds one bounce. Sparks come back for every shot. |
| Pivot walls | Reflect, then turn 90° about their centre. The turn persists between shots. |

## Progression
- 8 chapters × 40 rooms. Each chapter introduces one mechanic (walls, glass, voids and bumpers, portals, prisms and ringed targets, switches and gates, sparks, pivot walls), then combines it with earlier ones.
- **Rooms:** unlock one at a time. Clearing room N opens room N + 1.
- **Ramp:** levels 1–3 of every chapter are easy. From level 4 on, each level measures strictly harder than the one before, and level 40 is the hardest.
- **Chapters:** a chapter opens after 15 clears in the previous one.
- **Difficulty:** every room asks a little more than the one before. The level generator targets a rising difficulty for each slot, and the solver measures it.

## Feel
Feedback is tiered by importance, following the game-feel skill's trauma/tier model:
- **Wall bounce:** a small ring, a tick sound and a light shake.
- **Target pop:** a ring, particles, a pitched note, a medium shake and a haptic pulse.
- **Final target:** slow motion, a screen flash and a heavy shake.
- **Results:** the result sheet springs up and the stars pop in with rising notes.

Screen shake, vibration and the longer aim guide can all be toggled in Settings.

## Presentation
- **Layout:** one typeface (Outfit) and line icons (Lucide).
- **Colour:** each chapter is a single palette; the backdrop eases between palettes when you change screens.
- **Arena:** a soft dot-grid card. Walls are capsules, targets are bullseyes, and the orb trails light.
- **Music:** one synthesised ambient loop per chapter plus a menu theme, all in the C-major / A-minor family so the pentatonic pops always fit.

## Monetisation
Ads come from AdMob through the Poing plugin, and the one purchase uses Google Play Billing. All rules live in `game/ads/ad_manager.gd`:
- **Banner:** at the bottom of every screen, with layout space reserved so it never covers a button.
- **No interstitials**, by design.
- **Rewarded:** +1 hint. The game asks before playing one, and if no ad can be shown the hint is free.
- **Hints:** 3 free hints, refilled to 3 at local midnight.
- **Supporter Pack** (`supporter_pack`, one-time, suggested $2.99 / ₹249): no banner, every hint free, and a Restore purchase button. The price shows in local currency.
