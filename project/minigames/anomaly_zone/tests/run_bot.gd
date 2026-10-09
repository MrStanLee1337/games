extends RefCounted
## Бот-бегун для проверки баланса участков (tests/run_balance.gd). Каждый физический кадр
## выставляет действия ввода: держит «вправо», прыгает через стены и ямы (со стенами — зацеп и
## подтягивание сами), на развилках выбирает дорогу:
##   safe — сбегает в ров и выходит по ступеням, аномалий и тайников не трогает;
##   fast — прыгает на скоростную дорогу поверху, рывок — если прыжок не долетает;
##   detour = true — по пути заходит на башню к редкому тайнику (берёт первую карту).

var p: Player
var zone: Node
var mode: StringName = &"safe"
var detour := false
## Какую дверь выбрать на развилке (RunManager.BRANCH_A / BRANCH_B).
var branch: StringName = &"s2a"

var _hold := 0
var _dash_hold := 0
var _dashed := false
var _takeoff_feet := 0.0
var _stage := 0
var _tower_x := INF
var _tower_cache: Cache = null


func setup(zone_node: Node, bot_mode: StringName, go_detour: bool = false) -> void:
	zone = zone_node
	p = zone.player
	mode = bot_mode
	detour = go_detour
	_stage = 0
	_tower_cache = null
	_tower_x = INF
	if detour:
		for n in zone.level.get_children():
			if n is Cache and (n as Cache).rare:
				_tower_cache = n
		for n in zone.level.get_children():
			if n is Ladder and _tower_cache and absf(n.global_position.x - (_tower_cache.global_position.x - 140.0)) < 5.0:
				_tower_x = n.global_position.x + 14.0


func release_all() -> void:
	for a in ["az_right", "az_left", "az_jump", "az_up", "az_down", "az_dash", "az_interact"]:
		Input.action_release(a)


func _ray(a: Vector2, b: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1, [p.get_rid()])
	return p.get_world_2d().direct_space_state.intersect_ray(q)


## Один кадр решения. Вызывать до physics_frame.
func tick() -> void:
	if zone.cache_choice.is_open():
		zone.cache_choice.choose(0)
		return
	if detour and _tower_cache and _detour_tick():
		return
	if zone._in_shelter:
		_door_tick()
		return
	var half := p.body_size * 0.5
	var pos := p.global_position
	var feet := pos.y + half.y
	Input.action_press("az_right")
	if _dash_hold > 0:
		_dash_hold -= 1
		if _dash_hold == 0:
			Input.action_release("az_dash")
	if _hold > 0:
		_hold -= 1
		if _hold == 0:
			Input.action_release("az_jump")
		return
	if p.is_on_floor():
		_dashed = false
		_takeoff_feet = feet
		var wall := not _ray(pos + Vector2(half.x - 2.0, 12.0), pos + Vector2(half.x + 20.0, 12.0)).is_empty() \
			or not _ray(pos + Vector2(half.x - 2.0, -12.0), pos + Vector2(half.x + 20.0, -12.0)).is_empty()
		var ahead := pos.x + half.x + 4.0
		var down := _ray(Vector2(ahead, feet - 4.0), Vector2(ahead, feet + 700.0))
		var depth: float = INF if down.is_empty() else float(down.position.y) - feet
		var jump := false
		if wall:
			jump = true
		elif depth > 30.0:
			if depth > 450.0:
				jump = true  # яма
			elif mode == &"fast":
				jump = true  # ров: скоростная дорога поверху
		if jump:
			Input.action_press("az_jump")
			_hold = 32
	elif mode == &"fast" and not _dashed and p.charge > 0 and p.velocity.y > 0.0 and feet >= _takeoff_feet - 4.0:
		# Не долетает до площадки — рывок.
		if _ray(pos, pos + Vector2(0.0, half.y + 40.0)).is_empty():
			Input.action_press("az_dash")
			_dash_hold = 2
			_dashed = true


## В укрытии с развилкой: дойти до своей двери и нажать E.
func _door_tick() -> void:
	var rs = zone.level as RunSection
	if rs == null or rs.doors.is_empty():
		release_all()
		return
	for d in rs.doors:
		if d.branch == branch:
			var dx: float = d.global_position.x - p.global_position.x
			if absf(dx) > 20.0:
				Input.action_press("az_right" if dx > 0.0 else "az_left")
				Input.action_release("az_left" if dx > 0.0 else "az_right")
				Input.action_release("az_interact")
			else:
				release_all()
				_hold += 1
				if _hold % 6 < 3:
					Input.action_press("az_interact")


## Крюк к редкому тайнику на башне: лестница вверх, тайник, спрыгнуть с перекатом. true — кадр занят.
func _detour_tick() -> bool:
	var pos := p.global_position
	match _stage:
		0:
			if pos.x >= _tower_x - 3.0 and p.is_on_floor():
				release_all()
				Input.action_press("az_up")
				_stage = 1
				return true
			return false
		1:
			Input.action_press("az_up")
			if p.state != Player.MoveState.LADDER and p.is_on_floor() and pos.y < _tower_cache.global_position.y:
				Input.action_release("az_up")
				_stage = 2
			return true
		2:
			Input.action_press("az_right")
			if absf(pos.x - _tower_cache.global_position.x) < 24.0:
				Input.action_release("az_right")
				Input.action_press("az_interact")
				_stage = 3
			return true
		3:
			# E держим 3 кадра, отпускаем 3 кадра, пока тайник не откроется.
			_hold += 1
			if _hold % 6 < 3:
				Input.action_press("az_interact")
			else:
				Input.action_release("az_interact")
			if _tower_cache.is_open:
				Input.action_release("az_interact")
				_hold = 0
				_stage = 4
			return true
		4:
			Input.action_press("az_right")
			# Спрыгнул с башни — перекат перед касанием (S за ~60 px до пола).
			if not p.is_on_floor() and p.velocity.y > 0.0:
				var half := p.body_size * 0.5
				if not _ray(pos + Vector2(0.0, half.y), pos + Vector2(0.0, half.y + 60.0)).is_empty():
					Input.action_press("az_down")
			if p.is_on_floor() and pos.y > _tower_cache.global_position.y + 100.0:
				Input.action_release("az_down")
				_stage = 5
			return true
	return false
