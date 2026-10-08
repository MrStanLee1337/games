class_name BeltAura
extends Node2D
## Пояс игрока как источник ауры (группа aura_sources; расчёт — в AuraSystem).
## Рисует круг ауры вокруг игрока и применяет пассивные эффекты артефактов с пояса.

@export var radius := 160.0

var _player: Player
var _t := 0.0
var _aura_color := Color.WHITE
var _has_belt := false


func _ready() -> void:
	_player = get_parent() as Player
	z_index = 5
	add_to_group(&"aura_sources")
	_player.inventory.changed.connect(_on_inventory_changed)
	_on_inventory_changed()


func aura_origin() -> Vector2:
	return global_position


func aura_items() -> Array[ItemData]:
	return _player.inventory.belt_artifacts()


func aura_radius() -> float:
	return radius


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_inventory_changed() -> void:
	var arts := _player.inventory.belt_artifacts()
	_has_belt = not arts.is_empty()
	var jump := 1.0
	var grav := 1.0
	var regen := 0.0
	var dash := false
	var sum := Color(0, 0, 0, 0)
	for art in arts:
		jump *= art.passives.get("jump_mult", 1.0)
		grav *= art.passives.get("gravity_mult", 1.0)
		regen += art.passives.get("regen", 0.0)
		dash = dash or art.passives.get("grants_dash", false)
		sum += art.color
	_player.set_passives(jump, grav, regen, dash)
	if _has_belt:
		_aura_color = Color(sum.r / arts.size(), sum.g / arts.size(), sum.b / arts.size(), 1.0)
	if is_inside_tree():
		get_tree().call_group(&"aura_system", &"refresh")


func _draw() -> void:
	if _has_belt:
		AuraSystem.draw_ring(self, radius, _aura_color, _t)
