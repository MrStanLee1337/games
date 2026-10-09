class_name Player
extends CharacterBody2D
## Игрок: бег, прыжок, рывок, здоровье, камера.
## Числа движения — в MovementConfig (movement_default.tres); игрок читает эффективную копию `m`
## (конфиг × множители артефактов и баффов), её пересчитывает recompute_movement().
## Рывок тратит заряд (заряды дают Электры).
## Движение разложено по состояниям (enum MoveState); переход — только через change_state().
## Внешние силы (аномалии) действуют через apply_impulse / add_external_force / set_move_multiplier.

signal health_changed(hp: float, max_hp: float)
signal died
## Короткое сообщение для HUD («Рюкзак полон» и т.п.).
signal message(text: String)
signal charge_changed(value: int, max_value: int)
signal state_changed(from: MoveState, to: MoveState)

## Группы по схеме ТЗ: на земле (STAND, RUN, SLIDE — подкат, CRAWL — ползком, ROLL — перекат),
## в воздухе (JUMP, FALL, DASH, WALL_SLIDE), на опоре (HANG — вис на краю, CLIMB — подтягивание,
## VAULT — быстрое перелезание, LADDER — лестница или верёвка).
## Оглушение — не состояние, а наложение поверх любого (is_stunned()).
enum MoveState { STAND, RUN, JUMP, FALL, DASH, WALL_SLIDE, HANG, CLIMB, VAULT, SLIDE, CRAWL, ROLL, LADDER }
const STATE_NAMES := ["стоит", "бег", "прыжок", "падение", "рывок", "скольжение по стене", "вис", "подтягивание",
	"перелезание", "подкат", "ползком", "перекат", "лестница"]
const SUPPORT_STATES := [MoveState.HANG, MoveState.CLIMB, MoveState.VAULT, MoveState.LADDER]
## Состояния с низким хитбоксом (crouch_height); из них выходят явно.
const CROUCH_STATES := [MoveState.SLIDE, MoveState.CRAWL, MoveState.ROLL]

@export var config: MovementConfig = preload("res://minigames/anomaly_zone/player/movement_default.tres")

@export_group("Здоровье")
@export var invuln_time := 0.6
@export var hit_knockback := 260.0

## Статы забега (артефакты, счётчик баффов) и активные баффы.
var stats := PlayerStats.new()
var buffs := Buffs.new()
## Пределы из статов: макс. HP (с артефактами) и зарядов рывка.
var max_hp := PlayerStats.BASE_MAX_HP
var max_charge := PlayerStats.BASE_CHARGES
# Итоговые множители движения (артефакты × баффы); пересчёт — recompute_movement().
var run_multiplier := 1.0
var jump_multiplier := 1.0
var gravity_multiplier := 1.0
# Контакты с аномалиями: часы забега, когда каждая аномалия (instance_id) последний раз дала бафф,
# время последнего баффа (Бенгальский огонь), Праща (overspeed_drag выключен).
var _clock := 0.0
var _buff_seen: Dictionary = {}
var _last_buff_t := -100.0
var _sling_t := 0.0

## Эффективные параметры движения: копия config с учётом пассивов. Только для чтения.
var m: MovementConfig
var state: MoveState = MoveState.STAND
## Последние смены состояния — для оверлея F1.
var state_log: Array[String] = []
var body_size: Vector2:
	get:
		return config.body_size()

var hp := 0.0
var inventory := Inventory.new()
var facing := 1

var _force_acc := Vector2.ZERO
var _mult_acc := 1.0
## Скорость падения в момент приземления (держится один кадр).
var landing_speed := 0.0
var charge := 0
var _coyote := 0.0
var _buffer := 0.0
var _jumping := false
## Окно «вершины» (меньше гравитации) — только у вершины своего прыжка, не после рывка или толчка.
var _apex_ok := false
var _air_dash_used := false
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := 1
var _lock := 0.0
var _lock_total := 1.0
var _invuln := 0.0
var _dead := false
var _stun := 0.0
var _no_dash_hint_t := 0.0
var _fall_through: Platform = null
var _fall_through_t := 0.0
var _shake := 0.0
var _look := 0.0
var _camera: Camera2D
# Стена: скольжение, отскок.
var _sliding := false
var _wall_dir := 0
var _wall_coyote := 0.0
var _wall_jumps := 0
var _wj_lock_t := 0.0
var _wj_dir := 0
# Зацеп за край и перелезание.
var _ledge: Dictionary = {}
var _ledge_seen_t := 0.0
var _regrab_cd := 0.0
var _climb_from := Vector2.ZERO
var _climb_to := Vector2.ZERO
var _climb_t := 0.0
var _climb_total := 1.0
var _climb_keep_vx := 0.0
# Подкат, ползком, перекат, падение.
var _shape: RectangleShape2D
var _cs: CollisionShape2D
var _crouched := false
var _slide_t := 0.0
var _slide_cd := 0.0
## S нажата в этом кадре (свой фронт: на нём подкат отличается от «ползком»).
var _down_edge := false
var _down_was := false
var _roll_t := 0.0
## S нажата в воздухе — перекат, если касание в ближайшие roll_window_before.
var _roll_buf := 0.0
## Жёсткое приземление ждёт roll_window_after: успел нажать S — перекат.
var _land_grace := 0.0
var _land_h := 0.0
## Верхняя точка текущего полёта (для урона от падения).
var _fall_peak_y := 0.0
## Высота последнего приземления, px (для оверлея F1).
var last_fall := 0.0
# Лестница.
var _ladder: Ladder = null
var _ladder_down_t := 0.0
# Камера: вертикаль с мёртвой зоной, смещение при падении, зум.
var _cam_y := 0.0
var _fall_look := 0.0
var _zoom_target := 1.0
var _zoom_tween: Tween


func _ready() -> void:
	recompute_movement()
	add_to_group(&"player")
	collision_layer = 2
	collision_mask = 1
	_cs = CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_shape.size = body_size
	_cs.shape = _shape
	add_child(_cs)
	_fall_peak_y = global_position.y
	_camera = Camera2D.new()
	_camera.top_level = true  # положение камеры считаем сами: взгляд вперёд, мёртвая зона, падение
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = m.cam_smoothing
	add_child(_camera)
	_cam_y = global_position.y + m.cam_offset_y
	_camera.global_position = Vector2(global_position.x, _cam_y)
	_camera.make_current()
	inventory.setup()
	stats.changed.connect(_on_stats_changed)
	buffs.changed.connect(recompute_movement)
	add_child(PlayerAura.new())
	hp = max_hp
	health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	# Силы и замедление, собранные за прошлый кадр, — порядок обработки узлов не важен.
	var ext := _force_acc
	var slow := _mult_acc
	var boost := 1.0
	_force_acc = Vector2.ZERO
	_mult_acc = 1.0
	_tick(delta)
	if is_on_floor() or state in SUPPORT_STATES or _sliding:
		_fall_peak_y = global_position.y

	var stunned := _stun > 0.0
	var down := Input.is_action_pressed(&"az_down")
	_down_edge = down and not _down_was
	_down_was = down
	var dir := 0.0 if stunned else Input.get_axis(&"az_left", &"az_right")
	if dir != 0.0 and state != MoveState.DASH:
		facing = 1 if dir > 0.0 else -1
	if is_on_floor():
		_coyote = m.coyote_time
		_air_dash_used = false
		_wall_jumps = 0
	if not stunned and Input.is_action_just_pressed(&"az_jump"):
		var plat := _floor_platform() if Input.is_action_pressed(&"az_down") else null
		if plat and plat.one_way:
			_drop_through(plat)  # вниз + прыжок на односторонней платформе — спрыгнуть
		else:
			_buffer = m.jump_buffer
	if not stunned and Input.is_action_just_pressed(&"az_dash"):
		_try_dash(dir)
	if Input.is_action_just_pressed(&"az_interact"):
		_try_interact()
	if Input.is_action_just_pressed(&"az_heal"):
		use_best_consumable()
	if not stunned and Input.is_action_just_pressed(&"az_down") and not is_on_floor() and state not in SUPPORT_STATES:
		_roll_buf = m.roll_window_before
	_land_grace_tick(delta)
	if not stunned:
		_try_ladder()
		if is_on_floor() and state in [MoveState.STAND, MoveState.RUN]:
			_ground_down_actions()
	if _crouched and state not in CROUCH_STATES and _can_stand():
		_set_crouch(false)

	match state:
		MoveState.HANG:
			_state_hang(dir)
			return
		MoveState.CLIMB, MoveState.VAULT:
			_state_climb(delta)
			return
		MoveState.DASH:
			_state_dash()
		MoveState.SLIDE, MoveState.ROLL:
			_state_slide(delta, boost)
		MoveState.CRAWL:
			_state_crawl(delta, dir, slow, boost)
		MoveState.LADDER:
			_state_ladder(delta, dir)
		_:
			# Стоит, бег, прыжок, падение, скольжение по стене делят одну физику.
			_move(delta, dir, slow, ext != Vector2.ZERO, boost)
			_corner_correction(delta)
			_ledge_nudge(delta)
	velocity += ext * delta
	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	landing_speed = 0.0
	move_and_slide()
	if state == MoveState.LADDER:
		_ladder_after_move(fall_speed)
	elif not was_on_floor and is_on_floor():
		landing_speed = maxf(0.0, fall_speed)
		_on_landed(global_position.y - _fall_peak_y, landing_speed)
	_fall_peak_y = minf(_fall_peak_y, global_position.y)
	_update_state()
	if not stunned and not _crouched:
		if is_on_floor():
			if state in [MoveState.STAND, MoveState.RUN]:
				_try_vault(dir)
		elif state not in SUPPORT_STATES and state != MoveState.DASH:
			_try_ledge_grab(dir)


func _process(delta: float) -> void:
	_update_camera(delta)
	modulate.a = 0.35 if _invuln > 0.0 and int(_invuln * 20.0) % 2 == 0 else 1.0
	queue_redraw()


func _tick(delta: float) -> void:
	_coyote -= delta
	_buffer -= delta
	_dash_cd -= delta
	_lock -= delta
	_invuln -= delta
	_stun -= delta
	_no_dash_hint_t -= delta
	_wall_coyote -= delta
	_wj_lock_t -= delta
	_regrab_cd -= delta
	_sling_t -= delta
	_clock += delta
	buffs.tick(delta)
	_ledge_seen_t -= delta
	_slide_cd -= delta
	_roll_buf -= delta
	if _fall_through_t > 0.0:
		_fall_through_t -= delta
		if _fall_through_t <= 0.0 and is_instance_valid(_fall_through):
			remove_collision_exception_with(_fall_through)
			_fall_through = null
	if _dash_t > 0.0:
		_dash_t -= delta
		if _dash_t <= 0.0:
			velocity.x = _dash_dir * m.run_speed * m.dash_end_speed
			_update_state()


func _move(delta: float, dir: float, slow: float, pulled: bool, boost: float) -> void:
	# Пока действует блокировка управления, ввод почти не влияет — отброс не гасится.
	var ctl := 1.0
	if _lock > 0.0:
		ctl = lerpf(0.08, 1.0, 1.0 - _lock / _lock_total)
	if _wj_lock_t > 0.0 and dir != 0.0 and int(signf(dir)) == _wj_dir:
		ctl *= m.wall_jump_control  # сразу после отскока к стене не тянет обратно
	var on_floor := is_on_floor()
	var target := dir * m.run_speed * slow
	var vx := velocity.x
	var rate: float
	if dir == 0.0:
		rate = m.ground_decel if on_floor else m.air_decel
		if pulled and on_floor:
			rate *= m.pulled_friction_mult  # под внешней силой трение слабеет, иначе притяжение не чувствуется
	elif signf(vx) == signf(dir) and absf(vx) > absf(target):
		# Быстрее бега (подкат, толчок, конец Форсажа) — гаснет плавно; Праща держит скорость.
		rate = 0.0 if _sling_t > 0.0 else (m.overspeed_drag if on_floor else m.air_overspeed_drag)
	elif on_floor and vx != 0.0 and signf(vx) != signf(dir):
		rate = m.turn_accel  # резкий разворот на бегу
	else:
		rate = m.ground_accel if on_floor else m.air_accel
	velocity.x = move_toward(vx, target, rate * ctl * delta)
	_vertical(delta, dir, boost)


## Прыжок, отскок от стены, гравитация, скольжение по стене, обрезка прыжка.
func _vertical(delta: float, dir: float, boost: float) -> void:
	var on_floor := is_on_floor()
	_sliding = false
	# Сначала толчок прыжка, потом гравитация того же кадра (полунеявный Эйлер, как в расчётах ТЗ).
	if _buffer > 0.0 and _coyote > 0.0 and _can_stand():
		_set_crouch(false)  # прыжок из подката, ползком и переката — встаём
		velocity.y = -m.jump_velocity * boost
		_buffer = 0.0
		_coyote = 0.0
		_jumping = true
		_apex_ok = true
	elif _buffer > 0.0 and not on_floor and _wall_coyote > 0.0 and _wall_jumps < m.wall_jumps_max:
		# Отскок от стены (при скольжении или сразу после отрыва).
		velocity = Vector2(-_wall_dir * m.wall_jump_out, -m.wall_jump_up)
		_wall_jumps += 1
		_buffer = 0.0
		_wall_coyote = 0.0
		_wj_lock_t = m.wall_jump_lock
		_wj_dir = _wall_dir
		facing = -_wall_dir
		_jumping = true
		_apex_ok = true
	if on_floor and velocity.y >= 0.0:
		_apex_ok = false
	var g := effective_gravity(velocity.y > 0.0)
	if _apex_ok and not on_floor and absf(velocity.y) < m.apex_threshold and Input.is_action_pressed(&"az_jump"):
		g *= m.apex_gravity_mult  # у вершины с зажатым Пробелом — время прицелиться
	velocity.y = minf(velocity.y + g * delta, m.terminal_fall)
	# Скольжение по стене: только при падении и прижимаясь к стене.
	if not on_floor and velocity.y > 0.0 and dir != 0.0 and _touching_wall(int(signf(dir))):
		velocity.y = minf(velocity.y, m.wall_slide_speed)
		_sliding = true
		_wall_dir = int(signf(dir))
		_wall_coyote = m.wall_coyote
	if _jumping:
		if velocity.y >= 0.0:
			_jumping = false
		elif not Input.is_action_pressed(&"az_jump"):
			velocity.y *= m.jump_cut
			_jumping = false


func _try_dash(dir: float) -> void:
	if state in SUPPORT_STATES:
		return
	if charge <= 0:
		if _no_dash_hint_t <= 0.0:
			message.emit("Рывок тратит заряд — заряды дают Электры")
			_no_dash_hint_t = 3.0
		return
	if _dash_cd > 0.0 or _dash_t > 0.0:
		return
	if not is_on_floor():
		if _air_dash_used:
			return
		_air_dash_used = true
	_dash_dir = int(signf(dir)) if dir != 0.0 else facing
	facing = _dash_dir
	_set_charge(charge - 1)
	_dash_t = m.dash_time
	_dash_cd = m.dash_cooldown
	_jumping = false
	_apex_ok = false
	velocity.y = 0.0
	change_state(MoveState.DASH)


## Головой задел угол потолка на подъёме — сдвинуть вбок до corner_correction px вместо удара.
func _corner_correction(delta: float) -> void:
	if velocity.y >= 0.0:
		return
	var motion := Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, motion):
		return
	for i in range(1, int(m.corner_correction) + 1):
		for s in [-1.0, 1.0]:
			var side := Vector2(i * s, 0.0)
			if not test_move(global_transform, side) and not test_move(global_transform.translated(side), motion):
				global_position.x += side.x
				return


## Ногами задел край уступа на подъёме — подбросить на него до ledge_nudge px.
func _ledge_nudge(delta: float) -> void:
	if is_on_floor() or velocity.y > m.apex_threshold or absf(velocity.x) < 1.0:
		return
	var motion := Vector2(velocity.x * delta, 0.0)
	if not test_move(global_transform, motion):
		return
	for i in range(1, int(m.ledge_nudge) + 1):
		var up := Vector2(0.0, -i)
		if not test_move(global_transform, up) and not test_move(global_transform.translated(up), motion):
			global_position.y -= i
			return


# --- Стена, зацеп за край, перелезание --------------------------------------

## Есть ли сплошная стена вплотную со стороны s (односторонние платформы стеной не считаются).
func _touching_wall(s: int) -> bool:
	return s != 0 and test_move(global_transform, Vector2(s * 2.0, 0.0))


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, 1, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(q)


## Стоит на полу всем телом: под обоими краями ног есть опора (для возврата из ямы).
func is_firmly_grounded() -> bool:
	if not is_on_floor():
		return false
	var half := body_size * 0.5
	for dx in [-half.x + 1.0, half.x - 1.0]:
		var from := global_position + Vector2(dx, half.y - 2.0)
		if _ray(from, from + Vector2(0.0, 8.0)).is_empty():
			return false
	return true


## Свободно ли место под тело с центром в c.
func _box_free(c: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size - Vector2(2.0, 2.0)
	q.shape = rect
	q.transform = Transform2D(0.0, c)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


## Край уступа со стороны s: верх между грудью и ledge_above_head над головой, над ним можно стоять.
func _find_ledge(s: int) -> Dictionary:
	var half := body_size * 0.5
	var px := global_position.x + s * (half.x + 3.0)
	# При быстром падении край проскакивает полосу за кадр — ищем его и на пройденном за кадр пути.
	var swept := maxf(0.0, velocity.y) * get_physics_process_delta_time()
	var hit := _ray(Vector2(px, global_position.y - half.y - m.ledge_above_head - swept),
		Vector2(px, global_position.y - m.ledge_chest_offset))
	if hit.is_empty():
		return {}
	if hit.collider is Platform and (hit.collider as Platform).no_grab:
		return {}  # гнилой край
	var top: float = hit.position.y
	var side := _ray(Vector2(global_position.x, top + 2.0), Vector2(global_position.x + s * (half.x + 8.0), top + 2.0))
	if side.is_empty():
		return {}
	var wall_x: float = side.position.x
	var stand := Vector2(wall_x + s * (half.x + 2.0), top - half.y - 1.0)
	if not _box_free(stand):
		return {}
	return {"top": top, "side": s, "wall_x": wall_x, "stand": stand}


func _try_ledge_grab(dir: float) -> void:
	if _regrab_cd > 0.0:
		return
	var s := int(signf(dir)) if dir != 0.0 else int(signf(velocity.x))
	if s == 0:
		return
	var info := _find_ledge(s)
	if not info.is_empty():
		_ledge = info
		_ledge_seen_t = m.grab_buffer
	elif _ledge_seen_t > 0.0 and int(_ledge.get("side", 0)) == s:
		info = _ledge  # край мелькнул в зоне в последние кадры — всё равно цепляемся
	else:
		return
	var half := body_size * 0.5
	var hang := Vector2(float(info["wall_x"]) - s * (half.x + 0.5), float(info["top"]) - m.hang_head_above + half.y)
	if not _box_free(hang):
		return
	global_position = hang
	velocity = Vector2.ZERO
	_ledge = info
	_buffer = 0.0
	_jumping = false
	_apex_ok = false
	facing = s
	change_state(MoveState.HANG)


## Вис: висеть сколько угодно. W или к стене — подтянуться, S — отпустить, Пробел — прыжок от стены.
func _state_hang(dir: float) -> void:
	velocity = Vector2.ZERO
	if is_stunned():
		return
	var s := int(_ledge.get("side", facing))
	if Input.is_action_pressed(&"az_up") or (dir != 0.0 and int(signf(dir)) == s):
		_start_climb(_ledge["stand"], m.climb_time, 0.0, MoveState.CLIMB)
	elif Input.is_action_just_pressed(&"az_jump"):
		velocity = Vector2(-s * m.wall_jump_out, -m.wall_jump_up)
		facing = -s
		_regrab_cd = m.regrab_cooldown
		_wj_lock_t = m.wall_jump_lock
		_wj_dir = s
		_jumping = true
		change_state(MoveState.JUMP)
	elif Input.is_action_just_pressed(&"az_down"):
		_regrab_cd = m.regrab_cooldown
		change_state(MoveState.FALL)


func _start_climb(to: Vector2, time: float, keep_vx: float, kind: MoveState) -> void:
	_climb_from = global_position
	_climb_to = to
	_climb_t = 0.0
	_climb_total = time
	_climb_keep_vx = keep_vx
	velocity = Vector2.ZERO
	change_state(kind)


## Подтягивание и перелезание: сначала вверх, потом через край. Без столкновений по пути.
func _state_climb(delta: float) -> void:
	_climb_t += delta
	var t := clampf(_climb_t / _climb_total, 0.0, 1.0)
	var ty := smoothstep(0.0, 0.6, t)
	var tx := smoothstep(0.35, 1.0, t)
	global_position = Vector2(lerpf(_climb_from.x, _climb_to.x, tx), lerpf(_climb_from.y, _climb_to.y, ty))
	if t >= 1.0:
		global_position = _climb_to
		velocity = Vector2(_climb_keep_vx, 0.0)
		change_state(MoveState.RUN if absf(_climb_keep_vx) > 5.0 else MoveState.STAND)


## Быстрое перелезание: на бегу в препятствие ниже середины тела — через него без остановки.
func _try_vault(dir: float) -> void:
	if dir == 0.0 or absf(velocity.x) > 0.0 and signf(velocity.x) != signf(dir):
		return
	var s := int(signf(dir))
	if not _touching_wall(s):
		return
	var half := body_size * 0.5
	var feet := global_position.y + half.y
	var px := global_position.x + s * (half.x + 3.0)
	var hit := _ray(Vector2(px, feet - m.vault_max_height - 1.0), Vector2(px, feet - 1.0))
	if hit.is_empty():
		return  # выше середины тела — это уже не перелезание
	var top: float = hit.position.y
	var side := _ray(Vector2(global_position.x, top + 2.0), Vector2(global_position.x + s * (half.x + 8.0), top + 2.0))
	if side.is_empty():
		return
	var stand := Vector2(float(side.position.x) + s * (half.x + 2.0), top - half.y - 1.0)
	if not _box_free(stand):
		return
	_start_climb(stand, m.vault_time, s * maxf(absf(velocity.x), m.run_speed * 0.8), MoveState.VAULT)


# --- Подкат, ползком, перекат, урон от падения --------------------------------

## Низкий хитбокс (crouch_height), прижатый к ногам; центр узла не двигается.
func _set_crouch(on: bool) -> void:
	if on == _crouched:
		return
	_crouched = on
	var h := m.crouch_height if on else body_size.y
	_shape.size = Vector2(body_size.x, h)
	_cs.position.y = (body_size.y - h) * 0.5


## Можно ли встать в полный рост (односторонние платформы над головой не мешают).
func _can_stand() -> bool:
	return not _crouched or not test_move(global_transform, Vector2(0.0, -(body_size.y - m.crouch_height)))


## S на земле: на бегу — подкат, стоя или медленно — ползком.
func _ground_down_actions() -> void:
	if _down_edge and _slide_cd <= 0.0 \
			and absf(velocity.x) >= m.run_speed * m.slide_min_speed:
		_start_slide()
	elif Input.is_action_pressed(&"az_down"):
		_set_crouch(true)
		change_state(MoveState.CRAWL)


func _start_slide() -> void:
	_set_crouch(true)
	var s := signf(velocity.x) if velocity.x != 0.0 else float(facing)
	velocity.x = s * maxf(m.slide_speed, absf(velocity.x))
	_slide_t = m.slide_time
	_slide_cd = m.slide_time + m.slide_cooldown
	change_state(MoveState.SLIDE)


## Перекат: низкий хитбокс, скорость бега сохраняется.
func _start_roll() -> void:
	_set_crouch(true)
	var dir := Input.get_axis(&"az_left", &"az_right")
	var s := signf(dir) if dir != 0.0 else (signf(velocity.x) if absf(velocity.x) > 5.0 else float(facing))
	facing = int(s)
	velocity.x = s * maxf(m.run_speed, absf(velocity.x))
	_roll_t = m.roll_time
	change_state(MoveState.ROLL)


## Подкат (трение) и перекат (скорость держится). Из обоих можно прыгнуть, скорость сохраняется.
func _state_slide(delta: float, boost: float) -> void:
	if state == MoveState.SLIDE:
		_slide_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, m.slide_friction * delta)
		if _slide_t <= 0.0:
			_end_low_move()
	else:
		_roll_t -= delta
		if _roll_t <= 0.0:
			_end_low_move()
	_vertical(delta, 0.0, boost)


## Конец подката или переката: есть место — встаём, над головой потолок — ползём.
func _end_low_move() -> void:
	if _can_stand():
		_set_crouch(false)
		change_state(MoveState.RUN if absf(velocity.x) > 5.0 else MoveState.STAND)
	else:
		change_state(MoveState.CRAWL)


## Ползком: пока зажата S или над головой потолок.
func _state_crawl(delta: float, dir: float, slow: float, boost: float) -> void:
	if not Input.is_action_pressed(&"az_down") and _can_stand():
		_set_crouch(false)
		change_state(MoveState.STAND)
		_move(delta, dir, slow, false, boost)
		return
	var rate := m.ground_accel if dir != 0.0 else m.ground_decel
	velocity.x = move_toward(velocity.x, dir * m.crawl_speed * slow, rate * delta)
	_vertical(delta, 0.0, boost)


## Приземление с высоты h (от верхней точки полёта).
func _on_landed(h: float, speed: float) -> void:
	last_fall = h
	var hurt := h > m.safe_fall_height and speed >= m.fall_damage_min_speed
	if _roll_buf > 0.0:
		_roll_buf = 0.0
		if h >= m.roll_min_fall:
			_start_roll()
			if hurt:
				_fall_hurt(h, true)
			return
		if absf(velocity.x) >= m.run_speed * m.slide_min_speed and _slide_cd <= 0.0:
			_start_slide()  # невысоко: S перед касанием — сразу в подкат
			return
	if hurt:
		_land_h = h
		_land_grace = m.roll_window_after


## Жёсткое приземление ждёт roll_window_after: нажал S — перекат, нет — урон и оглушение.
func _land_grace_tick(delta: float) -> void:
	if _land_grace <= 0.0:
		return
	if Input.is_action_just_pressed(&"az_down") and is_on_floor():
		_land_grace = 0.0
		_start_roll()
		_fall_hurt(_land_h, true)
		return
	_land_grace -= delta
	if _land_grace <= 0.0:
		_fall_hurt(_land_h, false)


func _fall_hurt(h: float, rolled: bool) -> void:
	var dmg := m.fall_damage(h)
	if rolled:
		dmg = dmg * m.roll_lethal_mult if h > m.lethal_fall_height else 0.0
	else:
		stun(m.hard_land_stun)
	if dmg > 0.0:
		take_damage(dmg, Vector2.ZERO, true)


# --- Лестница и верёвка ----------------------------------------------------

func _find_ladder() -> Ladder:
	var half := body_size * 0.5
	for n in get_tree().get_nodes_in_group(&"ladders"):
		var l := n as Ladder
		var r := l.zone_rect()
		if absf(global_position.x - r.get_center().x) <= r.size.x * 0.5 + 4.0 \
				and global_position.y + half.y >= r.position.y - 1.0 and global_position.y - half.y <= r.end.y - 8.0:
			return l
	return null


## W / S внутри зоны лестницы — зацепиться; в воздухе — автоматически с зажатым W.
func _try_ladder() -> void:
	if _regrab_cd > 0.0 or state in SUPPORT_STATES or state == MoveState.DASH:
		return
	var lad := _find_ladder()
	if lad == null:
		return
	var r := lad.zone_rect()
	var feet := global_position.y + body_size.y * 0.5
	var up_ok := r.position.y < feet - 4.0  # стоя на верхней площадке, W — обычный прыжок
	var down_ok := r.end.y > feet + 4.0  # стоя у подножия, S — присесть
	var up := Input.is_action_pressed(&"az_up") if not is_on_floor() else Input.is_action_just_pressed(&"az_up")
	var want := (up and up_ok) or (Input.is_action_just_pressed(&"az_down") and down_ok)
	if not want or not _can_stand():
		return
	_set_crouch(false)
	_ladder = lad
	_ladder_down_t = 0.0
	if lad.top_platform:
		if _fall_through == lad.top_platform:
			_fall_through = null
		add_collision_exception_with(lad.top_platform)
	global_position.x = r.get_center().x
	velocity = Vector2.ZERO
	_buffer = 0.0
	_jumping = false
	_apex_ok = false
	_land_grace = 0.0
	change_state(MoveState.LADDER)


## На лестнице: W вверх, S вниз (дольше ladder_slide_delay — съезжаешь), Пробел — спрыгнуть.
func _state_ladder(delta: float, dir: float) -> void:
	_buffer = 0.0
	velocity = Vector2.ZERO
	if not is_instance_valid(_ladder):
		change_state(MoveState.FALL)
		return
	if is_stunned():
		return
	if Input.is_action_just_pressed(&"az_jump") and not Input.is_action_just_pressed(&"az_up"):
		_regrab_cd = m.regrab_cooldown
		if dir != 0.0:
			facing = int(signf(dir))
			velocity = Vector2(facing * m.ladder_jump_out, -m.ladder_jump_up)
			_jumping = true
			change_state(MoveState.JUMP)
		else:
			change_state(MoveState.FALL)
		return
	var vy := 0.0
	if Input.is_action_pressed(&"az_up"):
		vy = -m.ladder_up_speed
		_ladder_down_t = 0.0
	elif Input.is_action_pressed(&"az_down"):
		_ladder_down_t += delta
		vy = m.ladder_slide_speed if _ladder_down_t > m.ladder_slide_delay else m.ladder_down_speed
	else:
		_ladder_down_t = 0.0
	var r := _ladder.zone_rect()
	var half := body_size * 0.5
	if vy < 0.0:
		if _ladder.one_way_top and global_position.y + half.y + vy * delta <= r.position.y:
			global_position.y = r.position.y - half.y - 0.5  # вылез на верхнюю площадку
			change_state(MoveState.STAND)
			return
		if not _ladder.one_way_top:
			var min_y := r.position.y + half.y - 8.0  # верёвка: руки у верхнего края
			vy = maxf(vy, minf(0.0, (min_y - global_position.y) / delta))
	velocity.y = vy


func _ladder_after_move(fall_speed: float) -> void:
	if fall_speed > 0.0 and is_on_floor():
		change_state(MoveState.STAND)  # спустился до земли
	elif not is_instance_valid(_ladder) or global_position.y - body_size.y * 0.5 > _ladder.zone_rect().end.y - 8.0:
		_regrab_cd = m.regrab_cooldown  # съехал с оборванного конца
		change_state(MoveState.FALL)


## Ушли с лестницы: исключение с верхней площадкой снимаем сразу, если стоим на ней,
## иначе чуть позже (как при спрыгивании сквозь платформу).
func _release_ladder() -> void:
	var top: Platform = _ladder.top_platform if is_instance_valid(_ladder) else null
	_ladder = null
	if top == null:
		return
	if global_position.y + body_size.y * 0.5 <= top.global_position.y + 0.5:
		remove_collision_exception_with(top)
	else:
		if is_instance_valid(_fall_through) and _fall_through != top:
			remove_collision_exception_with(_fall_through)
		_fall_through = top
		_fall_through_t = 0.15


# --- Камера ----------------------------------------------------------------

## Взгляд вперёд, мёртвая зона по вертикали, смещение вниз при быстром падении, зум у аномалий,
## тряска не больше shake_max.
func _update_camera(delta: float) -> void:
	var want := facing * m.look_ahead if absf(velocity.x) > 30.0 else 0.0
	_look = move_toward(_look, want, m.look_ahead / m.look_ahead_time * delta)
	var fall_want := m.fall_look if velocity.y > m.fall_look_speed else 0.0
	_fall_look = move_toward(_fall_look, fall_want, m.fall_look / m.fall_look_time * delta)
	var py := global_position.y + m.cam_offset_y
	if py > _cam_y + m.dead_zone_y:
		_cam_y = py - m.dead_zone_y
	elif py < _cam_y - m.dead_zone_y:
		_cam_y = py + m.dead_zone_y
	elif is_on_floor():
		_cam_y = move_toward(_cam_y, py, 60.0 * delta)  # стоя на земле — плавно к центру
	_camera.global_position = Vector2(global_position.x + _look, _cam_y + _fall_look)
	_shake = maxf(0.0, _shake - m.shake_decay * delta)
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	var z := 1.0
	if in_anomaly_field():
		z = m.zoom_field
	if not is_equal_approx(z, _zoom_target):
		_zoom_target = z
		if _zoom_tween:
			_zoom_tween.kill()
		_zoom_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_zoom_tween.tween_property(_camera, "zoom", Vector2(z, z), m.zoom_time)


func in_anomaly_field() -> bool:
	for f in get_tree().get_nodes_in_group(&"anomaly_fields"):
		if (f as AnomalyField).zone_rect().has_point(global_position):
			return true
	return false


func camera_zoom() -> float:
	return _camera.zoom.x


func _state_dash() -> void:
	velocity = Vector2(_dash_dir * m.dash_speed, 0.0)


func _try_interact() -> void:
	var best := Pickup.nearest_in_reach(get_tree(), global_position)
	if best:
		best.call(&"collect", self)


## Q: применить расходник, лучше всего подходящий под недостающее здоровье.
func use_best_consumable() -> void:
	if hp >= max_hp:
		message.emit("Здоровье полное")
		return
	var idx := inventory.best_heal_slot(max_hp - hp)
	if idx < 0:
		message.emit("Нет расходников")
		return
	use_item(idx)


## Применяет расходник из слота рюкзака; false, если нельзя.
func use_item(idx: int) -> bool:
	var it := inventory.get_item(idx)
	if it == null or it.kind != ItemData.Kind.CONSUMABLE:
		return false
	if hp >= max_hp:
		message.emit("Здоровье полное")
		return false
	inventory.consume(idx)
	heal(it.heal)
	message.emit("%s: +%d HP" % [it.display_name, int(it.heal)])
	return true


## Платформа, на которой стоит игрок (null — не стоит или это не Platform).
func _floor_platform() -> Platform:
	if not is_on_floor():
		return null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.7 and c.get_collider() is Platform:
			return c.get_collider() as Platform
	return null


## На короткое время отключаем столкновение с платформой — игрок проваливается сквозь неё.
func _drop_through(plat: Platform) -> void:
	if is_instance_valid(_fall_through):
		remove_collision_exception_with(_fall_through)
	_fall_through = plat
	_fall_through_t = m.drop_through_time
	add_collision_exception_with(plat)
	position.y += 2.0
	_coyote = 0.0
	_buffer = 0.0


# --- Контакт с аномалиями (таблица — AnomalyDb) -----------------------------

## Контакт с аномалией. Урон — с множителями артефактов и только вне неуязвимости (после урона
## 0.6 с аномалии дают баффы, но не ранят). Бафф — не чаще раза в REPEAT_DELAY от одной аномалии.
## opts: damage_scale (доля урона, ток по луже), speed (пиковая скорость в Воронке — для Пращи).
func on_anomaly_contact(type: Anomaly.Type, id: int, opts: Dictionary = {}) -> void:
	if _dead:
		return
	var d := AnomalyDb.get_data(type)
	var hurt := false
	var dmg: float = d.get("damage", 0.0) * stats.damage_mult(type) * float(opts.get("damage_scale", 1.0))
	if dmg > 0.0 and _invuln <= 0.0:
		hurt = take_damage(dmg)
	if type == Anomaly.Type.TRAMPLIN:
		launch(d["launch"] * stats.buff_mult(type))  # подброс — каждый раз, это сама аномалия
	if _clock - float(_buff_seen.get(id, -100.0)) < AnomalyDb.REPEAT_DELAY:
		return
	_buff_seen[id] = _clock
	match type:
		Anomaly.Type.ZHARKA:
			buffs.add(d["buff"], 1.0 + (d["strength"] - 1.0) * stats.buff_mult(type),
				d["duration"] * stats.buff_duration_mult(type))
		Anomaly.Type.TRAMPLIN:
			buffs.add(d["buff"], d["strength"], d["duration"] * stats.buff_duration_mult(type))
		Anomaly.Type.ELECTRA:
			add_charge(d["charges"])
			if hurt and stats.flag(&"no_stun") == null:
				stun(d["stun"])
		Anomaly.Type.VORONKA:
			_sling(float(opts.get("speed", 0.0)), d)
	stats.count_buff(type)
	# Бенгальский огонь: аномалия вскоре после предыдущей продлевает все активные баффы.
	var bengal: Variant = stats.flag(&"bengal")
	if bengal != null and _clock - _last_buff_t <= bengal["window"]:
		buffs.extend_all(bengal["extend"])
	_last_buff_t = _clock


## Урон со временем от аномалии (ядро Воронки): с множителем артефактов, не в неуязвимости.
func anomaly_dot(type: Anomaly.Type, amount: float) -> void:
	if _invuln <= 0.0:
		damage_over_time(amount * stats.damage_mult(type))


## Холодец изнутри: замедление и лечение (с множителями артефактов), вызывать каждый кадр.
func kholodets_tick(delta: float) -> void:
	var d := AnomalyDb.get_data(Anomaly.Type.KHOLODETS)
	set_move_multiplier(minf(1.0, d["run"] * stats.buff_mult(Anomaly.Type.KHOLODETS)))
	if hp < max_hp:
		heal(d["heal"] * stats.heal_mult() * delta)


## Подброс на высоту height px: скорость от текущей гравитации, v = √(2 · g · h)
## (плюс полкадра гравитации — поправка на шаг физики, чтобы высота была ровно height).
func launch(height: float) -> void:
	if state in SUPPORT_STATES:
		_regrab_cd = m.regrab_cooldown
		change_state(MoveState.FALL)
	velocity.y = -(sqrt(2.0 * m.gravity * height) + 0.5 * m.gravity * get_physics_process_delta_time())
	_fall_peak_y = global_position.y
	_dash_t = 0.0
	_jumping = false
	_apex_ok = false
	_coyote = 0.0
	_update_state()


## Праща: на выходе из Воронки скорость сохраняется (до предела), сопротивление выключено.
func _sling(peak: float, d: Dictionary) -> void:
	var cap: float = config.run_speed * d["cap"] * stats.buff_mult(Anomaly.Type.VORONKA)
	var v := minf(peak, cap)
	if v > absf(velocity.x):
		var s := signf(velocity.x) if absf(velocity.x) > 1.0 else float(facing)
		velocity.x = s * v
	_sling_t = d["duration"]
	buffs.add(d["buff"], 1.0, d["duration"])


# --- API для внешних сил -------------------------------------------------

## Резкий толчок. control_lock — сколько секунд управление ослаблено.
func apply_impulse(v: Vector2, control_lock: float = 0.0) -> void:
	if state in SUPPORT_STATES:
		_regrab_cd = m.regrab_cooldown  # толчок срывает с края
		change_state(MoveState.FALL)
	if v.y < 0.0:
		velocity.y = minf(velocity.y, 0.0)  # подброс не должен «съедаться» падением
		_fall_peak_y = global_position.y  # подброс (Трамплин) начинает новый полёт: прежняя высота не считается
	velocity += v
	_dash_t = 0.0
	_jumping = false
	_apex_ok = false
	_update_state()
	_coyote = 0.0
	if control_lock > 0.0:
		_lock = control_lock
		_lock_total = control_lock


## Постоянная сила (px/с²). Вызывать каждый физический кадр, пока сила действует.
func add_external_force(f: Vector2) -> void:
	_force_acc += f


func _set_charge(v: int) -> void:
	charge = clampi(v, 0, max_charge)
	charge_changed.emit(charge, max_charge)


## Добавить заряды рывка (не больше max_charge).
func add_charge(n: int = 1) -> void:
	_set_charge(charge + n)


## Замедление. Вызывать каждый физический кадр; из нескольких источников берётся минимум.
func set_move_multiplier(m: float) -> void:
	_mult_acc = minf(_mult_acc, m)


# --- Параметры движения и состояния ---------------------------------------

## Эффективные параметры = конфиг × множители артефактов × активные баффы.
## Пересчёт при смене артефактов, баффов или HP (Колючка), а не каждый кадр.
func recompute_movement() -> void:
	run_multiplier = stats.run_mult() * buffs.strength(&"forsazh") * _hp_speed_mult()
	jump_multiplier = stats.jump_mult() * buffs.strength(&"legkost")
	gravity_multiplier = stats.gravity_mult()
	m = config.duplicate() as MovementConfig
	m.derive(jump_multiplier, gravity_multiplier, run_multiplier)


## Колючка: бег × (1 + k · (1 − HP / HPмакс)) — чем меньше HP, тем быстрее.
func _hp_speed_mult() -> float:
	var k: float = stats.flag(&"hp_speed", 0.0)
	return 1.0 + k * (1.0 - clampf(hp / maxf(1.0, max_hp), 0.0, 1.0))


## Артефакты изменились: пределы HP и зарядов, движение.
func _on_stats_changed() -> void:
	max_hp = stats.max_hp()
	max_charge = stats.max_charges()
	_set_hp(minf(hp, max_hp))
	_set_charge(charge)
	recompute_movement()


## Гравитация с учётом множителей; при падении — усиленная.
func effective_gravity(falling: bool) -> float:
	return m.gravity * (m.fall_gravity_mult if falling else 1.0)


## Расчётные высота и дальность полного прыжка с разбега (для оверлея F1).
func predicted_jump() -> Vector2:
	var v := m.jump_velocity
	var h := v * v / (2.0 * m.gravity)
	var t_up := v / m.gravity
	var t_down := sqrt(2.0 * h / (m.gravity * m.fall_gravity_mult))
	return Vector2(h, m.run_speed * (t_up + t_down))


func is_stunned() -> bool:
	return _stun > 0.0


func state_name() -> String:
	return STATE_NAMES[state]


func change_state(s: MoveState) -> void:
	if s == state:
		return
	var from := state
	state = s
	if from == MoveState.LADDER:
		_release_ladder()
	var line := "%.2f %s → %s" % [Time.get_ticks_msec() / 1000.0, STATE_NAMES[from], STATE_NAMES[s]]
	state_log.append(line)
	if state_log.size() > 6:
		state_log.remove_at(0)
	if config.log_states:
		print("[player] ", line)
	state_changed.emit(from, s)


## Состояние по факту: рывок, на земле (стоит/бег) или в воздухе (прыжок/падение).
func _update_state() -> void:
	if state in SUPPORT_STATES:
		return  # из виса, подтягивания и лестницы выходят явно
	if state in CROUCH_STATES and is_on_floor():
		return  # из подката, переката и ползком — тоже
	if _dash_t > 0.0:
		change_state(MoveState.DASH)
	elif is_on_floor():
		if _crouched:
			change_state(MoveState.CRAWL)  # приземлился под низким потолком
		else:
			change_state(MoveState.RUN if absf(velocity.x) > 5.0 else MoveState.STAND)
	elif _sliding:
		change_state(MoveState.WALL_SLIDE)
	else:
		change_state(MoveState.JUMP if velocity.y < 0.0 else MoveState.FALL)


# --- Здоровье ------------------------------------------------------------

func take_damage(amount: float, knock: Vector2 = Vector2.ZERO, ignore_invuln: bool = false) -> bool:
	if _dead or (_invuln > 0.0 and not ignore_invuln):
		return false
	_invuln = invuln_time
	_set_hp(maxf(0.0, hp - amount))
	shake(clampf(amount * 0.3, 2.0, m.shake_max))
	if knock != Vector2.ZERO:
		apply_impulse(knock.normalized() * hit_knockback, 0.25)
	_check_death()
	return true


## Урон без неуязвимости, тряски и отброса — для луж и ядер (тикает каждый кадр).
func damage_over_time(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	_set_hp(maxf(0.0, hp - amount))
	_check_death()


## Оглушение: на это время ввод игнорируется.
func stun(time: float) -> void:
	_stun = maxf(_stun, time)


func _check_death() -> void:
	if hp <= 0.0 and not _dead:
		_dead = true
		velocity = Vector2.ZERO
		died.emit()


func heal(amount: float) -> void:
	_set_hp(minf(max_hp, hp + amount))


func is_dead() -> bool:
	return _dead


## Тряска камеры — только от урона и жёсткого приземления, не больше shake_max.
func shake(strength: float) -> void:
	_shake = maxf(_shake, minf(strength, m.shake_max))


func respawn(pos: Vector2, full_heal: bool) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_dash_t = 0.0
	_lock = 0.0
	_stun = 0.0
	_regrab_cd = 0.0
	_wall_jumps = 0
	_roll_buf = 0.0
	_land_grace = 0.0
	_fall_peak_y = pos.y
	change_state(MoveState.FALL)
	_set_crouch(false)
	_dead = false
	visible = true
	_invuln = 0.8
	if full_heal:
		_set_hp(max_hp)
	_cam_y = pos.y + m.cam_offset_y
	_look = 0.0
	_fall_look = 0.0
	_camera.global_position = Vector2(pos.x, _cam_y)
	_camera.reset_smoothing()


## Новый забег: артефакты, расходники, заряды и баффы — с нуля, полное здоровье.
func reset_run(pos: Vector2) -> void:
	inventory.setup()
	buffs.clear()
	_buff_seen.clear()
	_sling_t = 0.0
	stats.reset()
	_set_charge(0)
	respawn(pos, true)


## Новый участок: HP, артефакты и заряды сохраняются, баффы сбрасываются.
func start_section(pos: Vector2) -> void:
	buffs.clear()
	_buff_seen.clear()
	_sling_t = 0.0
	respawn(pos, false)


func set_camera_limits(r: Rect2) -> void:
	_camera.limit_left = int(r.position.x)
	_camera.limit_top = int(r.position.y)
	_camera.limit_right = int(r.end.x)
	_camera.limit_bottom = int(r.end.y)


func _set_hp(v: float) -> void:
	hp = v
	health_changed.emit(hp, max_hp)
	if stats.flag(&"hp_speed") != null:
		recompute_movement()


func _draw() -> void:
	var col := Color("dfe3ee")
	if state == MoveState.DASH:
		col = Color("8fd3ff")
	elif state == MoveState.ROLL:
		col = Color("c8f0c0")
	var half := body_size * 0.5
	var top := half.y - m.crouch_height if _crouched else -half.y
	draw_rect(Rect2(Vector2(-half.x, top), Vector2(body_size.x, half.y - top)), col)
	var eye_x := half.x - 12.0 if facing > 0 else -half.x + 2.0
	draw_rect(Rect2(Vector2(eye_x, top + (5.0 if _crouched else 8.0)), Vector2(10.0, 5.0)), Color("15171c"))
