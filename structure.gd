extends StaticBody2D

@export var direction: int = 1 # 1 — синя команда, -1 — червона команда
@export var is_throne: bool = false
@export var max_hp: float = 1000.0
@export var attack_damage: float = 48.0
@export var attack_range: float = 265.0

var hp: float
var hp_bar_width: float = 48.0
var last_attacker: Node2D = null

var beam_target_pos: Vector2 = Vector2.ZERO
var beam_timer: float = 0.0
var shield_msg_cd: float = 0.0

func _ready() -> void:
	add_to_group("structures")
	hp = max_hp
	if has_node("HpBar"):
		hp_bar_width = $HpBar.size.x
		
	collision_layer = 2
	collision_mask = 0
	
	if has_node("AttackTimer"):
		$AttackTimer.wait_time = 0.85
		if not $AttackTimer.timeout.is_connected(_on_attack_timer_timeout):
			$AttackTimer.timeout.connect(_on_attack_timer_timeout)
		$AttackTimer.start()
		
	call_deferred("_sync_throne_role")

func _sync_throne_role() -> void:
	# Якщо в Інспекторі не виставлено is_throne, автоматично вважаємо Троном крайню будівлю команди
	var has_explicit_throne: bool = false
	var outermost: Node2D = self
	for s in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(s) and int(s.get("direction")) == direction:
			if bool(s.get("is_throne")):
				has_explicit_throne = true
			if direction == 1 and s.global_position.x < outermost.global_position.x:
				outermost = s
			elif direction == -1 and s.global_position.x > outermost.global_position.x:
				outermost = s
				
	if not has_explicit_throne and outermost == self:
		is_throne = true
		
	if is_throne and max_hp == 1000.0:
		max_hp = 2200.0
		hp = max_hp
		
	if has_node("ColorRect"):
		if direction == 1:
			$ColorRect.color = Color("#2b6cb0") if is_throne else Color("#3182ce")
		else:
			$ColorRect.color = Color("#9b2c2c") if is_throne else Color("#e53e3e")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if shield_msg_cd > 0.0:
		shield_msg_cd = max(0.0, shield_msg_cd - delta)
	if beam_timer > 0.0:
		beam_timer = max(0.0, beam_timer - delta)
		queue_redraw()
	elif is_throne:
		queue_redraw()

func _draw() -> void:
	var team_col: Color = Color(0.38, 0.75, 0.98) if direction == 1 else Color(0.98, 0.45, 0.45)
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(team_col.r, team_col.g, team_col.b, 0.16), 1.5)
	
	if is_throne and is_invulnerable():
		draw_arc(Vector2.ZERO, 42.0, 0.0, TAU, 36, Color("#ffd700"), 2.5)
		
	if beam_timer > 0.0 and beam_target_pos != Vector2.ZERO:
		var alpha: float = clamp(beam_timer / 0.22, 0.0, 1.0)
		var local_target: Vector2 = to_local(beam_target_pos)
		draw_line(Vector2.ZERO, local_target, Color(team_col.r, team_col.g, team_col.b, alpha * 0.9), 4.5)
		draw_line(Vector2.ZERO, local_target, Color(1.0, 1.0, 1.0, alpha * 0.85), 1.5)

func is_invulnerable() -> bool:
	if not is_throne:
		return false
	for s in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(s) and s != self:
			if int(s.get("direction")) == direction and not bool(s.get("is_throne")) and float(s.get("hp")) > 0.0:
				return true
	return false

func _on_attack_timer_timeout() -> void:
	if hp <= 0.0:
		return
	var target: Node2D = _find_target()
	if target != null:
		beam_target_pos = target.global_position
		beam_timer = 0.22
		if "last_attacker" in target:
			target.last_attacker = self
		target.take_damage(attack_damage)
		var main_node: Node = get_tree().get_first_node_in_group("main")
		if is_instance_valid(main_node) and main_node.has_method("spawn_hit_effect"):
			var col: Color = Color("#63b3ed") if direction == 1 else Color("#fc8181")
			main_node.spawn_hit_effect(target.global_position, col, 22.0, 6)
		queue_redraw()

func _find_target() -> Node2D:
	var best_creep: Node2D = null
	var best_creep_dist: float = INF
	var best_hero: Node2D = null
	var best_hero_dist: float = INF
	
	for node in get_parent().get_children():
		if node == self or not (node is Node2D) or not node.has_method("take_damage"):
			continue
		if node.get("direction") == null or int(node.get("direction")) == direction:
			continue
		if node.is_in_group("structures") or node is StaticBody2D:
			continue
		if node.get("is_dead") == true:
			continue
		var hp_val = node.get("hp")
		if hp_val == null or float(hp_val) <= 0.0:
			continue
			
		var d: float = global_position.distance_to(node.global_position)
		if d > attack_range:
			continue
			
		if node.is_in_group("heroes"):
			if d < best_hero_dist:
				best_hero_dist = d
				best_hero = node
		else:
			if d < best_creep_dist:
				best_creep_dist = d
				best_creep = node
				
	return best_creep if best_creep != null else best_hero

func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	if is_invulnerable():
		if shield_msg_cd <= 0.0:
			shield_msg_cd = 1.2
			_spawn_shield_text()
		return
		
	hp -= amount
	if has_node("HpBar"):
		$HpBar.size.x = hp_bar_width * max(hp, 0.0) / max_hp
		
	if hp <= 0.0:
		hp = 0.0
		var main_node: Node = get_tree().get_first_node_in_group("main")
		if is_instance_valid(main_node) and main_node.has_method("spawn_hit_effect"):
			var col: Color = Color("#63b3ed") if direction == 1 else Color("#fc8181")
			main_node.spawn_hit_effect(global_position, col, 95.0, 24)
			
		if is_throne:
			if is_instance_valid(main_node) and main_node.has_method("end_match"):
				main_node.end_match(-direction)
		else:
			for h in get_tree().get_nodes_in_group("heroes"):
				if is_instance_valid(h) and int(h.get("direction")) == -direction and h.has_method("add_gold"):
					h.add_gold(200, global_position)
			queue_free()

func _spawn_shield_text() -> void:
	var lbl := Label.new()
	lbl.text = "Щит! Знищте вежу"
	lbl.global_position = global_position + Vector2(-48, -46)
	lbl.add_theme_color_override("font_color", Color("#ffd700"))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_font_size_override("font_size", 13)
	get_parent().add_child(lbl)
	var tween := lbl.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 28.0, 0.75)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.75)
	await tween.finished
	if is_instance_valid(lbl):
		lbl.queue_free()
