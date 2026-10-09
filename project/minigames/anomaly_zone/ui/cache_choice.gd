class_name CacheChoice
extends Control
## Окно тайника: до трёх карт артефактов, взять одну (клик или 1/2/3) или пропустить (Esc).
## Пока окно открыто, игра и волна стоят на паузе. Взятый артефакт выбросить нельзя.

signal picked(id: StringName)

const CARD := Vector2(300.0, 300.0)
const GAP := 26.0
const C_PLUS := Color("7be08a")
const C_MINUS := Color("ef7a6c")

var _cards: Array[StringName] = []
var _rare := false
var _bonus := ""
var _hover := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


## Показать карты. bonus — что тайник положил в рюкзак в придачу (или "").
func open(cards: Array[StringName], rare: bool, bonus: String) -> void:
	_cards = cards
	_rare = rare
	_bonus = bonus
	_hover = -1
	_layout()
	visible = true
	get_tree().paused = true


func is_open() -> bool:
	return visible


func choose(idx: int) -> void:
	if not visible:
		return
	var id: StringName = _cards[idx] if idx >= 0 and idx < _cards.size() else &""
	visible = false
	get_tree().paused = false
	picked.emit(id)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		match k.physical_keycode:
			KEY_1, KEY_KP_1:
				choose(0)
			KEY_2, KEY_KP_2:
				choose(1)
			KEY_3, KEY_KP_3:
				choose(2)
			KEY_ESCAPE, KEY_BACKSPACE:
				choose(-1)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		_hover = _card_at(mm.position)
		queue_redraw()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if _skip_rect().has_point(mb.position):
			choose(-1)
		else:
			var i := _card_at(mb.position)
			if i >= 0:
				choose(i)


func _card_rect(i: int) -> Rect2:
	var n := maxi(1, _cards.size())
	var total := n * CARD.x + (n - 1) * GAP
	var x0 := (size.x - total) * 0.5
	return Rect2(Vector2(x0 + i * (CARD.x + GAP), size.y * 0.5 - CARD.y * 0.5), CARD)


func _skip_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - 120.0, size.y * 0.5 + CARD.y * 0.5 + 30.0), Vector2(240.0, 40.0))


func _card_at(pos: Vector2) -> int:
	for i in _cards.size():
		if _card_rect(i).has_point(pos):
			return i
	return -1


func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))
	var title := "Редкий тайник" if _rare else "Тайник"
	draw_string(font, Vector2(0.0, size.y * 0.5 - CARD.y * 0.5 - 60.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32,
		Color("ffd24a") if _rare else Color.WHITE)
	var sub := "Возьмите один артефакт — он действует до конца забега, выбросить нельзя"
	if _cards.is_empty():
		sub = "Новых артефактов нет"
	draw_string(font, Vector2(0.0, size.y * 0.5 - CARD.y * 0.5 - 28.0), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15,
		Color(1, 1, 1, 0.65))
	for i in _cards.size():
		_draw_card(i)
	var sr := _skip_rect()
	draw_rect(sr, Color("2a2f3b"))
	draw_rect(sr, Color("7d879c"), false, 2.0)
	draw_string(font, sr.position + Vector2(0.0, 26.0), "Пропустить (Esc)" if not _cards.is_empty() else "Закрыть (Esc)",
		HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 16, Color.WHITE)
	if _bonus != "":
		draw_string(font, Vector2(0.0, sr.end.y + 30.0), "В тайнике также: " + _bonus + " — в рюкзак", HORIZONTAL_ALIGNMENT_CENTER,
			size.x, 15, Color("9fd7a8"))


func _draw_card(i: int) -> void:
	var font := ThemeDB.fallback_font
	var it := ArtifactDb.make(_cards[i])
	var r := _card_rect(i)
	var rare := it.rarity == &"rare"
	draw_rect(r, Color("1d2027"))
	var border := Color("ffd24a") if rare else Color("4f596e")
	if i == _hover:
		border = border.lightened(0.4)
	draw_rect(r, border, false, 3.0 if i == _hover else 2.0)
	draw_string(font, r.position + Vector2(12.0, 26.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.5))
	var c := r.position + Vector2(r.size.x * 0.5, 62.0)
	draw_circle(c, 32.0, Color(it.color, 0.15))
	it.draw_icon(self, c, 40.0)
	draw_string(font, r.position + Vector2(0.0, 122.0), it.display_name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22,
		Color("ffd24a") if rare else it.color.lightened(0.3))
	# Тег: значок типа аномалии и подпись.
	var tc := r.position + Vector2(r.size.x * 0.5 - 60.0, 146.0)
	AnomalyDb.draw_type_icon(self, it.tag, tc, 8.0, AnomalyDb.TYPE_COLORS.get(it.tag, Color("ffd24a")))
	draw_string(font, tc + Vector2(14.0, 5.0), ArtifactDb.tag_name(it.tag) + (", редкий" if rare else ""), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 13, Color(1, 1, 1, 0.7))
	draw_multiline_string(font, r.position + Vector2(16.0, 186.0), "+ " + it.plus, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32.0, 14, -1, C_PLUS)
	draw_multiline_string(font, r.position + Vector2(16.0, 252.0), "− " + it.minus, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32.0, 14, -1, C_MINUS)
