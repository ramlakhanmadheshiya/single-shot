# One Clean Shot: game design

## High concept
One Clean Shot is a minimalist portrait ricochet puzzle. You fire one orb that travels at a constant speed and banks off walls. You get one shot to clear every target in the room; a miss resets the room for another try.

## Market references
- **Ricochet One, Ricochet Kills, Bouncy Bullet:** the proven "bounce to clear all targets" loop, a visible trajectory preview, and limited shots.
- **Two Dots, I Love Hue, Alto's Odyssey, Monument Valley:** calm palettes, generous whitespace, one obvious primary action per screen, and audio that is part of the reward.

## Player promise
You read the room, find the angle, and watch one perfect shot chain through every target with a rising run of notes.

## Core loop
1. Drag to aim. A dotted line shows the path to the first contact, plus a short stub after the bounce.
2. Release to shoot.
3. The orb ricochets, using up its bounce allowance. Each target pops on contact and plays the next note on a pentatonic ladder.
4. Clear the room with that one shot. First try earns ★★★, within three tries (or first try with a hint) ★★, after that ★.
5. If you miss, the room resets at once. The missed path stays faintly visible with a one-line reason, so the player always sees why it failed and what to change. A hint shows the full solving path.

## Rules
| Rule | Detail |
|---|---|
| Speed | Constant. Distance stands in for time, so every shot is deterministic. |
| Bounces | Each room sets a bounce allowance, shown as dots over the launcher. When it runs out, the next wall contact dissolves the orb. |
| Targets | The orb passes through them. Ringed targets need two passes. |
| Glass | Reflects once, then shatters. Later in the same shot the orb flies through the gap. |
| Void blocks | Absorb the orb. |
| Bumpers | Round reflectors. |
| Portals | The orb keeps its heading and leaves the twin portal. |
| Prisms | Split the orb ±32°. Each half keeps the remaining bounces. |
| Switches and gates | Crossing a switch dissolves every gate wall for the rest of the attempt. |
| Sparks | Flying through a spark adds one bounce. Sparks come back for every shot. |
| Pivot walls | Reflect, then turn 90° about their centre for the rest of the shot. |
| Moving platforms | Never stop: they slide along a rail and back at 20–35% of the orb's speed, all in one rhythm per room. You time your release; the aim line shows where they will be. |

## Progression
- 9 chapters × 40 rooms, gentlest idea first: Dawn (walls), Glass, Void (dark blocks and bumpers), Drift (moving platforms), Gate (switches), Turn (pivot walls), Spark, Shift (portals), Prism (splits and ringed targets). Each introduces one mechanic, then mixes in earlier ones from about level 16.
- **A learning journey, not 40 puzzles:** level 1 is a tutorial room for the new idea (a floating card with a live diagram, then the element spotlit and the solving path shown once). Every later room must use the idea: with it removed, the solving shot fails. The first time a chapter shows something new (a ringed target, an older chapter's idea), a short tip says so.
- **Bands:** 1–5 easy, 6–10 easy–medium, 11–15 medium, 16–20 medium–hard, 21–25 hard, 26–30 hard–very hard, 31–35 very hard, 36–39 extreme, 40 the peak.
- **Bounces climb:** the solution needs `1 + round((n-1)·7/39)` bounces, from 1 at the start of a chapter to 8 at level 40, and the dots over the launcher show exactly that many.
- **Fairness:** the narrowest allowed solving window shrinks by band (4° → 0.5°), Drift rooms also need a fair timing window, and no room has a much cheaper shortcut. A miss shows its path; Restart gives a fresh start at try 1.
- **Variety:** neighbours never share a layout archetype, an aiming direction or a bounce pattern.
- **Rooms:** unlock one at a time. Clearing room N opens room N + 1. **Chapters:** a chapter opens after 15 clears in the previous one.

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
- **Rewarded:** +1 hint, +1 level key (3 a day), or a one-hour trial of the Orb or Theme pack (with a live countdown). The game asks before playing one, and if no ad can be shown a hint is free.
- **Hints:** 3 free hints, refilled to 3 at local midnight.
- **Shop** (one-time purchases, Restore in the shop and on every pack card; prices in local currency):
  - Complete pack (`complete_pack`, $5.99 / ₹449): supporter, orbs, themes and 5 keys, about a third off.
  - Supporter pack (`supporter_pack`, $2.99 / ₹249): no banner, every hint free.
  - Level keys (`keys_1`…`keys_10`, ₹30 each, 10% off for 5+): a key opens any one locked room for good. (No "open everything" pack: the climb is the game.)
  - Orb pack (`orb_pack`, $1.99 / ₹149) and Theme pack (`theme_pack`, $1.99 / ₹149): cosmetic, picked in Settings.
  - Tip jar (`tip_10`…`tip_1000` in ₹10 steps; presets ₹20/50/100/200 or a custom amount): consumable, opens nothing.
