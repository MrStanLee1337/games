extends "res://core/minigame.gd"
## Корень мини-игры «Зона»: собирает уровень, игрока и HUD, ведёт чекпоинты и респаун.

const FALL_DAMAGE := 25.0
const RESPAWN_DELAY := 0.5

@onready var world: Node2D = $World
@onready var hud_layer: CanvasLayer = $HUD

var player: Player
var level: DemoLevel
var hud: ZoneHud
var inv_window: InventoryWindow
var overlay: DebugOverlay

var _checkpoint: Checkpoint
var _respawning := false
var _time := 0.0
var _deaths := 0
var _finished := false


func _ready() -> void:
	# Тёмный фон отдельным слоем: корень Control двигался бы вместе с камерой.
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	var bg := ColorRect.new()
	bg.color = Color("12141a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)
	add_child(bg_layer)

	level = DemoLevel.new()
	world.add_child(level)
	player = Player.new()
	world.add_child(player)
	overlay = DebugOverlay.new()
	overlay.z_index = 50
	overlay.visible = false
	world.add_child(overlay)
	hud = ZoneHud.new()
	hud_layer.add_child(hud)

	var inv_layer := CanvasLayer.new()
	inv_layer.layer = 20
	add_child(inv_layer)
	inv_window = InventoryWindow.new()
	inv_layer.add_child(inv_window)
	inv_window.setup(player.inventory, player)
	hud.set_inventory(player.inventory)
	player.message.connect(hud.show_message)
	player.inventory.item_added.connect(_on_item_added)

	level.finish_sign.reached.connect(_on_finish)
	overlay.player = player
	player.set_camera_limits(level.bounds)
	player.health_changed.connect(hud.set_health)
	player.died.connect(_on_player_died)
	for cp in level.checkpoints:
		cp.activated.connect(_on_checkpoint)
	_set_checkpoint(level.checkpoints[0])
	player.respawn(_spawn_pos(), true)
	start()


func _process(delta: float) -> void:
	if not _finished:
		_time += delta
	hud.set_time(_time, _deaths)


func _physics_process(_delta: float) -> void:
	if player.is_dead() or _respawning:
		return
	if player.global_position.y > level.fall_y:
		player.take_damage(FALL_DAMAGE, Vector2.ZERO, true)
		if not player.is_dead():
			player.respawn(_spawn_pos(), false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"az_respawn") and not player.is_dead() and not _respawning:
		player.respawn(_spawn_pos(), false)
	elif event.is_action_pressed(&"az_debug"):
		overlay.visible = not overlay.visible
	elif event.is_action_pressed(&"az_give_all"):
		_give_all_artifacts()
	elif event.is_action_pressed(&"az_exit"):
		finish(false)
		# Хаба пока нет: при отдельном запуске Esc закрывает игру.
		if get_parent() == get_tree().root:
			get_tree().quit()


## F2: все артефакты, которых ещё нет у игрока (для тестов).
func _give_all_artifacts() -> void:
	var added := 0
	for id in ArtifactDb.artifact_ids():
		if player.inventory.has_id(id):
			continue
		if not player.inventory.add_item(ArtifactDb.make(id)):
			hud.show_message("Рюкзак полон")
			return
		added += 1
	hud.show_message("Выданы все артефакты" if added > 0 else "Все артефакты уже есть")


func _spawn_pos() -> Vector2:
	return _checkpoint.global_position + Vector2(0.0, -player.body_size.y * 0.5 - 1.0)


func _set_checkpoint(cp: Checkpoint) -> void:
	if _checkpoint:
		_checkpoint.active = false
	_checkpoint = cp
	_checkpoint.active = true


func _on_item_added(item: ItemData, _in_belt: bool) -> void:
	hud.show_message("Подобран: " + item.display_name)


func _on_checkpoint(cp: Checkpoint) -> void:
	if cp == _checkpoint:
		return
	_set_checkpoint(cp)
	hud.show_message("Чекпоинт")


func _on_finish() -> void:
	_finished = true
	hud.show_finish(_time, _deaths)
	finish(true, {"time": _time, "deaths": _deaths})


func _on_player_died() -> void:
	if _respawning:
		return
	_deaths += 1
	_respawning = true
	player.visible = false
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	# Аномалии возвращаются в исходное состояние.
	get_tree().call_group(&"anomalies", &"reset_state")
	player.respawn(_spawn_pos(), true)
	_respawning = false
