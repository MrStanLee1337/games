extends RefCounted
## Чистая логика паззла без UI: состояние засовов, ход шестерёнки, проверка победы.

const SCALE_MAX := 4

var open: Array[int] = []
var gears: Array[Dictionary] = []  # {индекс засова: сдвиг}
var start: Array[int] = []
var state: Array[int] = []
var moves := 0


func _init(level: Dictionary) -> void:
	open.assign(level["open"])
	gears.assign(level["gears"])
	start.assign(level["start"])
	reset()


func reset() -> void:
	state = start.duplicate()
	moves = 0


## Возвращает индексы засовов, которые упёрлись; пустой массив — ход применён.
func turn(gear: int, dir: int) -> Array[int]:
	var blocked: Array[int] = []
	for bolt in gears[gear]:
		var v: int = state[bolt] + gears[gear][bolt] * dir
		if v < 0 or v > SCALE_MAX:
			blocked.append(bolt)
	if not blocked.is_empty():
		return blocked
	for bolt in gears[gear]:
		state[bolt] += gears[gear][bolt] * dir
	moves += 1
	return blocked


func is_open(bolt: int) -> bool:
	return state[bolt] == open[bolt]


func is_solved() -> bool:
	for i in state.size():
		if not is_open(i):
			return false
	return true
