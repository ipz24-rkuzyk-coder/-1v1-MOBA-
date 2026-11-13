extends CharacterBody2D

const LANE_Y: float = 324.0
const LANE_MIN_Y: float = 245.0
const LANE_MAX_Y: float = 405.0

@export var direction: int = 1 # 1 — сині (вправо), -1 — червоні (вліво)
@export var speed: float = 115.0
@export var max_hp: float = 130.0
@export var attack_damage: float = 14.0
@export var attack_range: float = 64.0
@export var aggro_range: float = 190.0
@export var attack_cooldown: float = 0.90

var hp: float
var hp_bar_width: float = 24.0
var cooldown_timer: float = 0.0
var last_attacker: Node2D = null
var lane_offset_y: float = 0.0

func _ready() -> void:
	add_to_group("creeps")
	hp = max_hp
	if has_node("HpBar"):
		hp_bar_width = $HpBar.size.x
		
	# Зіткнення лише між юнітами, щоб кріпи не застрягали об прямокутні вежі
	collision_layer = 1
	collision_mask = 1
	lane_offset_y = randf_range(-14.0, 14.0)
	
	if has_node("ColorRect"):
		$ColorRect.color = Color("#4299e1") if direction == 1 else Color("#f56565")

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		
	var target: Node2D = _find_nearest_enemy()
	if target != null:
		var to_target: Vector2 = target.global_position - global_position
		var dist: float = to_target.length()
		if dist <= attack_range:
			velocity = Vector2.ZERO
			if cooldown_timer <= 0.0:
				_attack(target)
				cooldown_timer = attack_cooldown
		else:
			velocity = to_target.normalized() * speed
	else:
		var desired_y: float = _get_lane_target_y()
		var y_correction: float = clampf((desired_y - global_position.y) * 2.5, -75.0, 75.0)
		velocity = Vector2(float(direction) * speed, y_correction).limit_length(speed)
		
	move_and_slide()
	global_position.y = clampf(global_position.y, LANE_MIN_Y, LANE_MAX_Y)

func _get_lane_target_y() -> float:
	var target_y: float = LANE_Y + lane_offset_y
	for s in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(s) or float(s.get("hp")) <= 0.0:
			continue
		var dx: float = (s.global_position.x - global_position.x) * float(direction)
		if dx > -35.0 and dx < 110.0 and abs(s.global_position.y - global_position.y) < 52.0:
			var bypass_dir: float = -1.0 if lane_offset_y < 0.0 else 1.0
			return clampf(s.global_position.y + bypass_dir * 52.0, LANE_MIN_Y, LANE_MAX_Y)
	return target_y

func _find_nearest_enemy() -> Node2D:
	var best_target: Node2D = null
	var best_dist: float = aggro_range
	
	for node in get_parent().get_children():
		if node == self or not (node is Node2D) or not node.has_method("take_damage"):
			continue
		if node.get("direction") == null or int(node.get("direction")) == direction:
			continue
		if node.get("is_dead") == true:
			continue
		var hp_val = node.get("hp")
		if hp_val == null or float(hp_val) <= 0.0:
			continue
		if node.has_method("is_invulnerable") and node.is_invulnerable():
			continue
			
		var d: float = global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best_target = node
			
	return best_target

func _attack(target: Node2D) -> void:
	if "last_attacker" in target:
		target.last_attacker = self
	target.take_damage(attack_damage)
	
	var main_node: Node = get_tree().get_first_node_in_group("main")
	if is_instance_valid(main_node) and main_node.has_method("spawn_hit_effect"):
		var col: Color = Color("#63b3ed") if direction == 1 else Color("#fc8181")
		main_node.spawn_hit_effect(target.global_position, col, 14.0, 4)

func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	if has_node("HpBar"):
		$HpBar.size.x = hp_bar_width * max(hp, 0.0) / max_hp
		
	if hp <= 0.0:
		hp = 0.0
		if is_instance_valid(last_attacker) and last_attacker.is_in_group("heroes") and last_attacker.has_method("add_gold"):
			last_attacker.add_gold(28, global_position)
		queue_free()
