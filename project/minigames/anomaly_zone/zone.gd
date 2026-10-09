extends "res://core/minigame.gd"
## Корень мини-игры «Зона: забег»: собирает уровень, игрока и HUD, ведёт забег от А до Б.
## Чекпоинтов нет: смерть и R начинают забег заново — уровень строится с нуля,
## артефакты, расходники и заряды теряются. Яма — урон и возврат на последнее твёрдое место.

const FALL_DAMAGE := 25.0
const RESTART_DELAY := 0.8
## Твёрдое место для возврата из ямы: игрок простоял на полу хотя бы столько секунд.
const SAFE_TIME := 0.25

## Песочница взаимодействий вместо трассы (sandbox.tscn).
@export var sandbox := false

@onready var world: Node2D = $World
@onready var hud_layer: CanvasLayer = $HUD

var player: Player
var level: ZoneLevel
var hud: ZoneHud
var inv_window: InventoryWindow
var overlay: DebugOverlay
## Номер попытки (забега) с запуска игры.
var attempt := 1

var _restarting := false
var _time := 0.0
var _finished := false
var _safe_pos := Vector2.ZERO
var _safe_t := 0.0


func _ready() -> void:
	# Тёмный фон отдельным слоем: корень Control двигался бы вместе с камерой.
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	var bg := ColorRect.new()
	bg.color = Color("12141a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)
	add_child(bg_layer)

	player = Player.new()
	world.add_child(player)
	_build_level()
	world.add_child(AuraSystem.new())
	world.add_child(AnomalyInteractions.new())
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
	player.charge_changed.connect(hud.set_charge)
	player.inventory.item_added.connect(_on_item_added)
	overlay.player = player
	player.health_changed.connect(hud.set_health)
	player.died.connect(_on_player_died)
	_begin_run()
	start()


func _process(delta: float) -> void:
	if not _finished and not _restarting:
		_time += delta
	hud.set_time(_time, attempt)


func _physics_process(delta: float) -> void:
	if player.is_dead() or _restarting:
		return
	if player.state in [Player.MoveState.STAND, Player.MoveState.RUN] and player.is_firmly_grounded():
		_safe_t += delta
		if _safe_t >= SAFE_TIME:
			_safe_pos = player.global_position
	else:
		_safe_t = 0.0
	if player.global_position.y > level.fall_y:
		player.take_damage(FALL_DAMAGE, Vector2.ZERO, true)
		if not player.is_dead():
			player.respawn(_safe_pos, false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"az_respawn") and not _restarting:
		restart_run()
	elif event.is_action_pressed(&"az_debug"):
		overlay.visible = not overlay.visible
	elif event.is_action_pressed(&"az_give_all"):
		_give_all_artifacts()
	elif event.is_action_pressed(&"az_exit"):
		finish(false)
		# Хаба пока нет: при отдельном запуске Esc закрывает игру.
		if get_parent() == get_tree().root:
			get_tree().quit()


## Новый забег с точки А: уровень с нуля (аномалии и предметы на местах), игрок без вещей.
func restart_run() -> void:
	attempt += 1
	world.remove_child(level)  # из групп аномалий и предметов уходит сразу
	level.queue_free()
	_build_level()
	_begin_run()


func _build_level() -> void:
	level = SandboxLevel.new() if sandbox else DemoLevel.new()
	world.add_child(level)
	world.move_child(level, 0)  # уровень рисуется под игроком
	level.finish_sign.reached.connect(_on_finish)


func _begin_run() -> void:
	_restarting = false
	_finished = false
	_time = 0.0
	_safe_t = 0.0
	_safe_pos = level.start_pos + Vector2(0.0, -player.body_size.y * 0.5 - 1.0)
	player.set_camera_limits(level.bounds)
	player.reset_run(_safe_pos)
	hud.hide_finish()


## F2: все артефакты, которых ещё нет у игрока (для тестов).
func _give_all_artifacts() -> void:
	if ArtifactDb.artifact_ids().is_empty():
		hud.show_message("Артефактов пока нет")
		return
	var added := 0
	for id in ArtifactDb.artifact_ids():
		if not player.inventory.has_id(id):
			player.inventory.add_item(ArtifactDb.make(id))
			added += 1
	hud.show_message("Выданы все артефакты" if added > 0 else "Все артефакты уже есть")


func _on_item_added(item: ItemData) -> void:
	hud.show_message("Подобран: " + item.display_name)


func _on_finish() -> void:
	if _finished:
		return
	_finished = true
	var arts: Array[String] = []
	for it in player.inventory.artifacts:
		arts.append(it.display_name)
	hud.show_finish(_time, player.hp, arts)
	finish(true, {"time": _time, "hp": player.hp, "artifacts": arts})


func _on_player_died() -> void:
	if _restarting:
		return
	_restarting = true
	player.visible = false
	hud.show_message("Забег провален — сначала")
	await get_tree().create_timer(RESTART_DELAY).timeout
	restart_run()
