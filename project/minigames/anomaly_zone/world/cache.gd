class_name Cache
extends Node2D
## Тайник: E рядом — окно выбора одного артефакта из трёх (или «Пропустить»). Открытый тайник пустеет.
## Обычный стоит на трассе и предлагает только обычные артефакты; редкий — в стороне или среди
## аномалий, одна его карта всегда редкая. Карты генерируются в момент открытия (под текущий билд)
## общим RandomNumberGenerator забега. Обычный тайник кладёт в рюкзак ещё и расходник.
## Начало координат — точка на полу под тайником.

signal opened(cache: Cache)

@export var rare := false
@export var interact_radius := 60.0

var is_open := false
var _t := 0.0
var _near := false


func _ready() -> void:
	add_to_group(&"pickups")  # E обрабатывает Pickup.nearest_in_reach
	add_to_group(&"caches")
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	_near = not is_open and Pickup.nearest_for_player(get_tree()) == self
	queue_redraw()


func is_in_reach(from: Vector2) -> bool:
	return not is_open and from.distance_to(global_position + Vector2(0, -20)) <= interact_radius


## Игрок нажал E: открыть (выбор карт ведёт zone.gd).
func collect(_player: Player) -> bool:
	if is_open:
		return false
	is_open = true
	opened.emit(self)
	return true


## Карты тайника: только артефакты, которых у игрока нет; одна — «под билд» (тег самого частого
## типа баффов или универсальный), если такая осталась; в редком тайнике одна карта всегда редкая.
static func generate_cards(is_rare: bool, owned: Array[StringName], favorite: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var pool: Array[StringName] = []
	for d in ArtifactDb.ARTIFACTS:
		if d["id"] in owned:
			continue
		if not is_rare and d["rarity"] != &"common":
			continue
		pool.append(d["id"])
	var cards: Array[StringName] = []
	var n := mini(3, pool.size())
	if favorite >= 0:
		var fit: Array[StringName] = []
		for id in pool:
			var tag: int = ArtifactDb.data(id).get("tag", -1)
			if tag == favorite or tag == -1:
				fit.append(id)
		if not fit.is_empty():
			_take(fit[rng.randi_range(0, fit.size() - 1)], pool, cards)
	if is_rare and not cards.any(func(id: StringName) -> bool: return _is_rare(id)):
		var rares: Array[StringName] = []
		for id in pool:
			if _is_rare(id):
				rares.append(id)
		if not rares.is_empty():
			_take(rares[rng.randi_range(0, rares.size() - 1)], pool, cards)
	while cards.size() < n:
		_take(pool[rng.randi_range(0, pool.size() - 1)], pool, cards)
	# Перемешать, чтобы карта под билд не стояла всегда первой.
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
	return cards


## Расходник «в придачу» из обычного тайника: бинт чаще, аптечка реже.
static func bonus_consumable(rng: RandomNumberGenerator) -> StringName:
	return &"bint" if rng.randf() < 0.7 else &"aptechka"


static func _is_rare(id: StringName) -> bool:
	return ArtifactDb.data(id).get("rarity", &"common") == &"rare"


static func _take(id: StringName, pool: Array[StringName], cards: Array[StringName]) -> void:
	pool.erase(id)
	cards.append(id)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var gold := Color("ffd24a")
	var body := Rect2(Vector2(-24.0, -34.0), Vector2(48.0, 34.0))
	if rare and not is_open:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(Vector2(0, -18), 40.0 + 5.0 * pulse, Color(gold, 0.08 + 0.06 * pulse))
	draw_rect(body, Color("3a4152") if not is_open else Color("262a33"))
	draw_rect(body, gold if rare else Color("7d879c"), false, 2.0)
	for k in 3:
		draw_line(Vector2(-24.0 + 12.0 * (k + 1), -34.0), Vector2(-24.0 + 12.0 * (k + 1), 0.0), Color(0, 0, 0, 0.25), 2.0)
	if is_open:
		# Откинутая крышка.
		draw_line(Vector2(-24.0, -34.0), Vector2(-34.0, -58.0), Color("5a6375"), 4.0)
	else:
		draw_rect(Rect2(Vector2(-26.0, -40.0), Vector2(52.0, 8.0)), Color("4f596e"))
		draw_rect(Rect2(Vector2(-4.0, -26.0), Vector2(8.0, 10.0)), gold if rare else Color("aab1c2"))
	if _near:
		draw_string(font, Vector2(-80.0, -70.0), "E — " + ("редкий тайник" if rare else "тайник"), HORIZONTAL_ALIGNMENT_CENTER, 160.0, 14,
			Color(1, 1, 1, 0.95))
