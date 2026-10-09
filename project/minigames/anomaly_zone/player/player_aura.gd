class_name PlayerAura
extends Node2D
## Аура артефактов игрока — источник для AuraSystem (группа aura_sources).
## Источник — взятые артефакты с полем aura (по таблице забега — только Пламя).
## Рисует круг ауры вокруг игрока, пока такой артефакт есть.

const DEFAULT_RADIUS := 160.0

var _player: Player
var _t := 0.0


func _ready() -> void:
	_player = get_parent() as Player
	z_index = 5
	add_to_group(&"aura_sources")
	_player.inventory.changed.connect(_on_inventory_changed)


func aura_origin() -> Vector2:
	return global_position


func aura_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for it in _player.inventory.artifacts:
		if not it.aura.is_empty():
			out.append(it)
	return out


func aura_radius() -> float:
	var r := 0.0
	for it in aura_items():
		r = maxf(r, it.aura.get("radius", DEFAULT_RADIUS))
	return r


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_inventory_changed() -> void:
	if is_inside_tree():
		get_tree().call_group(&"aura_system", &"refresh")


func _draw() -> void:
	var items := aura_items()
	if items.is_empty():
		return
	var r := aura_radius()
	var col: Color = items[0].color
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	draw_circle(Vector2.ZERO, r, Color(col, 0.025))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(col, 0.12 + 0.06 * pulse), 1.5)
