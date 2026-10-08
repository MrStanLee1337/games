class_name Player
extends CharacterBody2D
## Игрок: бег, прыжок, рывок, здоровье, камера.
## Числа движения — в MovementConfig (movement_default.tres); игрок читает эффективную копию `m`
## (конфиг × пассивы артефактов), её пересчитывает recompute_movement().
## Движение разложено по состояниям (enum MoveState); переход — только через change_state().
## Внешние силы (аномалии) действуют через apply_impulse / add_external_force / set_move_multiplier.

signal health_changed(hp: float, max_hp: float)
signal died
## Короткое сообщение для HUD («Рюкзак полон» и т.п.).
signal message(text: String)
signal slot_selected(idx: int)
signal charge_changed(value: int, max_value: int)
signal state_changed(from: MoveState, to: MoveState)

## Группы по схеме ТЗ: на земле (STAND, RUN), в воздухе (JUMP, FALL, DASH), на опоре (пока нет).
## Оглушение — не состояние, а наложение поверх любого (is_stunned()).
enum MoveState { STAND, RUN, JUMP, FALL, DASH }
const STATE_NAMES := ["стоит", "бег", "прыжок", "падение", "рывок"]

@export var config: MovementConfig = preload("res://minigames/anomaly_zone/player/movement_default.tres")

@export_group("Здоровье")
@export var max_hp := 100.0
@export var invuln_time := 0.6
@export var hit_knockback := 260.0

@export_group("Болты")
@export var throw_speed := 420.0
@export var throw_up := 280.0
## Добавка к броску вверх, пока зажато «вверх».
@export var throw_up_boost := 260.0
@export var throw_cooldown := 0.4

@export_group("Инвентарь")
@export var belt_slots := 3

@export_group("Заряд (Батарейка)")
@export var max_charge := 3
@export var overload_damage := 25.0

@export_group("Аура артефактов")
@export var aura_radius := 160.0

# Пассивы артефактов пояса (выставляет BeltAura через set_passives).
var jump_multiplier := 1.0
var gravity_multiplier := 1.0
var regen_per_sec := 0.0

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
## Выбранный слот пояса: его артефакт бросается клавишей G.
var selected_slot := 0
var facing := 1

var _force_acc := Vector2.ZERO
var _mult_acc := 1.0
var _jump_boost_acc := 1.0
var _charged_dash := false
## Скорость падения в момент приземления (держится один кадр) — для желе.
var landing_speed := 0.0
var charge := 0
var _coyote := 0.0
var _buffer := 0.0
var _jumping := false
var _air_dash_used := false
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := 1
var _lock := 0.0
var _lock_total := 1.0
var _invuln := 0.0
var _dead := false
var _stun := 0.0
var _throw_cd := 0.0
var _drop_cd := 0.0
var _fall_through: Platform = null
var _fall_through_t := 0.0
var _shake := 0.0
var _look := 0.0
var _camera: Camera2D


func _ready() -> void:
	recompute_movement()
	add_to_group(&"player")
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	cs.shape = rect
	add_child(cs)
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = m.cam_smoothing
	add_child(_camera)
	_camera.make_current()
	inventory.setup(belt_slots)
	var aura := BeltAura.new()
	aura.radius = aura_radius
	add_child(aura)
	hp = max_hp
	health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	# Силы и замедление, собранные за прошлый кадр, — порядок обработки узлов не важен.
	var ext := _force_acc
	var slow := _mult_acc
	var boost := _jump_boost_acc
	_jump_boost_acc = 1.0
	_force_acc = Vector2.ZERO
	_mult_acc = 1.0
	_tick(delta)

	var stunned := _stun > 0.0
	var dir := 0.0 if stunned else Input.get_axis(&"az_left", &"az_right")
	if dir != 0.0 and state != MoveState.DASH:
		facing = 1 if dir > 0.0 else -1
	if is_on_floor():
		_coyote = m.coyote_time
		_air_dash_used = false
	if not stunned and Input.is_action_just_pressed(&"az_jump"):
		var plat := _floor_platform() if Input.is_action_pressed(&"az_down") else null
		if plat and plat.one_way:
			_drop_through(plat)  # вниз + прыжок на односторонней платформе — спрыгнуть
		else:
			_buffer = m.jump_buffer
	if not stunned and Input.is_action_just_pressed(&"az_dash"):
		_try_dash(dir)
	for i in mini(3, inventory.belt.size()):
		if Input.is_action_just_pressed(StringName("az_slot_%d" % (i + 1))):
			select_slot(i)
	if Input.is_action_just_pressed(&"az_drop"):
		_try_drop()
	if Input.is_action_just_pressed(&"az_throw"):
		_try_throw()
	if Input.is_action_just_pressed(&"az_interact"):
		_try_interact()
	if Input.is_action_just_pressed(&"az_heal"):
		use_best_consumable()

	match state:
		MoveState.DASH:
			_state_dash()
		_:
			# Стоит, бег, прыжок, падение пока делят одну физику (разделятся на этапах 2–4).
			_move(delta, dir, slow, ext != Vector2.ZERO, boost)
	velocity += ext * delta
	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	landing_speed = 0.0
	move_and_slide()
	if not was_on_floor and is_on_floor():
		landing_speed = maxf(0.0, fall_speed)
	_update_state()


func _process(delta: float) -> void:
	var want := facing * m.look_ahead if absf(velocity.x) > 30.0 else 0.0
	_look = lerpf(_look, want, 1.0 - exp(-m.look_ahead_speed * delta))
	_shake = maxf(0.0, _shake - m.shake_decay * delta)
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	_camera.offset = Vector2(_look, m.cam_offset_y) + jitter
	modulate.a = 0.35 if _invuln > 0.0 and int(_invuln * 20.0) % 2 == 0 else 1.0
	queue_redraw()


func _tick(delta: float) -> void:
	_coyote -= delta
	_buffer -= delta
	_dash_cd -= delta
	_lock -= delta
	_invuln -= delta
	_stun -= delta
	_throw_cd -= delta
	_drop_cd -= delta
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
	if regen_per_sec > 0.0 and hp < max_hp:
		_set_hp(minf(max_hp, hp + regen_per_sec * delta))


func _move(delta: float, dir: float, slow: float, pulled: bool, boost: float) -> void:
	# Пока действует блокировка управления, ввод почти не влияет — отброс не гасится.
	var ctl := 1.0
	if _lock > 0.0:
		ctl = lerpf(0.08, 1.0, 1.0 - _lock / _lock_total)
	var on_floor := is_on_floor()
	var target := dir * m.run_speed * slow
	var overspeed := dir != 0.0 and absf(velocity.x) > absf(target) and signf(velocity.x) == signf(dir)
	var rate: float
	if dir != 0.0 and not overspeed:
		rate = m.ground_accel if on_floor else m.air_accel
	else:
		rate = m.ground_decel if on_floor else m.air_decel
		if pulled and on_floor:
			rate *= m.pulled_friction_mult  # под внешней силой трение слабеет, иначе притяжение не чувствуется
	velocity.x = move_toward(velocity.x, target, rate * ctl * delta)

	velocity.y = minf(velocity.y + effective_gravity(velocity.y > 0.0) * delta, m.terminal_fall)

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -m.jump_velocity * boost
		_buffer = 0.0
		_coyote = 0.0
		_jumping = true
	if _jumping:
		if velocity.y >= 0.0:
			_jumping = false
		elif not Input.is_action_pressed(&"az_jump"):
			velocity.y *= m.jump_cut
			_jumping = false


func _try_dash(dir: float) -> void:
	if _dash_cd > 0.0 or _dash_t > 0.0:
		return
	if not is_on_floor():
		if _air_dash_used:
			return
		_air_dash_used = true
	_dash_dir = int(signf(dir)) if dir != 0.0 else facing
	facing = _dash_dir
	_charged_dash = charge > 0
	if _charged_dash:
		_set_charge(charge - 1)
	_dash_t = m.dash_time * (m.charged_dash_time if _charged_dash else 1.0)
	_dash_cd = m.dash_cooldown
	_jumping = false
	velocity.y = 0.0
	change_state(MoveState.DASH)


func _state_dash() -> void:
	velocity = Vector2(_dash_dir * m.dash_speed * (m.charged_dash_speed if _charged_dash else 1.0), 0.0)


func _try_interact() -> void:
	var best := Pickup.nearest_in_reach(get_tree(), global_position)
	if best:
		best.call(&"collect", self)


## Q: применить расходник, лучше всего подходящий под недостающее здоровье.
func use_best_consumable() -> void:
	if hp >= max_hp:
		message.emit("Здоровье полное")
		return
	var slot := inventory.best_heal_slot(max_hp - hp)
	if slot.x < 0:
		message.emit("Нет расходников")
		return
	use_item(slot.x as Inventory.Zone, slot.y)


## Применяет расходник из слота; false, если нельзя.
func use_item(zone: Inventory.Zone, idx: int) -> bool:
	var it := inventory.get_item(zone, idx)
	if it == null or it.kind != ItemData.Kind.CONSUMABLE:
		return false
	if hp >= max_hp:
		message.emit("Здоровье полное")
		return false
	inventory.consume(zone, idx)
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


func select_slot(idx: int) -> void:
	selected_slot = clampi(idx, 0, inventory.belt.size() - 1)
	slot_selected.emit(selected_slot)


## G — бросить артефакт из выбранного слота пояса; G с зажатым «вниз» — положить под ноги.
func _try_drop() -> void:
	if _drop_cd > 0.0:
		return
	var it := inventory.get_item(Inventory.Zone.BELT, selected_slot)
	if it == null:
		message.emit("Слот %d пуст" % (selected_slot + 1))
		return
	_drop_cd = 0.3
	inventory.take(Inventory.Zone.BELT, selected_slot)
	var wa := WorldArtifact.new()
	wa.item = it
	wa.aura_r = aura_radius
	get_parent().add_child(wa)
	if Input.is_action_pressed(&"az_down"):
		wa.global_position = global_position + Vector2(facing * 16.0, 8.0)
		message.emit("Положен: " + it.display_name)
	else:
		wa.global_position = global_position + Vector2(facing * 14.0, -10.0)
		wa.linear_velocity = _throw_velocity()
		message.emit("Брошен: " + it.display_name)


func _throw_velocity() -> Vector2:
	var up := throw_up + (throw_up_boost if Input.is_action_pressed(&"az_up") else 0.0)
	return Vector2(facing * throw_speed + velocity.x * 0.4, -up)


func _try_throw() -> void:
	if _throw_cd > 0.0:
		return
	_throw_cd = throw_cooldown
	var b := Bolt.new()
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(facing * 14.0, -10.0)
	b.linear_velocity = _throw_velocity()


# --- API для внешних сил -------------------------------------------------

## Резкий толчок. control_lock — сколько секунд управление ослаблено.
func apply_impulse(v: Vector2, control_lock: float = 0.0) -> void:
	if v.y < 0.0:
		velocity.y = minf(velocity.y, 0.0)  # подброс не должен «съедаться» падением
	velocity += v
	_dash_t = 0.0
	_jumping = false
	_update_state()
	_coyote = 0.0
	if control_lock > 0.0:
		_lock = control_lock
		_lock_total = control_lock


## Постоянная сила (px/с²). Вызывать каждый физический кадр, пока сила действует.
func add_external_force(f: Vector2) -> void:
	_force_acc += f


## Временная добавка к прыжку (желе). Вызывать каждый кадр; берётся максимум.
func set_jump_boost(m: float) -> void:
	_jump_boost_acc = maxf(_jump_boost_acc, m)


## Разряд Электры ушёл в Батарейку на поясе. Перегрузка — удар по самому игроку.
func absorb_discharge() -> void:
	if charge >= max_charge:
		_set_charge(0)
		message.emit("Перегрузка Батарейки!")
		take_damage(overload_damage, Vector2(-facing, -1.0), true)
		stun(0.5)
	else:
		_set_charge(charge + 1)


func has_belt_artifact(id: StringName) -> bool:
	for it in inventory.belt_artifacts():
		if it.id == id:
			return true
	return false


func _set_charge(v: int) -> void:
	charge = v
	charge_changed.emit(charge, max_charge)


## Замедление. Вызывать каждый физический кадр; из нескольких источников берётся минимум.
func set_move_multiplier(m: float) -> void:
	_mult_acc = minf(_mult_acc, m)


# --- Параметры движения и состояния ---------------------------------------

## Пассивы артефактов пояса меняют эффективные параметры (вызывает BeltAura при смене пояса).
func set_passives(jump_mult: float, grav_mult: float, regen: float) -> void:
	jump_multiplier = jump_mult
	gravity_multiplier = grav_mult
	regen_per_sec = regen
	recompute_movement()


## Эффективные параметры = конфиг × пассивы. Пересчёт при смене пояса, а не каждый кадр.
func recompute_movement() -> void:
	m = config.duplicate() as MovementConfig
	m.jump_velocity = config.jump_velocity * jump_multiplier
	m.gravity = config.gravity * gravity_multiplier


## Гравитация с учётом пассивов; при падении — усиленная. Нужна аномалиям (пар, парение).
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
	var line := "%.2f %s → %s" % [Time.get_ticks_msec() / 1000.0, STATE_NAMES[from], STATE_NAMES[s]]
	state_log.append(line)
	if state_log.size() > 6:
		state_log.remove_at(0)
	if config.log_states:
		print("[player] ", line)
	state_changed.emit(from, s)


## Состояние по факту: рывок, на земле (стоит/бег) или в воздухе (прыжок/падение).
func _update_state() -> void:
	if _dash_t > 0.0:
		change_state(MoveState.DASH)
	elif is_on_floor():
		change_state(MoveState.RUN if absf(velocity.x) > 5.0 else MoveState.STAND)
	else:
		change_state(MoveState.JUMP if velocity.y < 0.0 else MoveState.FALL)


# --- Здоровье ------------------------------------------------------------

func take_damage(amount: float, knock: Vector2 = Vector2.ZERO, ignore_invuln: bool = false) -> bool:
	if _dead or (_invuln > 0.0 and not ignore_invuln):
		return false
	_invuln = invuln_time
	_set_hp(maxf(0.0, hp - amount))
	shake(clampf(amount * 0.3, 3.0, 9.0))
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


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func respawn(pos: Vector2, full_heal: bool) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_dash_t = 0.0
	_lock = 0.0
	_stun = 0.0
	change_state(MoveState.FALL)
	_dead = false
	visible = true
	_invuln = 0.8
	if full_heal:
		_set_hp(max_hp)
	_camera.reset_smoothing()


func set_camera_limits(r: Rect2) -> void:
	_camera.limit_left = int(r.position.x)
	_camera.limit_top = int(r.position.y)
	_camera.limit_right = int(r.end.x)
	_camera.limit_bottom = int(r.end.y)


func _set_hp(v: float) -> void:
	hp = v
	health_changed.emit(hp, max_hp)


func _draw() -> void:
	var col := Color("dfe3ee")
	if state == MoveState.DASH:
		col = Color("ffe46b") if _charged_dash else Color("8fd3ff")
	var half := body_size * 0.5
	draw_rect(Rect2(-half, body_size), col)
	var eye_x := half.x - 12.0 if facing > 0 else -half.x + 2.0
	draw_rect(Rect2(Vector2(eye_x, -half.y + 8.0), Vector2(10.0, 5.0)), Color("15171c"))
