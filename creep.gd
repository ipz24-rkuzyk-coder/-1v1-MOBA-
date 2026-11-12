extends CharacterBody2D

@export var speed: float = 130.0
var direction: int = 1 # 1 — вправо (синій крип гравця), -1 — вліво (червоний крип бота)

func _ready() -> void:
	if direction == 1:
		$ColorRect.color = Color("#3182ce")
	else:
		$ColorRect.color = Color("#e53e3e")

func _physics_process(_delta: float) -> void:
	velocity = Vector2(direction * speed, 0)
	move_and_slide()
