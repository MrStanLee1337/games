class_name RunManager
extends Node
## Состояние одного забега: сид случайности (содержимое тайников), маршрут из участков и выбор
## на развилке. Узел живёт в корне «Зоны» (сцену при рестарте не перезагружаем, поэтому
## отдельный autoload не нужен): zone.gd вызывает new_run() на старте и после смерти.

## Маршрут: участок 1 → развилка (2а или 2б) → участок 3.
const SECTION_1 := &"s1"
const BRANCH_A := &"s2a"
const BRANCH_B := &"s2b"
const SECTION_3 := &"s3"

var seed_value := 0
var rng := RandomNumberGenerator.new()
## Номер текущего участка в маршруте (0..2) и выбранная ветка.
var index := 0
var branch: StringName = &""


## Новый забег. seed < 0 — случайный сид (в тестах задаётся явно для повторяемости).
func new_run(seed: int = -1) -> void:
	seed_value = seed if seed >= 0 else randi()
	rng.seed = seed_value
	index = 0
	branch = &""


## id текущего участка.
func section_id() -> StringName:
	match index:
		0:
			return SECTION_1
		1:
			return branch if branch != &"" else BRANCH_A
		_:
			return SECTION_3


func section_count() -> int:
	return 3


func is_last() -> bool:
	return index >= section_count() - 1


func choose_branch(b: StringName) -> void:
	branch = b


## Следующий участок; false, если участки кончились.
func advance() -> bool:
	if is_last():
		return false
	index += 1
	return true
