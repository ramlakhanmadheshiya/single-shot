# Theme and screen checks

All screen text comes from `game/ui/strings.gd`. It registers English with Godot's TranslationServer. Add another `Translation` resource later, then select its locale.

The screen colors use the semantic tokens in `game/ui/themes/theme_tokens.gd`. `tools/generate_themes.gd` writes both Theme resources from those tokens. UI panels, tiles, sheets, buttons, switches, and volume sliders use the current palette.

## Review checklist

| Screen | Dark | Light | Checked |
|---|---:|---:|---|
| Main Menu | ✓ | ✓ | ✓ |
| Level Select, open chapter | ✓ | ✓ | ✓ |
| Level Select, locked chapter | ✓ | ✓ | ✓ |
| Settings sheet | ✓ | ✓ | ✓ |
| How to play sheet | ✓ | ✓ | ✓ |
| Credits sheet | ✓ | ✓ | ✓ |
| About sheet | ✓ | ✓ | ✓ |
| Reset question | ✓ | ✓ | ✓ |
| Tutorial overlay | ✓ | ✓ | ✓ |
| In-level screen | ✓ | ✓ | ✓ |

The automated navigation test visits each screen with both color themes. The GUI run also saves temporary review images under `/tmp/bb_*.png`.

## Window sizes

The GUI level-page check resizes to 1280×720, 1920×1080, 720×1280, and 2560×1440. It checks that all four level columns remain inside the view. Buttons have at least 72 design pixels in height, which gives 48 pixels at the 1280×720 window scale.

Light mode uses pale panel and tile surfaces with dark text. Buttons, star marks, selected pages, switches, and sliders use token colors. The volume controls draw their own track, fill, and handle so they stay visible in both themes.
