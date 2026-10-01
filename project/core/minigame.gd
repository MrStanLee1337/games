extends Control
## Единый интерфейс мини-игры. Хаб знает только об этих сигналах.

signal started
signal finished(won: bool, reward: Dictionary)


func start() -> void:
	started.emit()


func finish(won: bool, reward: Dictionary = {}) -> void:
	finished.emit(won, reward)
