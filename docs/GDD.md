# Carom: game design

## High concept
Carom is a minimalist portrait ricochet puzzle. You fire one orb that travels at a constant speed and banks off walls. The aim is to clear every target in the room, ideally in a single shot.

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

## Progression
- 5 chapters × 20 rooms. Each chapter introduces one mechanic, then combines it with earlier ones.
- **Rooms:** the next 3 rooms past your furthest clear are always open.
- **Chapters:** a chapter opens after 12 clears in the previous one.
- **Difficulty:** rises in a gentle sawtooth within each chapter. It is measured by the solver rather than guessed.

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

## Monetisation hooks
These are prepared but mocked:
- Optional rewarded ad for +3 hints. There are no banners, to keep the minimal look.
- `game/ads/` holds the provider seam for a real SDK.
