extends CharacterBody2D

@export var speed: float = 130.0
@export var max_hp: float = 100.0
@export var attack_damage: float = 20.0

var direction: int = 1 # 1 — сині (вправо), -1 — червоні (вліво)
var hp: float

func _ready() -> void:
	hp = max_hp
	$AttackRange.collision_mask = 3 # Бачить і юнітів (шар 1), і вежі/Трони (шар 2)
	add_to_group("creeps")
	$AttackTimer.timeout.connect(_on_attack_timer_timeout)
	
	if direction == 1:
		$ColorRect.color = Color("#3182ce")
	else:
		$ColorRect.color = Color("#e53e3e")

func _physics_process(_delta: float) -> void:
	var target := get_enemy_in_range()
	
	if target != null:
		# Зупиняємось і б'ємо ворога або вежу
		velocity = Vector2.ZERO
		if $AttackTimer.is_stopped():
			$AttackTimer.start()
	else:
		# Якщо ворогів поруч немає — йдемо далі по лінії
		if not $AttackTimer.is_stopped():
			$AttackTimer.stop()
		velocity = Vector2(direction * speed, 0)
		move_and_slide()

func get_enemy_in_range() -> Node2D:
	for body in $AttackRange.get_overlapping_bodies():
		if body != self and body.has_method("take_damage") and "direction" in body and body.direction != direction:
			return body
	return null

func _on_attack_timer_timeout() -> void:
	var target := get_enemy_in_range()
	if target != null:
		target.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	hp -= amount
	$HpBar.size.x = 22.0 * max(hp, 0.0) / max_hp
	if hp <= 0.0:
		queue_free()
