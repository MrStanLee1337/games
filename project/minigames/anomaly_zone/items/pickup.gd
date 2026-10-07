class_name Pickup
extends Node2D
## Предмет на земле. Подойти и нажать E. Начало координат — точка на полу под предметом.

@export var item_id: StringName = &"kaplya"
@export var interact_radius := 56.0

var item: ItemData
var _near := false
var _t := 0.0


func _ready() -> void:
	add_to_group(&"pickups")
	item = ArtifactDb.make(item_id)
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	_near = nearest_for_player(get_tree()) == self
	queue_redraw()


func is_in_reach(from: Vector2) -> bool:
	return from.distance_to(global_position + Vector2(0, -18)) <= interact_radius


## Ближайший к точке подбираемый предмет (Pickup или WorldArtifact) в пределах досягаемости.
## Подсказку «E» рисует только он, и именно его подбирает игрок.
static func nearest_in_reach(tree: SceneTree, from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for n in tree.get_nodes_in_group(&"pickups"):
		var node := n as Node2D
		if node == null or node.is_queued_for_deletion() or not node.call(&"is_in_reach", from):
			continue
		var d := from.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


static func nearest_for_player(tree: SceneTree) -> Node2D:
	var p := tree.get_first_node_in_group(&"player") as Node2D
	return null if p == null else nearest_in_reach(tree, p.global_position)


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
