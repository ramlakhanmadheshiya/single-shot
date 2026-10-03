# Boneyard Bounce

A spooky graveyard puzzle game made with Godot 4.7.2 and GDScript.

## Screens

- Main Menu with Play, Levels, and Settings.
- Level Select with one chapter on each page.
- Twenty level tiles on every open chapter page.
- Locked chapter pages and chapter paging controls.
- A Settings sheet with sound, theme, aim guide, and shake controls.
- How to play, Credits, About, and Reset progress sheets.
- A pre-game screen with shots, Hint, Undo, Restart, and Settings.
- An action tutorial for the first room.
- Daily free hints with optional mock rewarded ads.
- A Web export preset and a first-tap audio screen.

Chapter 1 now has twenty playable slingshot levels. Drag back from Hazel and let go to shoot.
You can also aim with the arrow keys and fire with Space. A gamepad stick and A button work too.
Every level can be replayed, undone, or restarted. Your stars and best shots are saved.

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
godot --headless --path . res://tests/gameplay_flow.tscn
```

Check the chapter data rule:

```sh
godot --headless --path . --script tools/validate_levels.gd
```

See [docs/PUBLISHING.md](docs/PUBLISHING.md) for web hosting, store release, and ad preparation.

Press F1 in a debug build to tune physics while playing.

## Build generated sounds and themes

```sh
./tools/build_assets.sh
```
The main menu has **Play** to continue and **Levels** to browse chapters. The first unfinished level opens when you press Play. Level Select opens at your current chapter.

Dark and Light screen captures are in [docs/screenshots](docs/screenshots). The action tutorial waits for a drag inside its spotlight.
