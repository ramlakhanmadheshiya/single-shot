# Boneyard Bounce

A spooky graveyard puzzle game made with Godot 4.7.2 and GDScript.

## Screens

- Main Menu with Play and Settings.
- Level Select with one chapter on each page.
- Twenty level tiles on every open chapter page.
- Locked chapter pages and chapter paging controls.
- A Settings sheet with sound, theme, aim guide, and shake controls.
- How to play, Credits, About, and Reset progress sheets.
- A pre-game screen with shots, Hint, Undo, Restart, and Settings.
- A short guide for the first few rooms.

The level screen is ready for gameplay work. Physics and level scenes are not included yet.

## Run

Open `project.godot` in Godot 4.7.2 or run:

```sh
godot --path .
```

## Check the project

Run the full screen checks in headless mode or with the regular renderer:

```sh
python3 tests/run_ui_navigation.py
python3 tests/run_ui_navigation.py --gui
```

Check the chapter data rule:

```sh
godot --headless --path . --script tools/validate_levels.gd
```

## Build generated sounds and themes

```sh
./tools/build_assets.sh
```
