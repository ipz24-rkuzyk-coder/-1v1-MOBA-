extends Area2D

@export var speed: float = 550.0
@export var max_range: float = 230.0

var team: int = 1
var damage: float = 25.0
var move_direction: Vector2 = Vector2.RIGHT
var owner_unit: Node2D = null
var target: Node2D = null
var is_skill: bool = false
var is_crit: bool = false
var lifesteal: float = 0.0
var start_position: Vector2

func _ready() -> void:
	start_position = global_position
	collision_mask = 7
	body_entered.connect(_on_body_entered)
	
	if has_node("ColorRect"):
		$ColorRect.color = Color("#63b3ed") if team == 1 else Color("#fc8181")
	
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if target != null:
		if is_instance_valid(target) and target.get("is_dead") != true:
			var to_target: Vector2 = target.global_position - global_position
			if to_target.length() <= 14.0:
				_hit_target(target)
				return
			move_direction = to_target.normalized()
			position += move_direction * speed * delta
			return
		else:
			target = null
	
	position += move_direction * speed * delta
	if global_position.distance_to(start_position) >= max_range:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body == owner_unit:
		return
	if body.get("is_dead") == true:
		return
	
	if is_skill and (body.is_in_group("structures") or (body is StaticBody2D and body.get("direction") != null)):
		return
	
	if target != null and is_instance_valid(target):
		if body == target:
			_hit_target(body)
		return
		
	if body.has_method("take_damage") and body.get("direction") != null and int(body.get("direction")) != team:
		_hit_target(body)
	elif body is StaticBody2D and body.get("direction") == null:
		queue_free()

func _hit_target(body: Node2D) -> void:
	if "last_attacker" in body:
		body.last_attacker = owner_unit
	body.take_damage(damage)
	
	var main_node: Node = get_tree().get_first_node_in_group("main")
	if is_instance_valid(main_node) and main_node.has_method("spawn_hit_effect"):
		if is_skill:
			var s_col: Color = Color("#00f5d4") if team == 1 else Color("#ff6b6b")
			main_node.spawn_hit_effect(global_position, s_col, 42.0, 12)
		elif is_crit:
			main_node.spawn_hit_effect(global_position, Color("#ffd700"), 32.0, 10)
		else:
			var h_col: Color = Color("#63b3ed") if team == 1 else Color("#fc8181")
			main_node.spawn_hit_effect(global_position, h_col, 18.0, 5)
	
	if lifesteal > 0.0 and not body.is_in_group("structures") and not (body is StaticBody2D):
		if is_instance_valid(owner_unit) and owner_unit.has_method("heal"):
			owner_unit.heal(damage * lifesteal)
			
	queue_free()
