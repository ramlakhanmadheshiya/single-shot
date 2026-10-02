# Boneyard Bounce

A spooky-cute ricochet puzzle made with Godot 4.7.2 and GDScript.

## Run

Open `boneyard-bounce/project.godot` in Godot 4.7.2 or run:

```sh
godot --path .
```

The Foundation milestone includes a functioning main menu, persistent settings, dark/light/system appearance selection, credits, procedural graveyard backdrop, original synthesized UI sounds, and a looping menu score.

## Build generated assets

```sh
./tools/build_assets.sh
```

## Export

Create export presets in Godot Editor via **Project → Export** for Windows Desktop, Linux/X11, Android, and Web. Android signing credentials are intentionally not required for local debug exports. Install the corresponding export templates first. Presets will be committed with the gameplay milestone.

See `docs/PROGRESS.md` for current milestone status and known scope limits.
