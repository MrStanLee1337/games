class_name Bolt
extends RigidBody2D
## Болт: бесконечный инструмент разведки. Летит по дуге, исчезает через LIFETIME секунд.

const LIFETIME := 5.0

var _age := 0.0
var _gone := false
var _hit := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group(&"bolts")
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	cs.shape = circle
	add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.25
	mat.friction = 0.6
	physics_material_override = mat
	mass = 0.2
	linear_damp = 0.15
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)


## Первый удар болта шумит (игрок испускает сигнал шума за болт).
func _on_body_entered(_b: Node) -> void:
	if _hit:
		return
	_hit = true
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p:
		p.emit_noise(global_position, p.m.noise_bolt)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	elif _age > LIFETIME - 0.6:
		modulate.a = (LIFETIME - _age) / 0.6


## Холодец: болт тонет и пропадает.
func sink() -> void:
	if _gone:
		return
	_gone = true
	set_deferred("freeze", true)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 10.0, 0.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(queue_free)


## Воронка: болт поглощён ядром.
func absorb() -> void:
	if _gone:
		return
	_gone = true
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color("c9ced9"))
	draw_circle(Vector2.ZERO, 2.0, Color("15171c"))
