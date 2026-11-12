extends Area2D

var speed: float = 550.0
var damage: float = 35.0
var team: int = 1
var move_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(1.2).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += move_direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		queue_free()
	elif body.has_method("take_damage") and "direction" in body and body.direction != team:
		body.take_damage(damage)
		queue_free()
