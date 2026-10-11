# Outfit backend handoff

2026-10-11: new character assembly uses independent scene parts and explicit donor
binding; legacy slot compatibility remains only for old outfit resources. Integration
owns binding_service.gd and movement clip mappings. Editor and mesh modules have
separate owners in docs/CHARACTER_WORKSHOP_INTERFACES.md.

Backend repairs: nearest-four search now certifies the unsearched-cell distance or
falls back to exhaustive search; generated meshes use a bounded 16-entry LRU cache;
rejected wear replacements retain the old piece; root mesh/skeleton sources are
included. Morph-bearing pieces are rejected by donor conversion with a clear warning
so local facial rigs can be preserved through the assembly attachment workflow.

Outfit.working_copy explicitly clones external fit entries. Legacy preview starts
empty and never dresses automatically; refit queues retain edited resource identity
and flush before save/target changes. Preview animation libraries and their clips
are independent; only locomotion is looped. Actor exports set explicit idle/walk
mapping fields, retaining the original defaults for existing actors.

workshop_backend_check verifies nearest search against exhaustive sampling, resource
independence, empty startup, valid/invalid donor handling, refit selection changes,
replacement rollback, one-shot clips and mapped borrowed walk/idle playback.
Backend and dresser checks pass in the integrated 21-check suite. Final evidence:
`%TEMP%/cruises-checks-c672df683e5e4f13966fe5ac8e6f1f52/`.

Integration follow-up: pure array weight work is available as
`Dresser.bind_surface_data` for a cancellable worker. All scene/rig inputs are sampled
on the main thread. SkinCopy ignores unused vertices preserved by exclusion masks.
`RigSpace.validate_frame` rejects unsupported/local facial rigs before torso fitting
or Retarget can create a singular basis. Native attachments retain those local rigs.
Mover now accepts an explicit animation_player_path for assemblies with multiple rigs.

Root integration checks, legacy backend, dresser and movement pass without engine
errors. Latest module logs: `%TEMP%/cruises-checks-34d7cb54351f4eac8ac03906386aaf58`
and `%TEMP%/cruises-checks-0f8581e240b847b9bdcff17c91f21373`.

Final binding integration covers synchronous/worker equivalence, progress/cancel,
editor teardown joins, stale geometry/rig/material/transform rejection, independent
undo-retained source provenance and per-instance materials, malformed weighted
indices/named binds, unweighted surfaces in rigged models and explicit rebind offsets.
Origin-height hips retargeting stays finite; empty borrowed clips are rejected.
Actor save/cold playback uses mapped walk/idle through Mover while a separate facial
tree stays active. Production coat/body pose acceptance remains an art task.
