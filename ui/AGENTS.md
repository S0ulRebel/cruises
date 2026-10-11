# UI ownership

UI owns saved component scenes, portraits and icon render rigs. Bind authored nodes;
only variable inventory/choice entries and deliberate character changes may spawn.
Inventory.setup(state: GameState) binds the session store. Preserve add/remove/has/
select/describe/display_name/toggle/is_open and selected/opened/closed signals.
Caption and Choices preserve their dialogue APIs. Use InputMap, bounded scrolling,
keyboard focus and explicit Continue. Follow art/ui/ENGINE_INTEGRATION.md.
Portrait fitting and lights belong to per-character scenes. Never write resources at startup.
