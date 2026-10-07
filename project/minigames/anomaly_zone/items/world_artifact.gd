class_name WorldArtifact
extends RigidBody2D
## Артефакт, брошенный или положенный в мир. Его аура действует там, где он лежит
## (источник в группе aura_sources), пассивы — нет. Подбирается обратно на E.
## Воронка захватывает его на орбиту, Трамплин подбрасывает.

const ORBIT_SPEED := 1.6  # рад/с при интенсивности 1

var item: ItemData
var aura_r := 160.0

var _t := 0.0
var _orbit: Anomaly = null
var _orbit_angle := 0.0
var _orbit_radius := 0.0
var _orbit_target := 0.0
var _teleport_to := Vector2.INF


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	add_to_group(&"aura_sources")
	add_to_group(&"world_artifacts")
	add_to_group(&"pickups")
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	cs.shape = circle
	add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.2
	mat.friction = 0.8
	physics_material_override = mat
	mass = 0.3
	linear_damp = 0.3
	lock_rotation = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY


# --- Источник ауры ---------------------------------------------------------

func aura_origin() -> Vector2:
	return global_position


func aura_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	if item:
		out.append(item)
	return out


func aura_radius() -> float:
	return aura_r


# --- Подбор (тот же интерфейс, что у Pickup) --------------------------------

func is_in_reach(from: Vector2) -> bool:
	return from.distance_to(global_position) <= 56.0


func collect(player: Player) -> bool:
	if player.inventory.add_item(item):
		queue_free()
		return true
	player.message.emit("Рюкзак полон")
	return false


# --- Воронка и прочие аномалии -----------------------------------------------

func is_orbiting() -> bool:
	return _orbit != null


## Воронка захватывает артефакт: он плавно уходит на круговую орбиту вокруг ядра.
func capture(by: Anomaly, orbit_radius: float) -> void:
	if _orbit == by:
		return
	_orbit = by
	var off := global_position - by.global_position
	_orbit_angle = off.angle()
	_orbit_radius = off.length()
	_orbit_target = orbit_radius
	set_deferred(&"freeze", true)


## Отпустить с орбиты (Воронка уснула или её инвертировали).
func release(push: Vector2) -> void:
	if _orbit == null:
		return
	_orbit = null
	set_deferred(&"freeze", false)
	linear_velocity = push


## Безопасная телепортация физического тела (через _integrate_forces).
func teleport(pos: Vector2) -> void:
	release(Vector2.ZERO)
	_teleport_to = pos


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _teleport_to != Vector2.INF:
		state.transform = Transform2D(0.0, _teleport_to)
		state.linear_velocity = Vector2.ZERO
		_teleport_to = Vector2.INF


func _physics_process(delta: float) -> void:
	if _orbit == null:
		return
	if not is_instance_valid(_orbit) or _orbit.is_asleep():
		release(Vector2.ZERO)
		return
	_orbit_radius = move_toward(_orbit_radius, _orbit_target, 120.0 * delta)
	_orbit_angle += ORBIT_SPEED * _orbit.current_intensity * delta
	global_position = _orbit.global_position + Vector2.from_angle(_orbit_angle) * _orbit_radius


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if item == null:
		return
	AuraSystem.draw_ring(self, aura_r, item.color, _t)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(Vector2.ZERO, 18.0 + 3.0 * pulse, Color(item.color, 0.16))
	item.draw_icon(self, Vector2.ZERO, 18.0)
	if Pickup.nearest_for_player(get_tree()) == self:
		draw_string(ThemeDB.fallback_font, Vector2(-60.0, -26.0), "E — " + item.display_name, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 14, Color(1, 1, 1, 0.95))
