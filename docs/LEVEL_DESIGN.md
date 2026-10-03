# Level page and chapter data

Every chapter has exactly twenty level records. `tools/validate_levels.gd` checks the registry and each chapter file.

Run the check with:

```sh
godot --headless --path . --script tools/validate_levels.gd
```

## Chapter 1 play data

Each Chapter 1 record has targets, wall rectangles, crates, a stored solving shot,
and `par_3` and `par_2` star goals. Positions use fractions of the play area.
The solver test fires every stored shot through the physics bodies.

## Add a level

1. Open the chapter's `chapter.json` file.
2. Add one record to its `levels` list.
3. Give it a unique string id.
4. Set its scene path, shot count, star goals, and hint key.
5. Add target, wall, and crate positions. Store a shot that clears the targets.
6. Keep the chapter's total at twenty records.
7. Run the validator and gameplay solver.
8. Run the headless and GUI screen checks before sharing the change.

## Add a chapter

1. Make a folder under `content/chapters/`.
2. Add `chapter.json` with twenty level records.
3. Add its level scenes and art when they are ready.
4. Add one ordered entry to `content/registry.json`.
5. Run the validator and both UI checks.

The registry stores a small chapter list. The game reads one chapter's level data when its page opens. It only builds that page's twenty tiles.
