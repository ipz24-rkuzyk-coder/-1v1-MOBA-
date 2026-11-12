extends StaticBody2D

signal throne_destroyed(losing_team: int)

const PROJECTILE_SCENE = preload("res://projectile.tscn")

@export var direction: int = 1 # 1 — сині (гравець), -1 — червоні (бот)
@export var is_throne: bool = false
@export var max_hp: float = 600.0
@export var attack_damage: float = 45.0

var hp: float
var hp_bar_width: float = 56.0

func _ready() -> void:
	collision_layer = 2 # Окремий шар для будівель, щоб крипи не застрягали в них
	
	if is_throne:
		$ColorRect.size = Vector2(80, 80)
		$ColorRect.position = Vector2(-40, -40)
		var rect := RectangleShape2D.new()
		rect.size = Vector2(80, 80)
		$CollisionShape2D.shape = rect
		$HpBar.size = Vector2(80, 6)
		$HpBar.position = Vector2(-40, -49)
	
	hp = max_hp
	hp_bar_width = $HpBar.size.x
	
	if direction == 1:
		$ColorRect.color = Color("#2b6cb0") if is_throne else Color("#4299e1")
	else:
		$ColorRect.color = Color("#c53030") if is_throne else Color("#f56565")
	
	if not is_throne:
		$AttackTimer.timeout.connect(_on_attack_timer_timeout)

func _physics_process(_delta: float) -> void:
	if is_throne:
		return
	var target := get_enemy_in_range()
	if target != null:
		if $AttackTimer.is_stopped():
			$AttackTimer.start()
	elif not $AttackTimer.is_stopped():
		$AttackTimer.stop()

func get_enemy_in_range() -> Node2D:
	for body in $AttackRange.get_overlapping_bodies():
		if body != self and body.has_method("take_damage") and "direction" in body and body.direction != direction:
			return body
	return null

func _on_attack_timer_timeout() -> void:
	var target := get_enemy_in_range()
	if target != null:
		var dir := (target.global_position - global_position).normalized()
		var shot := PROJECTILE_SCENE.instantiate()
		shot.team = direction
		shot.damage = attack_damage
		shot.global_position = global_position + dir * 34.0
		shot.move_direction = dir
		get_parent().add_child(shot)

func take_damage(amount: float) -> void:
	hp -= amount
	$HpBar.size.x = hp_bar_width * max(hp, 0.0) / max_hp
	if hp <= 0.0:
		if is_throne:
			throne_destroyed.emit(direction)
		queue_free()
