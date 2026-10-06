class_name Pickup
extends Node2D
## Предмет на земле. Подойти и нажать E. Начало координат — точка на полу под предметом.

@export var item_id: StringName = &"kaplya"
@export var interact_radius := 56.0

var item: ItemData
var _near := false
var _t := 0.0
var _player: Node2D


func _ready() -> void:
	add_to_group(&"pickups")
	item = ArtifactDb.make(item_id)
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	_near = _player != null and is_in_reach(_player.global_position) and _is_nearest_to(_player.global_position)
	queue_redraw()


func is_in_reach(from: Vector2) -> bool:
	return from.distance_to(global_position + Vector2(0, -18)) <= interact_radius


## Подсказку «E» показывает только ближайший к игроку предмет.
func _is_nearest_to(from: Vector2) -> bool:
	var mine := from.distance_to(global_position)
	for n in get_tree().get_nodes_in_group(&"pickups"):
		var other := n as Pickup
		var d := from.distance_to(other.global_position)
		if other != self and other.is_in_reach(from) and (d < mine or (is_equal_approx(d, mine) and other.get_instance_id() < get_instance_id())):
			return false
	return true


## Пытается положить предмет игроку; true — предмет подобран.
func collect(player: Player) -> bool:
	if item == null:
		return false
	if player.inventory.add_item(item):
		queue_free()
		return true
	player.message.emit("Рюкзак полон")
	return false


func _draw() -> void:
	if item == null:
		return
	var bob := sin(_t * 2.5) * 4.0
	var c := Vector2(0.0, -22.0 + bob)
	if item.kind == ItemData.Kind.ARTIFACT:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(c, 26.0 + 4.0 * pulse, Color(item.color, 0.10 + 0.08 * pulse))
		draw_circle(c, 17.0, Color(item.color, 0.14))
	item.draw_icon(self, c, 22.0)
	if _near:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-60.0, -58.0), "E — " + item.display_name, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 14, Color(1, 1, 1, 0.95))
