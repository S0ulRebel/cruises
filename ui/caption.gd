extends CanvasLayer
## Speech behavior over the authored Captain's Ledger.
signal advanced
@export var show_actions := true
@export var auto_advance_secs := 0.0
@export var reveal_cps := 42.0
@onready var _box: Control = $Root/DialoguePanel
@onready var _speaker_label: Label = $Root/DialoguePanel/Speaker
@onready var _line_label: RichTextLabel = $Root/DialoguePanel/Speech
@onready var _action_label: Label = $Root/Action
@onready var _portrait: Portrait = $Root/DialoguePanel/Portrait
var _full_line := ""
var _revealed := 0.0
var _awaiting := false
var _settled := 0.0
var _following := true

func _ready() -> void:
	$Root/DialoguePanel/Responses.hide()
	$Root/DialoguePanel/Continue.pressed.connect(_advance)
	$Root/DialoguePanel/ScrollUp.pressed.connect(_scroll.bind(-40.0))
	$Root/DialoguePanel/ScrollDown.pressed.connect(_scroll.bind(40.0))

func set_characters(characters: Array[CharacterDefinition]) -> void:
	_portrait.set_characters(characters)

func say(speaker: String, text: String, character_id := "", colour := Color()) -> void:
	_box.show()
	_portrait.speak(character_id, speaker, colour, text)
	_speaker_label.text = speaker
	_full_line = text
	_revealed = 0.0
	_settled = 0.0
	_line_label.text = ""
	_line_label.get_v_scroll_bar().value = 0.0
	_following = true
	_awaiting = true

func action(text: String) -> void:
	if show_actions:
		_action_label.text = text
		_action_label.show()

func clear_action() -> void:
	_action_label.hide()

func speaking_with_portrait() -> bool:
	return _box.visible and _portrait.has_live_head()

func hide_box() -> void:
	_awaiting = false
	_box.hide()
	_portrait.dismiss()

func _process(delta: float) -> void:
	if not _awaiting:
		return
	if _revealed < float(_full_line.length()):
		var bar := _line_label.get_v_scroll_bar()
		_following = bar.value >= bar.max_value - bar.page - 2.0
		_revealed = minf(_revealed + reveal_cps * delta, float(_full_line.length()))
		_line_label.text = _full_line.substr(0, int(_revealed))
		_portrait.set_progress(_revealed / maxf(1.0, float(_full_line.length())))
		if _following:
			_follow_bottom.call_deferred()
		if _revealed >= _full_line.length():
			_portrait.settle()
		return
	if auto_advance_secs > 0.0:
		_settled += delta
		if _settled >= auto_advance_secs:
			_advance()

func _follow_bottom() -> void:
	if _following and _awaiting:
		var bar := _line_label.get_v_scroll_bar()
		bar.value = bar.max_value

func _scroll(amount: float) -> void:
	_line_label.get_v_scroll_bar().value += amount

func _advance() -> void:
	if not _awaiting:
		return
	if _revealed < float(_full_line.length()):
		_revealed = float(_full_line.length())
		_line_label.text = _full_line
		_portrait.settle()
		if _following:
			_follow_bottom.call_deferred()
	else:
		_awaiting = false
		_portrait.settle()
		advanced.emit()

func _unhandled_input(event: InputEvent) -> void:
	if _awaiting and event.is_action_pressed("dialogue_continue") and not event.is_echo():
		_advance()
		get_viewport().set_input_as_handled()
