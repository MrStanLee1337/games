extends "res://core/minigame.gd"
## Корень мини-игры «Зона». Пока каркас: показывает нажатые действия для проверки Input Map.

const ACTIONS: Array[StringName] = [
	&"az_left", &"az_right", &"az_up", &"az_jump", &"az_dash", &"az_throw", &"az_interact",
	&"az_inventory", &"az_heal", &"az_respawn", &"az_exit", &"az_toggle_hints", &"az_debug", &"az_give_all",
]

@onready var world: Node2D = $World
@onready var hud: CanvasLayer = $HUD

var _pressed_label: Label


func _ready() -> void:
	_pressed_label = Label.new()
	_pressed_label.position = Vector2(24, 24)
	_pressed_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(_pressed_label)
	start()


func _process(_delta: float) -> void:
	var down: Array[String] = []
	for a in ACTIONS:
		if Input.is_action_pressed(a):
			down.append(String(a))
	_pressed_label.text = "Зона — каркас (этап 1)\nНажато: " + ", ".join(down)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"az_exit"):
		finish(false)
		# Хаба пока нет: при отдельном запуске Esc закрывает игру.
		if get_parent() == get_tree().root:
			get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("12141a"))
