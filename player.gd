extends CharacterBody2D

const PROJECTILE_SCENE = preload("res://projectile.tscn")

@export var speed: float = 240.0
@export var max_hp: float = 300.0
@export var attack_cooldown: float = 0.45

var direction: int = 1 # 1 — синя команда гравця
var hp: float
var cooldown_timer: float = 0.0
var hp_bar_width: float = 32.0

func _ready() -> void:
	hp = max_hp
	hp_bar_width = $HpBar.size.x

func _physics_process(delta: float) -> void:
	# Рух на WASD або стрілки
	var input_dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
	
	velocity = input_dir.normalized() * speed
	move_and_slide()
	
	# Перезарядка та постріл на ліву кнопку миші
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and cooldown_timer <= 0.0:
		shoot()
		cooldown_timer = attack_cooldown

func shoot() -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.team = direction
	projectile.global_position = global_position
	projectile.move_direction = (get_global_mouse_position() - global_position).normalized()
	get_parent().add_child(projectile)

func take_damage(amount: float) -> void:
	hp -= amount
	$HpBar.size.x = hp_bar_width * max(hp, 0.0) / max_hp
	if hp <= 0.0:
		# Відродження біля синього Трону після смерті
		hp = max_hp
		$HpBar.size.x = hp_bar_width
		global_position = Vector2(320, 324)
