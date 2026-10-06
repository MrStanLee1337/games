class_name Player
extends CharacterBody2D
## Игрок: бег, прыжок, рывок, здоровье, камера.
## Внешние силы (аномалии) действуют через apply_impulse / add_external_force / set_move_multiplier.

signal health_changed(hp: float, max_hp: float)
signal died

@export_group("Тело")
@export var body_size := Vector2(24, 40)

@export_group("Бег")
@export var max_speed := 300.0
@export var ground_accel := 2800.0
@export var ground_decel := 3600.0
@export var air_accel := 1500.0
@export var air_decel := 700.0

@export_group("Прыжок")
@export var jump_velocity := 560.0
## Во сколько раз обрезается скорость подъёма, когда кнопку отпустили.
@export_range(0.0, 1.0) var jump_cut := 0.4
@export var coyote_time := 0.1
@export var jump_buffer := 0.12
@export var gravity := 1500.0
@export var fall_gravity_mult := 1.6
@export var max_fall_speed := 900.0

@export_group("Рывок")
@export var dash_speed := 720.0
@export var dash_time := 0.18
@export var dash_cooldown := 0.4

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

@export_group("Камера")
@export var look_ahead := 90.0
@export var look_ahead_speed := 3.0
@export var cam_smoothing := 7.0
@export var shake_decay := 40.0

# Множители, которые потом выставляют артефакты.
var jump_multiplier := 1.0
var gravity_multiplier := 1.0
var regen_per_sec := 0.0

var hp := 0.0
var facing := 1

var _force_acc := Vector2.ZERO
var _mult_acc := 1.0
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
var _shake := 0.0
var _look := 0.0
var _camera: Camera2D


func _ready() -> void:
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
	_camera.position_smoothing_speed = cam_smoothing
	add_child(_camera)
	_camera.make_current()
	hp = max_hp
	health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	# Силы и замедление, собранные за прошлый кадр, — порядок обработки узлов не важен.
	var ext := _force_acc
	var slow := _mult_acc
	_force_acc = Vector2.ZERO
	_mult_acc = 1.0
	_tick(delta)

	var stunned := _stun > 0.0
	var dir := 0.0 if stunned else Input.get_axis(&"az_left", &"az_right")
	if dir != 0.0 and _dash_t <= 0.0:
		facing = 1 if dir > 0.0 else -1
	if is_on_floor():
		_coyote = coyote_time
		_air_dash_used = false
	if not stunned and Input.is_action_just_pressed(&"az_jump"):
		_buffer = jump_buffer
	if not stunned and Input.is_action_just_pressed(&"az_dash"):
		_try_dash(dir)
	if Input.is_action_just_pressed(&"az_throw"):
		_try_throw()

	if _dash_t > 0.0:
		velocity = Vector2(_dash_dir * dash_speed, 0.0)
	else:
		_move(delta, dir, slow, ext != Vector2.ZERO)
	velocity += ext * delta
	move_and_slide()


func _process(delta: float) -> void:
	var want := facing * look_ahead if absf(velocity.x) > 30.0 else 0.0
	_look = lerpf(_look, want, 1.0 - exp(-look_ahead_speed * delta))
	_shake = maxf(0.0, _shake - shake_decay * delta)
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	_camera.offset = Vector2(_look, -24.0) + jitter
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
	if _dash_t > 0.0:
		_dash_t -= delta
		if _dash_t <= 0.0:
			velocity.x = _dash_dir * max_speed * 0.9
	if regen_per_sec > 0.0 and hp < max_hp:
		_set_hp(minf(max_hp, hp + regen_per_sec * delta))


func _move(delta: float, dir: float, slow: float, pulled: bool) -> void:
	# Пока действует блокировка управления, ввод почти не влияет — отброс не гасится.
	var ctl := 1.0
	if _lock > 0.0:
		ctl = lerpf(0.08, 1.0, 1.0 - _lock / _lock_total)
	var on_floor := is_on_floor()
	var target := dir * max_speed * slow
	var overspeed := dir != 0.0 and absf(velocity.x) > absf(target) and signf(velocity.x) == signf(dir)
	var rate: float
	if dir != 0.0 and not overspeed:
		rate = ground_accel if on_floor else air_accel
	else:
		rate = ground_decel if on_floor else air_decel
		if pulled and on_floor:
			rate *= 0.25  # под действием внешней силы трение слабеет, иначе притяжение не чувствуется
	velocity.x = move_toward(velocity.x, target, rate * ctl * delta)

	var g := gravity * gravity_multiplier
	if velocity.y > 0.0:
		g *= fall_gravity_mult
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -jump_velocity * jump_multiplier
		_buffer = 0.0
		_coyote = 0.0
		_jumping = true
	if _jumping:
		if velocity.y >= 0.0:
			_jumping = false
		elif not Input.is_action_pressed(&"az_jump"):
			velocity.y *= jump_cut
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
	_dash_t = dash_time
	_dash_cd = dash_cooldown
	_jumping = false
	velocity.y = 0.0


func _try_throw() -> void:
	if _throw_cd > 0.0:
		return
	_throw_cd = throw_cooldown
	var b := Bolt.new()
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(facing * 14.0, -10.0)
	var up := throw_up + (throw_up_boost if Input.is_action_pressed(&"az_up") else 0.0)
	b.linear_velocity = Vector2(facing * throw_speed + velocity.x * 0.4, -up)


# --- API для внешних сил -------------------------------------------------

## Резкий толчок. control_lock — сколько секунд управление ослаблено.
func apply_impulse(v: Vector2, control_lock: float = 0.0) -> void:
	if v.y < 0.0:
		velocity.y = minf(velocity.y, 0.0)  # подброс не должен «съедаться» падением
	velocity += v
	_dash_t = 0.0
	_jumping = false
	_coyote = 0.0
	if control_lock > 0.0:
		_lock = control_lock
		_lock_total = control_lock


## Постоянная сила (px/с²). Вызывать каждый физический кадр, пока сила действует.
func add_external_force(f: Vector2) -> void:
	_force_acc += f


## Замедление. Вызывать каждый физический кадр; из нескольких источников берётся минимум.
func set_move_multiplier(m: float) -> void:
	_mult_acc = minf(_mult_acc, m)


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
	var col := Color("8fd3ff") if _dash_t > 0.0 else Color("dfe3ee")
	var half := body_size * 0.5
	draw_rect(Rect2(-half, body_size), col)
	var eye_x := half.x - 12.0 if facing > 0 else -half.x + 2.0
	draw_rect(Rect2(Vector2(eye_x, -half.y + 8.0), Vector2(10.0, 5.0)), Color("15171c"))
