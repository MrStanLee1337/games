class_name ForkDoor
extends Node2D
## Дверь развилки в укрытии: E — выбрать следующий участок. Выбор нельзя отменить.
## Над дверью — значки типов аномалий участка. Начало координат — порог двери на полу.

signal chosen(branch: StringName)

@export var branch: StringName = &""
@export var title := ""
## Типы аномалий участка (Anomaly.Type) — значки над дверью.
@export var types: Array[int] = []
@export var interact_radius := 70.0

var locked := false
var _near := false
var _t := 0.0


func _ready() -> void:
	add_to_group(&"pickups")  # E обрабатывает Pickup.nearest_in_reach
	add_to_group(&"fork_doors")


func _process(delta: float) -> void:
	_t += delta
	_near = not locked and Pickup.nearest_for_player(get_tree()) == self
	queue_redraw()


func is_in_reach(from: Vector2) -> bool:
	return not locked and from.distance_to(global_position + Vector2(0, -40)) <= interact_radius


func collect(_player: Player) -> bool:
	if locked:
		return false
	chosen.emit(branch)
	return true


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var frame := Rect2(Vector2(-38.0, -120.0), Vector2(76.0, 120.0))
	draw_rect(frame, Color("101217"))
	draw_rect(frame, Color("aab1c2") if not locked else Color("4f596e"), false, 3.0)
	if _near:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		draw_rect(frame.grow(4.0), Color(1, 1, 1, 0.3 + 0.3 * pulse), false, 2.0)
	for i in types.size():
		var c := Vector2(-18.0 + 36.0 * i - 18.0 * (types.size() - 1) + 18.0, -150.0)
		draw_circle(c, 15.0, Color(0, 0, 0, 0.6))
		AnomalyDb.draw_type_icon(self, types[i], c, 9.0, AnomalyDb.TYPE_COLORS.get(types[i], Color.WHITE))
	draw_string(font, Vector2(-80.0, -176.0), title, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 15, Color("e8ecf4"))
	if _near:
		draw_string(font, Vector2(-80.0, 22.0), "E — сюда", HORIZONTAL_ALIGNMENT_CENTER, 160.0, 14, Color(1, 1, 1, 0.95))
