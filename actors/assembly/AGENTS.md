# Character visual assembly ownership

- Read `docs/CHARACTER_WORKSHOP_PLAN.md` and `docs/CHARACTER_WORKSHOP_INTERFACES.md`.
- This directory owns game-specific visual templates and their local mesh resources.
- Canonical construction code is in `addons/character_workshop/runtime/` and `core/`.
  Do not restore adapter hooks, compatibility script shims or duplicate core code here.
- Templates are authored CWAssembly scenes; opening them must never build or rebind.
- Game identity, movement, dialogue and portrait wrappers are game-owned features.
- Source assets, local rigs, weights and facial shapes remain intact. Binding and
  geometry changes are explicit authoring actions, tested with independent outputs.
