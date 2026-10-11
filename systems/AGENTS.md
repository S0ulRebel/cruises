# Systems ownership

Use explicit references passed by Game. Avoid global event buses or scene-tree name
searches outside the owner's module. `GameState` owns flags, held items and selection.
`CharacterDefinition` separates screenplay content_id from art asset_id and has an
optional authored portrait_scene. `ItemDefinition` owns its model and prose.

Interaction owns async movement/action completion. Audio owns authored players and
their scene properties. Do not import developer tools from runtime systems.
