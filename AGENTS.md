# Cruises editing contract

- Read `docs/REFACTOR_PLAN.md` and the module's `AGENTS.md` before editing.
- Fixed content is authored in `.tscn` prefabs. Scripts provide behavior; never
  create replacement scenery, reset authored transforms, or silently regenerate scenes.
- Do not restore packing flags or batch builders. Normal startup/tests cannot save
  over scenes, models or resources. Authoring saves require an explicit output path.
- Use `game/game.tscn` for startup and `locations/<id>/<id>.tscn` for playable places.
  Locations may be indoors or outdoors. Files/folders use snake_case; nodes PascalCase.
- Root integration owns `game/`, `locations/`, `project.godot`, shared interfaces in
  `systems/content/`, `systems/game_state/`, `systems/interaction/` and path migrations.
- Work on the owner's current branch by default. Notify the owner before creating
  or using another branch/worktree or switching the checkout; this also applies
  to delegated agents. Never switch branches silently.
- Assign each delegated edit an explicit file scope and follow the branch policy
  above. Coordinate shared API or another owner's scene changes before editing.
- Actor/prop/UI owners edit their own prefabs and local resources. Placement belongs
  to the location owner. New content should not require edits to a global registry.
- Keep import settings and script UIDs versioned; leave `.godot` caches and extracted
  previews alone. Do not delete untracked art or user changes.
- Run meaningful module checks, then integration checks. An engine script error is
  failure even when the engine exits zero. Do not add fallback builders to satisfy tests.
- Keep module handoffs local; `HANDOFF.md` is the shared index/current status.
