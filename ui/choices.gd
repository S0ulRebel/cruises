extends CanvasLayer
## Variable response rows in a fixed authored ledger.
signal picked(index: int)
@export var auto_pick_secs := 0.0
const ROW := preload("res://ui/choice_row/choice_row.tscn")
@onready var _panel: Control = $Root/DialoguePanel
@onready var _scroll: ScrollContainer = $Root/DialoguePanel/Responses
@onready var _list: VBoxContainer = $Root/DialoguePanel/Responses/List
@onready var _portrait: Portrait = $Root/DialoguePanel/Portrait
var _count := 0
var _generation := 0
var _waiting := false
var _player: Dictionary = {}

func _ready() -> void:
	$Root/DialoguePanel/Speech.hide()
	$Root/DialoguePanel/Scrollbar.bind_content(_scroll.get_v_scroll_bar())
	$Root/DialoguePanel/Continue.hide()
	$Root/DialoguePanel/Footer.text = "Choose a response - arrows and Enter, or number keys"
	$Root/DialoguePanel/ScrollUp.pressed.connect(_scroll_by.bind(-36))
	$Root/DialoguePanel/ScrollDown.pressed.connect(_scroll_by.bind(36))

func set_characters(characters: Array[CharacterDefinition]) -> void:
	_portrait.set_characters(characters)

func set_player(person: Dictionary) -> void:
	_player = person

func ask(options: Array) -> int:
	dismiss()
	_generation += 1
	var token := _generation
	_count = options.size()
	if _count == 0:
		return -1
	for i in _count:
		var row := ROW.instantiate() as Button
		_list.add_child(row)
		row.call("configure", i, String(options[i]))
		row.pressed.connect(_choose.bind(i))
		row.focus_entered.connect(_focus_row.bind(row))
	_panel.show()
	$Root/DialoguePanel/Speaker.text = "Your response"
	var player_colour: Color = _player.get("colour", Color.WHITE) if _player.get("colour") is Color else Color(String(_player.get("colour", "#ffffff")))
	_portrait.speak(String(_player.get("assets", "")), String(_player.get("name", "")), player_colour)
	_portrait.settle()
	_scroll.scroll_vertical = 0
	_waiting = true
	if auto_pick_secs > 0.0:
		get_tree().create_timer(auto_pick_secs).timeout.connect(func() -> void:
			if token == _generation and _waiting:
				_choose(0), CONNECT_ONE_SHOT)
	var chosen: int = await picked
	dismiss()
	return chosen

func _choose(index: int) -> void:
	if not _waiting or index < 0 or index >= _count:
		return
	_waiting = false
	picked.emit(index)

func _focus_row(row: Control) -> void:
	_scroll.ensure_control_visible(row)

func _scroll_by(amount: int) -> void:
	_scroll.scroll_vertical += amount

func dismiss() -> void:
	_generation += 1
	_waiting = false
	_panel.hide()
	_portrait.dismiss()
	_count = 0
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

func _input(event: InputEvent) -> void:
	if _waiting and event is InputEventMouseMotion:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and _list.is_ancestor_of(focused):
			focused.release_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not _waiting:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# Begin keyboard navigation only when the player requests it.
	if key.keycode in [KEY_UP, KEY_DOWN, KEY_TAB]:
		var focused := get_viewport().gui_get_focus_owner()
		if focused == null or not _list.is_ancestor_of(focused):
			var index := _count - 1 if key.keycode == KEY_UP or (key.keycode == KEY_TAB and key.shift_pressed) else 0
			_list.get_child(index).grab_focus()
			get_viewport().set_input_as_handled()
			return
	var number := key.keycode - KEY_1
	if number >= 0 and number < mini(_count, 9):
		_choose(number)
		get_viewport().set_input_as_handled()
