extends "res://core/minigame.gd"
## Корень мини-игры «Зона»: собирает уровень, игрока и HUD, ведёт чекпоинты и респаун.

const FALL_DAMAGE := 25.0
const RESPAWN_DELAY := 0.5

@onready var world: Node2D = $World
@onready var hud_layer: CanvasLayer = $HUD

var player: Player
var level: TestLevel
var hud: ZoneHud

var _checkpoint: Checkpoint
var _respawning := false


func _ready() -> void:
	# Тёмный фон отдельным слоем: корень Control двигался бы вместе с камерой.
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	var bg := ColorRect.new()
	bg.color = Color("12141a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)
	add_child(bg_layer)

	level = TestLevel.new()
	world.add_child(level)
	player = Player.new()
	world.add_child(player)
	hud = ZoneHud.new()
	hud_layer.add_child(hud)

	player.set_camera_limits(level.bounds)
	player.health_changed.connect(hud.set_health)
	player.died.connect(_on_player_died)
	for cp in level.checkpoints:
		cp.activated.connect(_on_checkpoint)
	_set_checkpoint(level.checkpoints[0])
	player.respawn(_spawn_pos(), true)
	start()


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
	elif event.is_action_pressed(&"az_exit"):
		finish(false)
		# Хаба пока нет: при отдельном запуске Esc закрывает игру.
		if get_parent() == get_tree().root:
			get_tree().quit()


func _spawn_pos() -> Vector2:
	return _checkpoint.global_position + Vector2(0.0, -player.body_size.y * 0.5 - 1.0)


func _set_checkpoint(cp: Checkpoint) -> void:
	if _checkpoint:
		_checkpoint.active = false
	_checkpoint = cp
	_checkpoint.active = true


func _on_checkpoint(cp: Checkpoint) -> void:
	if cp == _checkpoint:
		return
	_set_checkpoint(cp)
	hud.show_message("Чекпоинт")


func _on_player_died() -> void:
	if _respawning:
		return
	_respawning = true
	player.visible = false
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	# Аномалии вернутся в исходное состояние (появятся на этапе 3).
	get_tree().call_group(&"anomalies", &"reset_state")
	player.respawn(_spawn_pos(), true)
	_respawning = false
