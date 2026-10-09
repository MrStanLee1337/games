@tool
class_name Anomaly
extends Area2D
## Базовая аномалия. Наследники задают форму (_new_shape/_apply_shape), поведение (_tick) и вид (_draw).
## Артефакты не упоминаются: аура игрока лишь передаёт словарь эффектов через set_aura().

enum Type { ZHARKA, ELECTRA, TRAMPLIN, VORONKA, KHOLODETS }
enum State { IDLE, TELEGRAPH, ACTIVE, COOLDOWN }

const INTENSITY_MAX := 3.0
const SLEEP_BELOW := 0.12
## Скорость сглаживания интенсивности: ~95% за 0.6 с.
const SMOOTH := 5.0

@export var base_intensity := 1.0:
	set(v):
		base_intensity = v
		if Engine.is_editor_hint():
			current_intensity = v
			_rebuild()

var anomaly_type: Type = Type.ZHARKA
var current_intensity := 1.0
## Эффекты ауры артефакта игрока (AuraSystem); пусто — аура не достаёт. Смысл полей задаёт наследник.
var aura: Dictionary = {}
var state: State = State.IDLE

var _state_t := 0.0
var _time := 0.0
var _phase := 0.0  # фаза анимации: чем сильнее аномалия, тем быстрее бежит
var _bodies: Array[Node2D] = []
var _shape_node: CollisionShape2D
var _last_scale := -1.0


func _ready() -> void:
	current_intensity = base_intensity
	collision_layer = 0
	collision_mask = 2  # игрок
	monitorable = false
	_rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group(&"anomalies")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# --- Публичный интерфейс ---------------------------------------------------

func set_aura(effects: Dictionary) -> void:
	aura = effects


func target_intensity() -> float:
	return clampf(base_intensity, 0.0, INTENSITY_MAX)


func reset_state() -> void:
	aura = {}
	current_intensity = base_intensity
	_set_state(State.IDLE)
	_reset_extra()


# --- Общее для наследников -------------------------------------------------

func is_asleep() -> bool:
	return current_intensity < SLEEP_BELOW


## Множитель радиуса и частоты срабатываний: ×(0.6 + 0.4·I).
func scale_factor() -> float:
	return 0.6 + 0.4 * current_intensity


func dmg(base: float) -> float:
	return base * current_intensity


## Серость/тусклость при слабой интенсивности, яркость при сильной.
func tint(c: Color) -> Color:
	var out := c
	var i := current_intensity
	if i < 1.0:
		var g := c.get_luminance()
		out = c.lerp(Color(g, g, g, c.a), (1.0 - i) * 0.85)
		out.a *= lerpf(0.25, 1.0, clampf(i, 0.0, 1.0))
	elif i > 1.0:
		out = c.lightened(clampf((i - 1.0) * 0.25, 0.0, 0.5))
	return out


## Расстояние от точки до края зоны аномалии (0, если точка внутри). Нужно ауре артефактов.
func edge_distance(p: Vector2) -> float:
	return maxf(0.0, p.distance_to(global_position) - _extent())


## Центр видимой части (для связей между аномалиями).
func visual_center() -> Vector2:
	return global_position


## Над какой точкой подписывать аномалию (оверлей F1).
func top_point() -> Vector2:
	return global_position + Vector2(0.0, -_extent() - 16.0)


## Габариты зоны в мировых координатах — для взаимодействий аномалий друг с другом.
func world_bounds() -> Rect2:
	var e := _extent()
	return Rect2(global_position - Vector2(e, e), Vector2(e, e) * 2.0)


## Зазор между двумя прямоугольниками (0 — касаются или пересекаются).
static func rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()


## Доп. строка для отладочного оверлея (F1).
func debug_extra() -> String:
	return ""


func get_shape_node() -> CollisionShape2D:
	return _shape_node


func _extent() -> float:
	return 0.0


static func _rect_distance(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0
	_on_state(s)


func _players() -> Array[Player]:
	var out: Array[Player] = []
	for b in _bodies:
		if b is Player:
			out.append(b as Player)
	return out


## Игрок внутри — «провокатор» для Жарки, Электры, Трамплина.
func _has_provoker() -> bool:
	for b in _bodies:
		if b is Player:
			return true
	return false


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := target_intensity()
	current_intensity = lerpf(current_intensity, target, 1.0 - exp(-SMOOTH * delta))
	if absf(current_intensity - target) < 0.002:
		current_intensity = target
	var s := scale_factor()
	if absf(s - _last_scale) > 0.004:
		_last_scale = s
		_apply_shape(s)
	_state_t += delta
	for i in range(_bodies.size() - 1, -1, -1):
		if not is_instance_valid(_bodies[i]):
			_bodies.remove_at(i)
	_tick(delta)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_phase += delta * (0.5 + 0.5 * current_intensity)
	queue_redraw()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape_node == null:
		_shape_node = CollisionShape2D.new()
		_shape_node.shape = _new_shape()
		add_child(_shape_node)
	_last_scale = scale_factor()
	_apply_shape(_last_scale)
	queue_redraw()


func _on_body_entered(b: Node2D) -> void:
	if not _bodies.has(b):
		_bodies.append(b)


func _on_body_exited(b: Node2D) -> void:
	_bodies.erase(b)


# --- Переопределяется в наследниках ---------------------------------------

func _new_shape() -> Shape2D:
	return CircleShape2D.new()


func _apply_shape(_s: float) -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _on_state(_s: State) -> void:
	pass


func _reset_extra() -> void:
	pass
