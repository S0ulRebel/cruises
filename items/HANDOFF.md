# Inventory content handoff

Seven independent ItemDefinition resources replace the former Inventory.ITEMS data.
Each items/<id>/item.tres preserves its existing ID, label and look description.
Fishbowl, rapier, key, compass and brass_inkwell reference reusable prop scenes.
Ladle and rolled_charts have no supplied GLB yet and retain optional-null model_scene,
so their existing placeholder presentation can continue without invented artwork.

UI/integration owns assigning these resources to the authored Inventory. Adding an item
requires a local resource and that scene assignment, not editing a shared code registry.
