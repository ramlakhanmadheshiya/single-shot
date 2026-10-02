# Level design workflow

Full authoring tools arrive with the level milestone. Planned workflow:

1. Run `godot --headless --path . --script tools/new_level.gd -- ch01 011` to scaffold metadata and a scene.
2. Edit that level's chapter `chapter.json` entry with ammo, pars, objective, and hint.
3. Arrange reusable physics objects and enemies in the `.tscn` scene.
4. Give every room at least one hostile enemy and enough ammo for a valid solution.
5. Run `godot --headless --path . --script tools/validate_levels.gd`.
6. Run `godot --headless --path . --script tools/solve_levels.gd -- --chapter ch01`.
7. Play the room in Godot and check aim readability and contrast.
8. Commit metadata and scene together.

To add a chapter: create `content/chapters/chNN_slug/` with its JSON, level scenes and art, then add one ordered entry in `content/registry.json`. The registry autoload already loads chapter data lazily.
