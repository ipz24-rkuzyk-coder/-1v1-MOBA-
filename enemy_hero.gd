extends CharacterBody2D

const PROJECTILE_SCENE = preload("res://projectile.tscn")
const RESPAWN_TIME: float = 12.0
const LANE_MIN_Y: float = 248.0
const LANE_MAX_Y: float = 400.0
const TOWER_DANGER_RADIUS: float = 235.0
const TOWER_STANDOFF_DIST: float = 245.0

const Q_MANA: float = 35.0
const Q_COOLDOWN: float = 4.5
const E_MANA: float = 40.0
const E_COOLDOWN: float = 6.0
const E_DASH_DIST: float = 195.0
const R_MANA: float = 80.0
const R_COOLDOWN: float = 14.0
const R_CAST_RANGE: float = 400.0
const R_RADIUS: float = 115.0

@export_enum("easy", "norm", "hard") var difficulty: String = "norm"
@export var speed: float = 235.0
@export var max_hp: float = 360.0
@export var hp_regen: float = 4.0
@export var max_mana: float = 200.0
@export var mana_regen: float = 6.0
@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 0.48
@export var attack_range: float = 230.0

var direction: int = -1
var hp: float
var mana: float
var gold: int = 120
var passive_gold_timer: float = 0.0
var cooldown_timer: float = 0.0
var hp_bar_width: float = 32.0

var lifesteal: float = 0.0
var crit_chance: float = 0.0
var spell_amp: float = 0.0
var cdr: float = 0.0

var is_dead: bool = false
var respawn_timer: float = 0.0
var is_healing: bool = false
var going_to_shop: bool = false
var strafe_dir: float = 1.0
var strafe_timer: float = 0.0
var avoid_dir: float = 1.0
var stuck_check_timer: float = 0.0
var last_check_pos: Vector2 = Vector2.ZERO

var q_cd: float = 0.0
var e_cd: float = 0.0
var r_cd: float = 0.0

var red_throne_pos: Vector2 = Vector2(1045.0, 324.0)
var blue_throne_pos: Vector2 = Vector2(135.0, 324.0)
var last_attacker: Node2D = null
var active_effects: Array[Dictionary] = []
var tag_label: Label

var build_step: int = 0
var build_order: Array[Dictionary] = [
	{"name": "Чоботи вітру", "cost": 240, "dmg": 0.0, "as_mult": 1.0, "spd": 45.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
	{"name": "Меч бійця", "cost": 280, "dmg": 15.0, "as_mult": 1.0, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
	{"name": "Лук швидкості", "cost": 300, "dmg": 0.0, "as_mult": 0.80, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
	{"name": "Броня титана", "cost": 340, "dmg": 0.0, "as_mult": 1.0, "spd": 0.0, "hp": 150.0, "hp_reg": 3.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
	{"name": "Вампірський кинджал", "cost": 380, "dmg": 15.0, "as_mult": 1.0, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.12, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
	{"name": "Кристал мани", "cost": 250, "dmg": 0.0, "as_mult": 1.0, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 120.0, "mp_reg": 5.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
	# Tier 2 покращення
	{"name": "Клинок руйнівника (T2)", "cost": 820, "dmg": 35.0, "as_mult": 1.0, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.22, "amp": 0.0, "cdr": 0.0},
	{"name": "Чоботи телепорту (T2)", "cost": 660, "dmg": 0.0, "as_mult": 0.88, "spd": 40.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.15},
	{"name": "Егіда безсмертя (T2)", "cost": 860, "dmg": 0.0, "as_mult": 1.0, "spd": 0.0, "hp": 270.0, "hp_reg": 7.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
	{"name": "Серце дракона (T2)", "cost": 970, "dmg": 30.0, "as_mult": 1.0, "spd": 0.0, "hp": 180.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.10, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
	{"name": "Арбалет бурі (T2)", "cost": 800, "dmg": 20.0, "as_mult": 0.76, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
	{"name": "Сфера архімага (T2)", "cost": 750, "dmg": 0.0, "as_mult": 1.0, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 160.0, "mp_reg": 7.0, "ls": 0.0, "crit": 0.0, "amp": 0.25, "cdr": 0.0}
]

func _ready() -> void:
	add_to_group("heroes")
	if has_node("HpBar"):
		hp_bar_width = $HpBar.size.x
	collision_layer = 1
	collision_mask = 2
	
	_resolve_throne_positions()
	global_position = red_throne_pos + Vector2(-55.0, 0.0)
	last_check_pos = global_position
	
	if has_node("ColorRect"):
		$ColorRect.color = Color("#e53e3e")
		
	tag_label = Label.new()
	tag_label.position = Vector2(-42, -44)
	tag_label.add_theme_color_override("font_color", Color("#feb2b2"))
	tag_label.add_theme_color_override("font_outline_color", Color.BLACK)
	tag_label.add_theme_constant_override("outline_size", 3)
	tag_label.add_theme_font_size_override("font_size", 11)
	add_child(tag_label)
	
	var saved_diff: String = str(Engine.get_meta("bot_difficulty", difficulty))
	set_difficulty(saved_diff)
	queue_redraw()

func _resolve_throne_positions() -> void:
	var best_blue_x: float = INF
	var best_red_x: float = -INF
	for s in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(s):
			continue
		var s_dir: int = int(s.get("direction"))
		if s_dir == 1 and s.global_position.x < best_blue_x:
			best_blue_x = s.global_position.x
			blue_throne_pos = Vector2(s.global_position.x, 324.0)
		elif s_dir == -1 and s.global_position.x > best_red_x:
			best_red_x = s.global_position.x
			red_throne_pos = Vector2(s.global_position.x, 324.0)
			
	if best_blue_x == INF:
		blue_throne_pos = Vector2(135.0, 324.0)
	if best_red_x == -INF:
		red_throne_pos = Vector2(1045.0, 324.0)

func sync_throne_positions(blue_pos: Vector2, red_pos: Vector2) -> void:
	blue_throne_pos = Vector2(blue_pos.x, 324.0)
	red_throne_pos = Vector2(red_pos.x, 324.0)
	if not is_dead:
		global_position = red_throne_pos + Vector2(-55.0, 0.0)
		last_check_pos = global_position

func _get_arena_min_x() -> float:
	return minf(48.0, blue_throne_pos.x - 60.0)

func _get_arena_max_x() -> float:
	return maxf(1104.0, red_throne_pos.x + 60.0)

func set_difficulty(diff: String) -> void:
	difficulty = diff
	if difficulty == "easy":
		speed = 215.0
		max_hp = 335.0
		attack_damage = 22.0
		attack_cooldown = 0.55
	elif difficulty == "hard":
		speed = 242.0
		max_hp = 365.0
		attack_damage = 26.0
		attack_cooldown = 0.45
	else:
		speed = 232.0
		max_hp = 350.0
		attack_damage = 24.0
		attack_cooldown = 0.49
		
	hp = max_hp
	mana = max_mana
	if has_node("HpBar"):
		$HpBar.size.x = hp_bar_width
	_update_tag_label()

func _update_tag_label() -> void:
	if not is_instance_valid(tag_label):
		return
	var diff_tag: String = "Норм"
	if difficulty == "easy":
		diff_tag = "Легко"
	elif difficulty == "hard":
		diff_tag = "Хард"
	tag_label.text = "БОТ (%s) [%d/12]" % [diff_tag, build_step]

func _draw() -> void:
	if is_dead:
		return
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 48, Color(0.98, 0.45, 0.45, 0.14), 1.5)
	draw_rect(Rect2(-18, -18, 36, 36), Color("#fbd38d"), false, 2.0)
	
	for ef in active_effects:
		var alpha: float = clampf(float(ef["time"]) / float(ef["max_time"]), 0.0, 1.0)
		if ef["type"] == "dash":
			draw_line(to_local(ef["from"]), to_local(ef["to"]), Color(0.98, 0.45, 0.45, alpha * 0.75), 18.0)
		elif ef["type"] == "blast":
			var progress: float = 1.0 - alpha * 0.35
			var center: Vector2 = to_local(ef["pos"])
			draw_circle(center, float(ef["radius"]) * progress, Color(0.90, 0.24, 0.24, alpha * 0.35))
			draw_arc(center, float(ef["radius"]), 0.0, TAU, 48, Color(0.99, 0.65, 0.65, alpha), 3.0)

func _physics_process(delta: float) -> void:
	if active_effects.size() > 0:
		for i in range(active_effects.size() - 1, -1, -1):
			active_effects[i]["time"] -= delta
			if float(active_effects[i]["time"]) <= 0.0:
				active_effects.remove_at(i)
		queue_redraw()
		
	if is_dead:
		respawn_timer -= delta
		var player: Node2D = _get_player_hero()
		if is_instance_valid(player) and player.has_method("set_bot_respawn"):
			player.set_bot_respawn(maxf(0.0, respawn_timer))
		if respawn_timer <= 0.0:
			_respawn()
		return
		
	if q_cd > 0.0:
		q_cd = maxf(0.0, q_cd - delta)
	if e_cd > 0.0:
		e_cd = maxf(0.0, e_cd - delta)
	if r_cd > 0.0:
		r_cd = maxf(0.0, r_cd - delta)
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = randf_range(1.15, 1.95)
		strafe_dir = -strafe_dir
		
	passive_gold_timer += delta
	if passive_gold_timer >= 1.0:
		passive_gold_timer -= 1.0
		gold += 1
		
	var on_fountain: bool = global_position.distance_to(red_throne_pos) <= 200.0
	if on_fountain:
		_try_buy_item()
		going_to_shop = false
		
	var current_hp_regen: float = hp_regen + (45.0 if on_fountain else 0.0)
	var current_mana_regen: float = mana_regen + (35.0 if on_fountain else 0.0)
	
	if hp < max_hp:
		hp = minf(hp + current_hp_regen * delta, max_hp)
		if has_node("HpBar"):
			$HpBar.size.x = hp_bar_width * hp / max_hp
	if mana < max_mana:
		mana = minf(mana + current_mana_regen * delta, max_mana)
		
	_run_ai(delta, on_fountain)

func _apply_smart_steering(delta: float, desired_vel: Vector2) -> void:
	var steer: Vector2 = desired_vel
	
	for node in get_parent().get_children():
		if node != self and node is Node2D and node.is_in_group("creeps"):
			if float(node.get("hp")) <= 0.0:
				continue
			var diff: Vector2 = global_position - node.global_position
			var dist: float = diff.length()
			if dist < 38.0 and dist > 0.01:
				var push_strength: float = (38.0 - dist) / 38.0
				steer += diff.normalized() * speed * 0.45 * push_strength
				
	for s in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(s) or float(s.get("hp")) <= 0.0:
			continue
		var diff_s: Vector2 = global_position - s.global_position
		var dist_s: float = diff_s.length()
		if dist_s < 80.0 and dist_s > 0.01:
			var side_y: float = -1.0 if global_position.y <= s.global_position.y else 1.0
			if global_position.y < LANE_MIN_Y + 26.0:
				side_y = 1.0
			elif global_position.y > LANE_MAX_Y - 26.0:
				side_y = -1.0
			steer += diff_s.normalized() * speed * 0.75
			steer.y += side_y * speed * 0.75
			
	if global_position.y < LANE_MIN_Y + 12.0 and steer.y < 0.0:
		steer.y = absf(steer.y) * 0.4 + 25.0
	elif global_position.y > LANE_MAX_Y - 12.0 and steer.y > 0.0:
		steer.y = -absf(steer.y) * 0.4 - 25.0
		
	var target_vel: Vector2 = Vector2.ZERO
	if desired_vel.length() > 5.0:
		target_vel = steer.limit_length(speed)
	elif steer.length() > 12.0:
		target_vel = steer.limit_length(speed * 0.35)
		
	velocity = velocity.lerp(target_vel, clampf(delta * 14.0, 0.0, 1.0))
	move_and_slide()
	
	stuck_check_timer += delta
	if stuck_check_timer >= 0.25:
		if desired_vel.length() > 45.0 and global_position.distance_to(last_check_pos) < 8.0:
			if global_position.y < 290.0:
				avoid_dir = 1.0
			elif global_position.y > 360.0:
				avoid_dir = -1.0
			else:
				avoid_dir = -avoid_dir
			velocity = Vector2(desired_vel.x * 0.25, avoid_dir * speed * 0.85)
			move_and_slide()
		last_check_pos = global_position
		stuck_check_timer = 0.0
		
	global_position.x = clampf(global_position.x, _get_arena_min_x(), _get_arena_max_x())
	global_position.y = clampf(global_position.y, LANE_MIN_Y, LANE_MAX_Y)

func _run_ai(delta: float, on_fountain: bool) -> void:
	var player: Node2D = _get_player_hero()
	var player_alive: bool = is_instance_valid(player) and player.get("is_dead") != true
	var dist_to_player: float = global_position.distance_to(player.global_position) if player_alive else INF
	var fountain_spot: Vector2 = red_throne_pos + Vector2(-55.0, 0.0)
	var dist_to_fountain: float = global_position.distance_to(fountain_spot)
	
	if e_cd <= 0.0 and mana >= E_MANA and not on_fountain:
		var dodge_dir: Vector2 = _check_incoming_skillshot_dodge()
		if dodge_dir != Vector2.ZERO:
			var chance: float = 1.0 if difficulty == "hard" else (0.55 if difficulty == "norm" else (0.25 if hp < max_hp * 0.5 else 0.0))
			if randf() < chance:
				_cast_e(dodge_dir)
				spawn_floating_text(global_position, "Ухилення!", Color("#fbd38d"))
	
	var retreat_threshold: float = 0.26 if difficulty == "hard" else (0.34 if difficulty == "norm" else 0.44)
	
	if not player_alive:
		if difficulty == "easy":
			if hp < max_hp * 0.45:
				is_healing = true
			elif is_healing and hp >= max_hp * 0.88:
				is_healing = false
		else:
			is_healing = false
			going_to_shop = false
			var respawn_buffer: float = 2.6 if difficulty == "hard" else 4.2
			var rt_val = player.get("respawn_timer") if is_instance_valid(player) else null
			var player_respawning_soon: bool = rt_val != null and float(rt_val) <= respawn_buffer
			var has_gold_to_spend: bool = build_step < build_order.size() and gold >= int(build_order[build_step]["cost"])
			
			if hp < max_hp * 0.14 or (player_respawning_soon and (hp < max_hp * 0.48 or has_gold_to_spend)):
				is_healing = true
	else:
		var p_hp: float = float(player.get("hp"))
		var can_finish_player: bool = (difficulty != "easy") and dist_to_player <= 385.0 and (
			p_hp <= _estimate_burst_damage() or
			(difficulty == "hard" and p_hp < hp * 0.78 and (q_cd <= 0.4 or r_cd <= 0.4))
		)
		
		if can_finish_player:
			is_healing = false
			going_to_shop = false
		else:
			if hp < max_hp * retreat_threshold:
				is_healing = true
			elif is_healing and hp >= max_hp * 0.88:
				is_healing = false
				
		if not is_healing and not going_to_shop and build_step < build_order.size():
			var next_cost: int = int(build_order[build_step]["cost"])
			var mid_x: float = (blue_throne_pos.x + red_throne_pos.x) * 0.45
			if gold >= next_cost and dist_to_player > 410.0 and global_position.x > mid_x and not _is_base_under_threat():
				going_to_shop = true
				
	if on_fountain and not _is_base_under_threat() and build_step < build_order.size():
		var deficit: int = int(build_order[build_step]["cost"]) - gold
		if deficit > 0 and deficit <= 22:
			_apply_smart_steering(delta, Vector2.ZERO)
			return
			
	if is_healing or going_to_shop:
		if is_healing and player_alive and dist_to_player < 245.0 and dist_to_fountain > 170.0 and e_cd <= 0.0 and mana >= E_MANA:
			_cast_e((fountain_spot - global_position).normalized())
		var retreat_dir: Vector2 = (fountain_spot - global_position).normalized()
		var move_v: Vector2 = retreat_dir * speed if dist_to_fountain > 18.0 else Vector2.ZERO
		_apply_smart_steering(delta, move_v)
		if on_fountain and not is_healing:
			going_to_shop = false
		return
		
	var danger_struct: Node2D = _get_dangerous_enemy_structure(global_position, TOWER_DANGER_RADIUS)
	if danger_struct != null:
		var step_out_dir: Vector2 = (global_position - danger_struct.global_position).normalized()
		if step_out_dir == Vector2.ZERO:
			step_out_dir = Vector2.RIGHT
		_apply_smart_steering(delta, step_out_dir * speed)
		return
		
	if player_alive:
		var p_hp: float = float(player.get("hp"))
		var p_max_hp: float = float(player.get("max_hp"))
		var aim_q_pos: Vector2 = _predict_player_pos(player, 750.0) if difficulty == "hard" else player.global_position
		var aim_r_pos: Vector2 = _predict_player_pos(player, 1800.0) if difficulty == "hard" else player.global_position
		
		if r_cd <= 0.0 and mana >= R_MANA and global_position.distance_to(aim_r_pos) <= R_CAST_RANGE:
			var nearby_creeps: int = _count_blue_creeps_near(aim_r_pos, R_RADIUS)
			if p_hp < p_max_hp * 0.72 or p_hp <= _estimate_r_damage() * 1.25 or nearby_creeps >= 2:
				_cast_r(aim_r_pos)
				
		if q_cd <= 0.0 and mana >= Q_MANA and global_position.distance_to(aim_q_pos) <= 415.0:
			if _is_line_clear_for_q(aim_q_pos) or p_hp <= _estimate_q_damage():
				_cast_q((aim_q_pos - global_position).normalized())
				
		if e_cd <= 0.0 and mana >= E_MANA and dist_to_player > 235.0 and dist_to_player <= 415.0:
			var can_aggro_blink: bool = (difficulty != "easy") and (p_hp <= _estimate_burst_damage() * 1.15 or p_hp < p_max_hp * 0.35)
			if can_aggro_blink:
				var blink_dir: Vector2 = (player.global_position - global_position).normalized()
				var landing: Vector2 = global_position + blink_dir * E_DASH_DIST
				if _get_dangerous_enemy_structure(landing, TOWER_DANGER_RADIUS + 5.0) == null:
					_cast_e(blink_dir)
	else:
		var wave_center: Vector2 = _find_dense_blue_creep_cluster(3)
		if wave_center != Vector2.ZERO:
			if q_cd <= 0.0 and mana >= Q_MANA + 45.0 and global_position.distance_to(wave_center) <= 410.0:
				_cast_q((wave_center - global_position).normalized())
			elif difficulty != "easy" and r_cd <= 0.0 and mana >= R_MANA + 50.0 and global_position.distance_to(wave_center) <= R_CAST_RANGE:
				if _count_blue_creeps_near(wave_center, R_RADIUS) >= 4:
					_cast_r(wave_center)
					
	var attack_target: Node2D = _choose_best_attack_target(player, player_alive)
	if attack_target != null and cooldown_timer <= 0.0:
		_shoot(attack_target)
		cooldown_timer = attack_cooldown
		
	var move_goal: Vector2 = _choose_move_goal(player, player_alive, attack_target)
	var to_goal: Vector2 = move_goal - global_position
	var desired_vel: Vector2 = Vector2.ZERO
	var in_combat: bool = (attack_target != null) or (player_alive and dist_to_player <= 390.0)
	
	if to_goal.length() > 14.0:
		desired_vel = to_goal.normalized() * speed
		if in_combat:
			var lane_shift: float = strafe_dir * 55.0
			if player_alive and q_cd <= 0.4 and mana >= Q_MANA and not _is_line_clear_for_q(player.global_position):
				lane_shift = avoid_dir * 115.0
			desired_vel.y += lane_shift
		desired_vel = desired_vel.limit_length(speed)
	elif in_combat:
		desired_vel = Vector2(0.0, strafe_dir * 45.0)
	else:
		desired_vel = Vector2.ZERO
		
	var next_pos: Vector2 = global_position + desired_vel * delta
	if _get_dangerous_enemy_structure(next_pos, TOWER_DANGER_RADIUS + 2.0) != null:
		desired_vel.x = maxf(0.0, desired_vel.x)
		
	_apply_smart_steering(delta, desired_vel)

func _is_line_clear_for_q(target_pos: Vector2) -> bool:
	var to_target: Vector2 = target_pos - global_position
	var dist: float = to_target.length()
	if dist <= 1.0:
		return true
	var dir_norm: Vector2 = to_target / dist
	for node in get_parent().get_children():
		if node is Node2D and node.is_in_group("creeps") and int(node.get("direction")) == 1:
			if float(node.get("hp")) <= 0.0:
				continue
			var to_creep: Vector2 = node.global_position - global_position
			var proj: float = to_creep.dot(dir_norm)
			if proj > 0.0 and proj < dist - 20.0:
				var perp_dist: float = absf(to_creep.cross(dir_norm))
				if perp_dist < 26.0:
					return false
	return true

func _estimate_q_damage() -> float:
	return (attack_damage * 2.2 + 30.0) * (1.0 + spell_amp)

func _estimate_r_damage() -> float:
	return (attack_damage * 2.5 + 90.0) * (1.0 + spell_amp)

func _estimate_burst_damage() -> float:
	var dmg: float = attack_damage * 2.0
	if q_cd <= 0.5 and mana >= Q_MANA:
		dmg += _estimate_q_damage()
	if r_cd <= 0.5 and mana >= R_MANA:
		dmg += _estimate_r_damage()
	return dmg

func _predict_player_pos(player: Node2D, proj_speed: float) -> Vector2:
	var dist: float = global_position.distance_to(player.global_position)
	var travel_time: float = dist / proj_speed
	var p_vel: Vector2 = player.get("velocity") if player.get("velocity") is Vector2 else Vector2.ZERO
	var predicted: Vector2 = player.global_position + p_vel * travel_time * 0.78
	predicted.x = clampf(predicted.x, _get_arena_min_x() + 7.0, _get_arena_max_x() - 7.0)
	predicted.y = clampf(predicted.y, LANE_MIN_Y, LANE_MAX_Y)
	return predicted

func _check_incoming_skillshot_dodge() -> Vector2:
	for node in get_parent().get_children():
		if node is Area2D and node.get("team") == 1 and node.get("is_skill") == true:
			var to_bot: Vector2 = global_position - node.global_position
			var d: float = to_bot.length()
			if d > 15.0 and d < 180.0:
				var m_dir: Vector2 = node.get("move_direction") if node.get("move_direction") is Vector2 else Vector2.RIGHT
				var aim_alignment: float = m_dir.dot(to_bot.normalized())
				if aim_alignment > 0.76:
					var perp: Vector2 = m_dir.orthogonal()
					if absf((global_position + perp * 120.0).y - 324.0) > absf((global_position - perp * 120.0).y - 324.0):
						perp = -perp
					return perp.normalized()
	return Vector2.ZERO

func _find_dense_blue_creep_cluster(min_count: int = 3) -> Vector2:
	for node in get_parent().get_children():
		if node is Node2D and node.is_in_group("creeps") and int(node.get("direction")) == 1:
			if _count_blue_creeps_near(node.global_position, R_RADIUS) >= min_count:
				return node.global_position
	return Vector2.ZERO

func _is_base_under_threat() -> bool:
	for node in get_parent().get_children():
		if node is Node2D and node.get("direction") == 1:
			if node.get("is_dead") == true:
				continue
			if node.global_position.distance_to(red_throne_pos) < 420.0:
				return true
	return false

func _choose_best_attack_target(player: Node2D, player_alive: bool) -> Node2D:
	var best_last_hit: Node2D = null
	var best_creep: Node2D = null
	var best_creep_dist: float = INF
	var best_struct: Node2D = null
	
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
		var n_hp: float = float(hp_val)
			
		var d: float = global_position.distance_to(node.global_position)
		if d > attack_range + 15.0:
			continue
			
		if node.is_in_group("structures") or node is StaticBody2D:
			if node.has_method("is_invulnerable") and node.is_invulnerable():
				continue
			best_struct = node
		elif not node.is_in_group("heroes"):
			if n_hp <= attack_damage * 1.15:
				best_last_hit = node
			if d < best_creep_dist:
				best_creep_dist = d
				best_creep = node
				
	if player_alive and global_position.distance_to(player.global_position) <= attack_range + 15.0 and float(player.get("hp")) <= attack_damage * 1.45:
		return player
		
	if best_last_hit != null:
		return best_last_hit
		
	if player_alive and global_position.distance_to(player.global_position) <= attack_range + 15.0:
		return player
		
	if not player_alive and best_struct != null:
		return best_struct
		
	if best_creep != null:
		return best_creep
	return best_struct

func _avoid_friendly_structures(goal: Vector2) -> Vector2:
	var res: Vector2 = goal
	for s in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(s) or int(s.get("direction")) != direction or float(s.get("hp")) <= 0.0:
			continue
		if res.distance_to(s.global_position) < 92.0:
			res.x = s.global_position.x - 98.0
			res.y = 324.0
	return res

func _choose_move_goal(player: Node2D, player_alive: bool, current_target: Node2D) -> Vector2:
	var closest_blue_creep: Node2D = null
	var closest_creep_dist: float = INF
	for node in get_parent().get_children():
		if node is Node2D and node.is_in_group("creeps") and int(node.get("direction")) == 1 and float(node.get("hp")) > 0.0:
			var d_c: float = global_position.distance_to(node.global_position)
			if d_c < closest_creep_dist:
				closest_creep_dist = d_c
				closest_blue_creep = node
				
	if is_instance_valid(closest_blue_creep) and closest_creep_dist < 135.0:
		var kite_away: Vector2 = (global_position - closest_blue_creep.global_position).normalized()
		if kite_away == Vector2.ZERO:
			kite_away = Vector2.RIGHT
		return _avoid_friendly_structures(closest_blue_creep.global_position + kite_away * 195.0)
		
	if is_instance_valid(current_target):
		if current_target.is_in_group("structures") or current_target is StaticBody2D:
			return _avoid_friendly_structures(current_target.global_position + Vector2(185.0, 0.0))
			
		var away: Vector2 = (global_position - current_target.global_position).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		var desired_dist: float = 212.0 if cooldown_timer > 0.1 else 185.0
		return _avoid_friendly_structures(current_target.global_position + away * desired_dist)
		
	if player_alive and _get_dangerous_enemy_structure(player.global_position, TOWER_DANGER_RADIUS) == null:
		var toward: Vector2 = (player.global_position - global_position).normalized()
		if toward == Vector2.ZERO:
			toward = Vector2.LEFT
		return _avoid_friendly_structures(player.global_position - toward * 200.0)
		
	var front_tower: Node2D = _get_frontmost_dangerous_tower()
	var safe_min_x: float = (front_tower.global_position.x + TOWER_STANDOFF_DIST) if front_tower != null else (blue_throne_pos.x + 185.0)
	
	var furthest_friendly_x: float = INF
	for node in get_parent().get_children():
		if node != self and node is Node2D and node.is_in_group("creeps") and int(node.get("direction")) == direction:
			if float(node.get("hp")) > 0.0:
				furthest_friendly_x = minf(furthest_friendly_x, node.global_position.x)
				
	if furthest_friendly_x < INF:
		var escort_x: float = maxf(safe_min_x, furthest_friendly_x + 55.0)
		return _avoid_friendly_structures(Vector2(escort_x, 324.0))
		
	return _avoid_friendly_structures(Vector2(safe_min_x, 324.0))

func _get_frontmost_dangerous_tower() -> Node2D:
	var best_tower: Node2D = null
	var best_x: float = -INF
	for s in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(s) or int(s.get("direction")) == direction or float(s.get("hp")) <= 0.0:
			continue
		if _get_dangerous_enemy_structure(s.global_position, TOWER_DANGER_RADIUS + 5.0) != null:
			if s.global_position.x > best_x:
				best_x = s.global_position.x
				best_tower = s
	return best_tower

func _get_dangerous_enemy_structure(check_pos: Vector2, radius: float = TOWER_DANGER_RADIUS) -> Node2D:
	for s in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(s) or int(s.get("direction")) == direction or float(s.get("hp")) <= 0.0:
			continue
		if check_pos.distance_to(s.global_position) < radius:
			var friendly_tanks: int = 0
			var total_tank_hp: float = 0.0
			for node in get_parent().get_children():
				if node != self and node is Node2D and node.is_in_group("creeps") and int(node.get("direction")) == direction:
					var hp_val = node.get("hp")
					if hp_val != null and float(hp_val) > 0.0 and node.global_position.distance_to(s.global_position) <= TOWER_DANGER_RADIUS + 5.0:
						friendly_tanks += 1
						total_tank_hp += float(hp_val)
			if friendly_tanks == 0 or (friendly_tanks == 1 and total_tank_hp <= 45.0):
				return s
	return null

func _count_blue_creeps_near(pos: Vector2, radius: float) -> int:
	var count: int = 0
	for node in get_parent().get_children():
		if node is Node2D and node.is_in_group("creeps") and int(node.get("direction")) == 1:
			if node.global_position.distance_to(pos) <= radius:
				count += 1
	return count

func _get_player_hero() -> Node2D:
	for h in get_tree().get_nodes_in_group("heroes"):
		if is_instance_valid(h) and h != self and h.get("direction") == 1:
			return h
	return null

func _shoot(target_node: Node2D) -> void:
	var is_crit: bool = randf() < crit_chance
	var final_dmg: float = attack_damage * (1.8 if is_crit else 1.0)
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.team = direction
	projectile.damage = final_dmg
	projectile.max_range = attack_range
	projectile.target = target_node
	projectile.lifesteal = lifesteal
	if "is_crit" in projectile:
		projectile.is_crit = is_crit
	if "owner_unit" in projectile:
		projectile.owner_unit = self
	projectile.global_position = global_position
	projectile.move_direction = (target_node.global_position - global_position).normalized()
	get_parent().add_child(projectile)
	if is_crit:
		projectile.scale = Vector2(1.4, 1.4)
		if projectile.has_node("ColorRect"):
			projectile.get_node("ColorRect").color = Color("#f6ad55")

func _cast_q(aim_dir: Vector2) -> void:
	if aim_dir == Vector2.ZERO:
		return
	mana -= Q_MANA
	q_cd = Q_COOLDOWN * (1.0 - cdr)
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.team = direction
	projectile.damage = _estimate_q_damage()
	projectile.max_range = 420.0
	projectile.speed = 750.0
	projectile.target = null
	projectile.is_skill = true
	if "owner_unit" in projectile:
		projectile.owner_unit = self
	projectile.global_position = global_position + aim_dir * 18.0
	projectile.move_direction = aim_dir
	get_parent().add_child(projectile)
	projectile.scale = Vector2(1.9, 1.9)
	if projectile.has_node("ColorRect"):
		projectile.get_node("ColorRect").color = Color("#ff6b6b")

func _cast_e(dash_dir: Vector2) -> void:
	if dash_dir == Vector2.ZERO:
		return
	mana -= E_MANA
	e_cd = E_COOLDOWN * (1.0 - cdr)
	var start_pos: Vector2 = global_position
	var max_dist: float = E_DASH_DIST
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	
	var ray := PhysicsRayQueryParameters2D.create(start_pos, start_pos + dash_dir * max_dist, 6, [get_rid()])
	var hit: Dictionary = space_state.intersect_ray(ray)
	while not hit.is_empty():
		var collider: Object = hit["collider"]
		if collider is StaticBody2D and not collider.is_in_group("structures") and collider.get("direction") == null:
			max_dist = maxf(0.0, start_pos.distance_to(hit["position"]) - 24.0)
			break
		else:
			var excl: Array[RID] = ray.exclude
			excl.append(collider.get_rid())
			ray.exclude = excl
			hit = space_state.intersect_ray(ray)
			
	var min_x: float = _get_arena_min_x()
	var max_x: float = _get_arena_max_x()
	var target_pos: Vector2 = start_pos + dash_dir * max_dist
	target_pos.x = clampf(target_pos.x, min_x, max_x)
	target_pos.y = clampf(target_pos.y, LANE_MIN_Y, LANE_MAX_Y)
	
	if has_node("CollisionShape2D") and $CollisionShape2D.shape != null:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = $CollisionShape2D.shape
		query.collision_mask = 2
		query.exclude = [get_rid()]
		
		var push_steps: int = 0
		query.transform = Transform2D(0.0, target_pos)
		while space_state.intersect_shape(query, 1).size() > 0 and push_steps < 6:
			target_pos += dash_dir * 18.0
			target_pos.x = clampf(target_pos.x, min_x, max_x)
			target_pos.y = clampf(target_pos.y, LANE_MIN_Y, LANE_MAX_Y)
			query.transform = Transform2D(0.0, target_pos)
			push_steps += 1
			
		var dist: float = start_pos.distance_to(target_pos)
		var back_dir: Vector2 = (target_pos - start_pos).normalized()
		while space_state.intersect_shape(query, 1).size() > 0 and dist > 0.0:
			dist = maxf(0.0, dist - 14.0)
			target_pos = start_pos + back_dir * dist
			query.transform = Transform2D(0.0, target_pos)
			
	global_position = target_pos
	active_effects.append({
		"type": "dash",
		"from": start_pos,
		"to": global_position,
		"time": 0.35,
		"max_time": 0.35
	})
	queue_redraw()

func _cast_r(blast_pos: Vector2) -> void:
	mana -= R_MANA
	r_cd = R_COOLDOWN * (1.0 - cdr)
	active_effects.append({
		"type": "blast",
		"pos": blast_pos,
		"radius": R_RADIUS,
		"time": 0.45,
		"max_time": 0.45
	})
	queue_redraw()
	
	var main_node: Node = get_tree().get_first_node_in_group("main")
	if is_instance_valid(main_node) and main_node.has_method("spawn_hit_effect"):
		main_node.spawn_hit_effect(blast_pos, Color("#fc8181"), R_RADIUS, 20)
	
	var ult_damage: float = _estimate_r_damage()
	for node in get_parent().get_children():
		if node != self and node is Node2D and node.has_method("take_damage") and node.get("direction") != null and int(node.get("direction")) != direction:
			if node.is_in_group("structures") or node is StaticBody2D:
				continue
			if node.get("is_dead") == true:
				continue
			var hp_val = node.get("hp")
			if hp_val == null or float(hp_val) <= 0.0:
				continue
			if node.global_position.distance_to(blast_pos) <= R_RADIUS + 20.0:
				if "last_attacker" in node:
					node.last_attacker = self
				node.take_damage(ult_damage)

func _try_buy_item() -> void:
	while build_step < build_order.size():
		var next_item: Dictionary = build_order[build_step]
		if gold < int(next_item["cost"]):
			break
		gold -= int(next_item["cost"])
		build_step += 1
		attack_damage += float(next_item["dmg"])
		attack_cooldown = maxf(0.12, attack_cooldown * float(next_item["as_mult"]))
		speed += float(next_item["spd"])
		max_hp += float(next_item["hp"])
		hp += float(next_item["hp"])
		hp_regen += float(next_item["hp_reg"])
		max_mana += float(next_item["mp"])
		mana += float(next_item["mp"])
		mana_regen += float(next_item["mp_reg"])
		lifesteal += float(next_item["ls"])
		crit_chance = minf(0.75, crit_chance + float(next_item["crit"]))
		spell_amp += float(next_item["amp"])
		cdr = minf(0.45, cdr + float(next_item["cdr"]))
		if has_node("HpBar"):
			$HpBar.size.x = hp_bar_width * hp / max_hp
		_update_tag_label()
		spawn_floating_text(global_position, "Бот зібрав: %s!" % next_item["name"], Color("#feb2b2"))

func heal(amount: float) -> void:
	if is_dead:
		return
	hp = minf(hp + amount, max_hp)
	if has_node("HpBar"):
		$HpBar.size.x = hp_bar_width * hp / max_hp

func add_gold(amount: int, _popup_pos: Vector2 = Vector2.ZERO) -> void:
	gold += amount

func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	if has_node("HpBar"):
		$HpBar.size.x = hp_bar_width * maxf(hp, 0.0) / max_hp
	if hp <= 0.0:
		is_dead = true
		is_healing = false
		going_to_shop = false
		respawn_timer = RESPAWN_TIME
		visible = false
		collision_layer = 0
		
		var player: Node2D = _get_player_hero()
		if is_instance_valid(player):
			if player.has_method("register_kill"):
				player.register_kill(true)
			if is_instance_valid(last_attacker) and last_attacker == player and player.has_method("add_gold"):
				player.add_gold(150, global_position)
		global_position = red_throne_pos + Vector2(-55.0, 0.0)
		_try_buy_item()

func _respawn() -> void:
	is_dead = false
	hp = max_hp
	mana = max_mana
	if has_node("HpBar"):
		$HpBar.size.x = hp_bar_width
	global_position = red_throne_pos + Vector2(-55.0, 0.0)
	last_check_pos = global_position
	visible = true
	collision_layer = 1
	var player: Node2D = _get_player_hero()
	if is_instance_valid(player) and player.has_method("set_bot_respawn"):
		player.set_bot_respawn(0.0)
	spawn_floating_text(global_position, "Бот у бою!", Color("#fc8181"))

func spawn_floating_text(world_pos: Vector2, text_value: String, text_color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.global_position = world_pos + Vector2(-25, -30)
	lbl.add_theme_color_override("font_color", text_color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 15)
	get_parent().add_child(lbl)
	
	var tween := lbl.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 36.0, 0.85)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.85)
	await tween.finished
	if is_instance_valid(lbl):
		lbl.queue_free()
