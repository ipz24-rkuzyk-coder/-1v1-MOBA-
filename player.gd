extends CharacterBody2D

const PROJECTILE_SCENE = preload("res://projectile.tscn")
const PLAYER_SCENE = preload("res://player.tscn")
const ENEMY_HERO_SCRIPT = preload("res://enemy_hero.gd")
const BLUE_THRONE_POS = Vector2(160, 324)
const MAX_INVENTORY_SLOTS = 6
const RESPAWN_TIME: float = 12.0

const Q_MANA: float = 35.0
const Q_COOLDOWN: float = 4.5
const E_MANA: float = 40.0
const E_COOLDOWN: float = 6.0
const E_DASH_DIST: float = 195.0
const R_MANA: float = 80.0
const R_COOLDOWN: float = 14.0
const R_CAST_RANGE: float = 400.0
const R_RADIUS: float = 115.0

@export var speed: float = 240.0
@export var max_hp: float = 350.0
@export var hp_regen: float = 4.0
@export var max_mana: float = 200.0
@export var mana_regen: float = 6.0
@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 0.45
@export var attack_range: float = 230.0

var direction: int = 1
var hp: float
var mana: float
var gold: int = 120
var passive_gold_timer: float = 0.0
var cooldown_timer: float = 0.0
var hp_bar_width: float = 32.0
var last_attacker: Node2D = null

var lifesteal: float = 0.0
var crit_chance: float = 0.0
var spell_amp: float = 0.0
var cdr: float = 0.0
var elixir_timer: float = 0.0

var is_dead: bool = false
var respawn_timer: float = 0.0

var player_kills: int = 0
var bot_kills: int = 0
var bot_respawn_left: float = 0.0
var match_seconds: float = 0.0

var q_cd: float = 0.0
var e_cd: float = 0.0
var r_cd: float = 0.0
var b_key_held: bool = false
var esc_key_held: bool = false
var q_key_held: bool = false
var e_key_held: bool = false
var r_key_held: bool = false

var active_effects: Array[Dictionary] = []
var inventory: Array[Dictionary] = []

var consumables: Array[Dictionary] = [
	{"id": "potion", "name": "Зілля життя (+150 HP, +90 MP)", "cost": 60},
	{"id": "elixir", "name": "Еліксир люті (+20 Атака, +15% Шв.Ат на 45с)", "cost": 160}
]

var item_catalog: Array[Dictionary] = [
	{
		"id": "boots",
		"t1_short": "ЧОБ", "t1_name": "Чоботи вітру", "t1_cost": 240,
		"t1_desc": "+45 до швидкості руху",
		"t2_short": "ТЕЛ+", "t2_name": "Чоботи телепорту", "t2_cost": 660,
		"t2_desc": "+40 Рух, +12% Швидк. атаки, -15% КД скілів",
		"color": Color("#38a169"),
		"t1": {"dmg": 0.0, "as_mult": 1.0, "spd": 45.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
		"t2": {"dmg": 0.0, "as_mult": 0.88, "spd": 40.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.15}
	},
	{
		"id": "crystal",
		"t1_short": "МАН", "t1_name": "Кристал мани", "t1_cost": 250,
		"t1_desc": "+120 Макс. MP та +5 MP/с",
		"t2_short": "АРХ+", "t2_name": "Сфера архімага", "t2_cost": 750,
		"t2_desc": "+160 Макс. MP, +7 MP/с, +25% шкоди скілів Q/R",
		"color": Color("#3182ce"),
		"t1": {"dmg": 0.0, "as_mult": 1.0, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 120.0, "mp_reg": 5.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
		"t2": {"dmg": 0.0, "as_mult": 1.0, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 160.0, "mp_reg": 7.0, "ls": 0.0, "crit": 0.0, "amp": 0.25, "cdr": 0.0}
	},
	{
		"id": "sword",
		"t1_short": "МЕЧ", "t1_name": "Меч бійця", "t1_cost": 280,
		"t1_desc": "+15 до шкоди автоатак",
		"t2_short": "РУЙ+", "t2_name": "Клинок руйнівника", "t2_cost": 820,
		"t2_desc": "+35 Атаки та +22% шанс криту (x1.8)",
		"color": Color("#e53e3e"),
		"t1": {"dmg": 15.0, "as_mult": 1.0, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
		"t2": {"dmg": 35.0, "as_mult": 1.0, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.22, "amp": 0.0, "cdr": 0.0}
	},
	{
		"id": "bow",
		"t1_short": "ЛУК", "t1_name": "Лук швидкості", "t1_cost": 300,
		"t1_desc": "+25% до швидкості атаки",
		"t2_short": "БУР+", "t2_name": "Арбалет бурі", "t2_cost": 800,
		"t2_desc": "+30% до швидкості атаки та +20 Атаки",
		"color": Color("#dd6b20"),
		"t1": {"dmg": 0.0, "as_mult": 0.80, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
		"t2": {"dmg": 20.0, "as_mult": 0.76, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0}
	},
	{
		"id": "armor",
		"t1_short": "БРОН", "t1_name": "Броня титана", "t1_cost": 340,
		"t1_desc": "+150 Макс. HP та +3 HP/с",
		"t2_short": "ЕГІ+", "t2_name": "Егіда безсмертя", "t2_cost": 860,
		"t2_desc": "+270 Макс. HP та +7 HP/с",
		"color": Color("#319795"),
		"t1": {"dmg": 0.0, "as_mult": 1.0, "spd": 0.0, "hp": 150.0, "hp_reg": 3.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
		"t2": {"dmg": 0.0, "as_mult": 1.0, "spd": 0.0, "hp": 270.0, "hp_reg": 7.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.0, "crit": 0.0, "amp": 0.0, "cdr": 0.0}
	},
	{
		"id": "vamp",
		"t1_short": "КИНД", "t1_name": "Вампірський кинджал", "t1_cost": 380,
		"t1_desc": "+15 Атаки та +12% Вампіризму від пострілів",
		"t2_short": "ДРА+", "t2_name": "Серце дракона", "t2_cost": 970,
		"t2_desc": "+30 Атаки, +180 HP та +10% Вампіризму",
		"color": Color("#805ad5"),
		"t1": {"dmg": 15.0, "as_mult": 1.0, "spd": 0.0, "hp": 0.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.12, "crit": 0.0, "amp": 0.0, "cdr": 0.0},
		"t2": {"dmg": 30.0, "as_mult": 1.0, "spd": 0.0, "hp": 180.0, "hp_reg": 0.0, "mp": 0.0, "mp_reg": 0.0, "ls": 0.10, "crit": 0.0, "amp": 0.0, "cdr": 0.0}
	}
]

var hp_bar_ui: ProgressBar
var hp_label_ui: Label
var mana_bar_ui: ProgressBar
var mana_label_ui: Label
var gold_label_ui: Label
var fountain_label_ui: Label
var elixir_label_ui: Label
var slot_panels: Array[PanelContainer] = []
var slot_labels: Array[Label] = []

var score_label_ui: Label
var timer_label_ui: Label
var respawn_status_ui: Label
var player_dead_banner: PanelContainer
var player_dead_label: Label

var skill_panels: Array[PanelContainer] = []
var skill_status_labels: Array[Label] = []

var shop_panel: PanelContainer
var shop_zone_label: Label
var shop_stats_label: Label
var consumable_buttons: Array[Button] = []
var item_name_labels: Array[Label] = []
var item_desc_labels: Array[Label] = []
var item_badge_labels: Array[Label] = []
var shop_buy_buttons: Array[Button] = []

func _ready() -> void:
	add_to_group("heroes")
	hp = max_hp
	mana = max_mana
	hp_bar_width = $HpBar.size.x
	collision_mask = 3
	_build_hud()
	_build_scoreboard_hud()
	_build_skills_hud()
	_build_shop_ui()
	_update_hud(false)
	_update_skills_hud()
	_refresh_shop_ui()
	queue_redraw()
	call_deferred("_spawn_enemy_bot")

func _spawn_enemy_bot() -> void:
	for h in get_tree().get_nodes_in_group("heroes"):
		if is_instance_valid(h) and h.get("direction") == -1:
			return
	var bot := PLAYER_SCENE.instantiate()
	bot.name = "EnemyHero"
	bot.set_script(ENEMY_HERO_SCRIPT)
	get_parent().add_child(bot)
	var saved_diff: String = str(Engine.get_meta("bot_difficulty", "norm"))
	if bot.has_method("set_difficulty"):
		bot.set_difficulty(saved_diff)

func _draw() -> void:
	if is_dead:
		return
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 48, Color(0.4, 0.75, 1.0, 0.16), 1.5)
	
	for ef in active_effects:
		var alpha: float = clamp(float(ef["time"]) / float(ef["max_time"]), 0.0, 1.0)
		if ef["type"] == "dash":
			draw_line(to_local(ef["from"]), to_local(ef["to"]), Color(0.38, 0.85, 0.98, alpha * 0.75), 18.0)
			draw_circle(to_local(ef["from"]), 14.0 * alpha, Color(0.38, 0.85, 0.98, alpha * 0.5))
		elif ef["type"] == "blast":
			var progress: float = 1.0 - alpha * 0.35
			var center: Vector2 = to_local(ef["pos"])
			draw_circle(center, float(ef["radius"]) * progress, Color(0.55, 0.36, 0.96, alpha * 0.35))
			draw_arc(center, float(ef["radius"]), 0.0, TAU, 48, Color(0.78, 0.62, 1.0, alpha), 3.0)

func _physics_process(delta: float) -> void:
	if q_cd > 0.0:
		q_cd = max(0.0, q_cd - delta)
	if e_cd > 0.0:
		e_cd = max(0.0, e_cd - delta)
	if r_cd > 0.0:
		r_cd = max(0.0, r_cd - delta)
	if elixir_timer > 0.0:
		elixir_timer = max(0.0, elixir_timer - delta)
		
	if active_effects.size() > 0:
		for i in range(active_effects.size() - 1, -1, -1):
			active_effects[i]["time"] -= delta
			if float(active_effects[i]["time"]) <= 0.0:
				active_effects.remove_at(i)
		queue_redraw()
		
	var b_pressed: bool = Input.is_key_pressed(KEY_B)
	if b_pressed and not b_key_held:
		toggle_shop()
	b_key_held = b_pressed
	
	var esc_pressed: bool = Input.is_key_pressed(KEY_ESCAPE)
	if esc_pressed and not esc_key_held and shop_panel.visible:
		toggle_shop(false)
	esc_key_held = esc_pressed
	
	passive_gold_timer += delta
	if passive_gold_timer >= 1.0:
		passive_gold_timer -= 1.0
		gold += 1
		
	if is_dead:
		respawn_timer -= delta
		player_dead_banner.visible = true
		player_dead_label.text = "ВИ ЗАГИНУЛИ! Відродження через %.1f с (можна купувати предмети на [B])" % max(0.0, respawn_timer)
		if respawn_timer <= 0.0:
			_respawn_player()
		_update_hud(false)
		_update_skills_hud()
		if shop_panel.visible:
			_refresh_shop_ui()
		return
		
	player_dead_banner.visible = false
	
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
	
	var on_fountain: bool = _can_shop_here()
	var current_hp_regen: float = hp_regen + (45.0 if on_fountain else 0.0)
	var current_mana_regen: float = mana_regen + (35.0 if on_fountain else 0.0)
	
	if hp < max_hp:
		hp = min(hp + current_hp_regen * delta, max_hp)
		$HpBar.size.x = hp_bar_width * hp / max_hp
		
	if mana < max_mana:
		mana = min(mana + current_mana_regen * delta, max_mana)
	
	var q_pressed: bool = Input.is_key_pressed(KEY_Q)
	if q_pressed and not q_key_held and not shop_panel.visible:
		cast_q()
	q_key_held = q_pressed
	
	var e_pressed: bool = Input.is_key_pressed(KEY_E)
	if e_pressed and not e_key_held and not shop_panel.visible:
		cast_e()
	e_key_held = e_pressed
	
	var r_pressed: bool = Input.is_key_pressed(KEY_R)
	if r_pressed and not r_key_held and not shop_panel.visible:
		cast_r()
	r_key_held = r_pressed
	
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		
	if not shop_panel.visible and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and cooldown_timer <= 0.0:
		shoot()
		cooldown_timer = _get_effective_attack_cooldown()
	
	_update_hud(on_fountain)
	_update_skills_hud()
	if shop_panel.visible:
		_refresh_shop_ui()

func _can_shop_here() -> bool:
	return is_dead or (global_position.distance_to(BLUE_THRONE_POS) <= 200.0)

func _get_effective_damage() -> float:
	return attack_damage + (20.0 if elixir_timer > 0.0 else 0.0)

func _get_effective_attack_cooldown() -> float:
	return attack_cooldown * (0.85 if elixir_timer > 0.0 else 1.0)

func cast_q() -> void:
	if q_cd > 0.0:
		spawn_floating_text(global_position, "Q: %.1fс" % q_cd, Color("#a0aec0"))
		return
	if mana < Q_MANA:
		spawn_floating_text(global_position, "Не вистачає мани!", Color("#63b3ed"))
		return
		
	mana -= Q_MANA
	q_cd = Q_COOLDOWN * (1.0 - cdr)
	
	var aim_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT
		
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.team = direction
	projectile.damage = (_get_effective_damage() * 2.2 + 30.0) * (1.0 + spell_amp)
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
		projectile.get_node("ColorRect").color = Color("#00f5d4")

func cast_e() -> void:
	if e_cd > 0.0:
		spawn_floating_text(global_position, "E: %.1fс" % e_cd, Color("#a0aec0"))
		return
	if mana < E_MANA:
		spawn_floating_text(global_position, "Не вистачає мани!", Color("#63b3ed"))
		return
		
	mana -= E_MANA
	e_cd = E_COOLDOWN * (1.0 - cdr)
	
	var start_pos: Vector2 = global_position
	var dash_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	if dash_dir == Vector2.ZERO:
		dash_dir = Vector2.RIGHT
		
	var max_dist: float = E_DASH_DIST
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	
	var ray := PhysicsRayQueryParameters2D.create(start_pos, start_pos + dash_dir * max_dist, 7, [get_rid()])
	var hit: Dictionary = space_state.intersect_ray(ray)
	while not hit.is_empty():
		var collider: Object = hit["collider"]
		if collider is StaticBody2D and not collider.is_in_group("structures") and collider.get("direction") == null:
			max_dist = max(0.0, start_pos.distance_to(hit["position"]) - 24.0)
			break
		else:
			var excl: Array[RID] = ray.exclude
			excl.append(collider.get_rid())
			ray.exclude = excl
			hit = space_state.intersect_ray(ray)
			
	var target_pos: Vector2 = start_pos + dash_dir * max_dist
	var vp_size: Vector2 = get_viewport_rect().size
	target_pos.x = clampf(target_pos.x, 45.0, vp_size.x - 45.0)
	target_pos.y = clampf(target_pos.y, 45.0, vp_size.y - 45.0)
	
	if has_node("CollisionShape2D") and $CollisionShape2D.shape != null:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = $CollisionShape2D.shape
		query.collision_mask = 2
		query.exclude = [get_rid()]
		
		var push_steps: int = 0
		query.transform = Transform2D(0.0, target_pos)
		while space_state.intersect_shape(query, 1).size() > 0 and push_steps < 6:
			target_pos += dash_dir * 18.0
			target_pos.x = clampf(target_pos.x, 45.0, vp_size.x - 45.0)
			target_pos.y = clampf(target_pos.y, 45.0, vp_size.y - 45.0)
			query.transform = Transform2D(0.0, target_pos)
			push_steps += 1
			
		var dist: float = start_pos.distance_to(target_pos)
		var back_dir: Vector2 = (target_pos - start_pos).normalized()
		while space_state.intersect_shape(query, 1).size() > 0 and dist > 0.0:
			dist = max(0.0, dist - 14.0)
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

func cast_r() -> void:
	if r_cd > 0.0:
		spawn_floating_text(global_position, "R: %.1fс" % r_cd, Color("#a0aec0"))
		return
	if mana < R_MANA:
		spawn_floating_text(global_position, "Не вистачає мани!", Color("#63b3ed"))
		return
		
	mana -= R_MANA
	r_cd = R_COOLDOWN * (1.0 - cdr)
	
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length() > R_CAST_RANGE:
		to_mouse = to_mouse.normalized() * R_CAST_RANGE
	var blast_pos: Vector2 = global_position + to_mouse
	
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
		main_node.spawn_hit_effect(blast_pos, Color("#b794f4"), R_RADIUS, 20)
	
	var ult_damage: float = (_get_effective_damage() * 2.5 + 90.0) * (1.0 + spell_amp)
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
				spawn_floating_text(node.global_position, "-%d" % int(ult_damage), Color("#d6bcfa"))

func toggle_shop(force_state = null) -> void:
	if force_state == null:
		shop_panel.visible = not shop_panel.visible
	else:
		shop_panel.visible = bool(force_state)
	if shop_panel.visible:
		_refresh_shop_ui()

func buy_consumable(index: int) -> void:
	if not _can_shop_here():
		spawn_floating_text(global_position, "Купівля лише на фонтані!", Color("#fc8181"))
		return
	var cons: Dictionary = consumables[index]
	var cost: int = int(cons["cost"])
	if gold < cost:
		return
	gold -= cost
	if str(cons["id"]) == "potion":
		hp = min(hp + 150.0, max_hp)
		mana = min(mana + 90.0, max_mana)
		$HpBar.size.x = hp_bar_width * hp / max_hp
		spawn_floating_text(global_position, "+150 HP / +90 MP!", Color("#68d391"))
	elif str(cons["id"]) == "elixir":
		elixir_timer = 45.0
		spawn_floating_text(global_position, "Еліксир люті (45с)!", Color("#f6ad55"))
	_refresh_shop_ui()

func buy_or_upgrade_item(index: int) -> void:
	if not _can_shop_here():
		spawn_floating_text(global_position, "Купівля лише на фонтані!", Color("#fc8181"))
		return
	if index < 0 or index >= item_catalog.size():
		return
		
	var entry: Dictionary = item_catalog[index]
	var item_id: String = str(entry["id"])
	var existing_slot: int = _find_inventory_slot(item_id)
	
	if existing_slot == -1:
		var t1_cost: int = int(entry["t1_cost"])
		if inventory.size() >= MAX_INVENTORY_SLOTS or gold < t1_cost:
			return
		gold -= t1_cost
		inventory.append({
			"id": item_id,
			"tier": 1,
			"short": str(entry["t1_short"]),
			"color": entry["color"]
		})
		_apply_stat_block(entry["t1"])
		spawn_floating_text(global_position, "Куплено: %s!" % entry["t1_name"], Color("#ffd700"))
	elif int(inventory[existing_slot]["tier"]) == 1:
		var t2_cost: int = int(entry["t2_cost"])
		if gold < t2_cost:
			return
		gold -= t2_cost
		inventory[existing_slot]["tier"] = 2
		inventory[existing_slot]["short"] = str(entry["t2_short"])
		_apply_stat_block(entry["t2"])
		spawn_floating_text(global_position, "Покращено: %s (T2)!" % entry["t2_name"], Color("#ffd700"))
		
	_update_inventory_slots()
	_refresh_shop_ui()

func _find_inventory_slot(item_id: String) -> int:
	for i in range(inventory.size()):
		if str(inventory[i]["id"]) == item_id:
			return i
	return -1

func _apply_stat_block(stats: Dictionary) -> void:
	attack_damage += float(stats["dmg"])
	attack_cooldown = max(0.12, attack_cooldown * float(stats["as_mult"]))
	speed += float(stats["spd"])
	max_hp += float(stats["hp"])
	hp += float(stats["hp"])
	hp_regen += float(stats["hp_reg"])
	max_mana += float(stats["mp"])
	mana += float(stats["mp"])
	mana_regen += float(stats["mp_reg"])
	lifesteal += float(stats["ls"])
	crit_chance = min(0.75, crit_chance + float(stats["crit"]))
	spell_amp += float(stats["amp"])
	cdr = min(0.45, cdr + float(stats["cdr"]))
	$HpBar.size.x = hp_bar_width * hp / max_hp

func find_target_under_cursor() -> Node2D:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var best_target: Node2D = null
	var best_cursor_dist: float = 55.0
	
	for node in get_parent().get_children():
		if node != self and node is Node2D and node.has_method("take_damage") and node.get("direction") != null and int(node.get("direction")) != direction:
			if node.get("is_dead") == true:
				continue
			var hp_val = node.get("hp")
			if hp_val == null or float(hp_val) <= 0.0:
				continue
			if global_position.distance_to(node.global_position) <= attack_range + 35.0:
				var d: float = mouse_pos.distance_to(node.global_position)
				if d < best_cursor_dist:
					best_cursor_dist = d
					best_target = node
	return best_target

func shoot() -> void:
	var locked_target: Node2D = find_target_under_cursor()
	var is_crit: bool = randf() < crit_chance
	var final_dmg: float = _get_effective_damage() * (1.8 if is_crit else 1.0)
	
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.team = direction
	projectile.damage = final_dmg
	projectile.max_range = attack_range
	projectile.target = locked_target
	projectile.lifesteal = lifesteal
	if "is_crit" in projectile:
		projectile.is_crit = is_crit
	if "owner_unit" in projectile:
		projectile.owner_unit = self
	projectile.global_position = global_position
	if locked_target != null:
		projectile.move_direction = (locked_target.global_position - global_position).normalized()
	else:
		projectile.move_direction = (get_global_mouse_position() - global_position).normalized()
	get_parent().add_child(projectile)
	
	if is_crit:
		projectile.scale = Vector2(1.4, 1.4)
		if projectile.has_node("ColorRect"):
			projectile.get_node("ColorRect").color = Color("#ffd700")

func heal(amount: float) -> void:
	if is_dead:
		return
	hp = min(hp + amount, max_hp)
	$HpBar.size.x = hp_bar_width * hp / max_hp

func add_gold(amount: int, popup_pos: Vector2 = Vector2.ZERO) -> void:
	gold += amount
	if popup_pos != Vector2.ZERO:
		spawn_floating_text(popup_pos, "+%dg" % amount, Color("#ffd700"))

func register_kill(player_got_kill: bool) -> void:
	if player_got_kill:
		player_kills += 1
	else:
		bot_kills += 1
	_update_scoreboard_hud()

func set_bot_respawn(seconds_left: float) -> void:
	bot_respawn_left = seconds_left
	_update_scoreboard_hud()

func set_match_time(seconds: float) -> void:
	match_seconds = seconds
	if is_instance_valid(timer_label_ui):
		var total: int = int(match_seconds)
		timer_label_ui.text = "%02d:%02d" % [int(total / 60.0), total % 60]

func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	$HpBar.size.x = hp_bar_width * max(hp, 0.0) / max_hp
	if hp <= 0.0:
		is_dead = true
		respawn_timer = RESPAWN_TIME
		visible = false
		collision_layer = 0
		register_kill(false)
		if is_instance_valid(last_attacker) and last_attacker.has_method("add_gold"):
			last_attacker.add_gold(150, global_position)
		global_position = BLUE_THRONE_POS

func _respawn_player() -> void:
	is_dead = false
	hp = max_hp
	mana = max_mana
	$HpBar.size.x = hp_bar_width
	global_position = BLUE_THRONE_POS + Vector2(150, 0)
	visible = true
	collision_layer = 1
	player_dead_banner.visible = false
	spawn_floating_text(global_position, "Ви відродилися!", Color("#63b3ed"))

func spawn_floating_text(world_pos: Vector2, text_value: String, text_color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.global_position = world_pos + Vector2(-20, -30)
	lbl.add_theme_color_override("font_color", text_color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 16)
	get_parent().add_child(lbl)
	
	var tween := lbl.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 38.0, 0.85)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.85)
	await tween.finished
	if is_instance_valid(lbl):
		lbl.queue_free()

func _build_scoreboard_hud() -> void:
	var canvas := get_node("HudLayer")
	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root_ctrl)
	
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_panel.offset_top = 12
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.13, 0.9)
	sb.border_color = Color(0.25, 0.35, 0.5, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	top_panel.add_theme_stylebox_override("panel", sb)
	root_ctrl.add_child(top_panel)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	top_panel.add_child(vbox)
	
	score_label_ui = Label.new()
	score_label_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label_ui.add_theme_font_size_override("font_size", 16)
	vbox.add_child(score_label_ui)
	
	timer_label_ui = Label.new()
	timer_label_ui.text = "00:00"
	timer_label_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label_ui.add_theme_color_override("font_color", Color("#a0aec0"))
	timer_label_ui.add_theme_font_size_override("font_size", 12)
	vbox.add_child(timer_label_ui)
	
	respawn_status_ui = Label.new()
	respawn_status_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	respawn_status_ui.add_theme_color_override("font_color", Color("#68d391"))
	respawn_status_ui.add_theme_font_size_override("font_size", 12)
	respawn_status_ui.visible = false
	vbox.add_child(respawn_status_ui)
	
	player_dead_banner = PanelContainer.new()
	player_dead_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	player_dead_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	player_dead_banner.offset_top = 86
	player_dead_banner.visible = false
	var dead_sb := StyleBoxFlat.new()
	dead_sb.bg_color = Color(0.35, 0.08, 0.08, 0.92)
	dead_sb.border_color = Color("#fc8181")
	dead_sb.set_border_width_all(2)
	dead_sb.set_corner_radius_all(8)
	dead_sb.set_content_margin_all(8)
	player_dead_banner.add_theme_stylebox_override("panel", dead_sb)
	root_ctrl.add_child(player_dead_banner)
	
	player_dead_label = Label.new()
	player_dead_label.add_theme_color_override("font_color", Color("#fed7d7"))
	player_dead_label.add_theme_font_size_override("font_size", 14)
	player_dead_banner.add_child(player_dead_label)
	
	_update_scoreboard_hud()

func _update_scoreboard_hud() -> void:
	if is_instance_valid(score_label_ui):
		score_label_ui.text = "Ви   %d  :  %d   Бот" % [player_kills, bot_kills]
	if is_instance_valid(respawn_status_ui):
		if bot_respawn_left > 0.0:
			respawn_status_ui.visible = true
			respawn_status_ui.text = "Бот відродиться через %.1f с" % bot_respawn_left
		else:
			respawn_status_ui.visible = false

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HudLayer"
	add_child(canvas)
	
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.13, 0.88)
	sb.border_color = Color(0.25, 0.35, 0.5, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	canvas.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)
	
	gold_label_ui = Label.new()
	gold_label_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_label_ui.add_theme_color_override("font_color", Color("#ffd700"))
	gold_label_ui.add_theme_font_size_override("font_size", 18)
	top_row.add_child(gold_label_ui)
	
	var shop_btn := Button.new()
	shop_btn.text = "[B] Крамниця"
	shop_btn.focus_mode = Control.FOCUS_NONE
	shop_btn.pressed.connect(toggle_shop)
	top_row.add_child(shop_btn)
	
	hp_bar_ui = _create_bar(Color("#38a169"), Color(0.15, 0.25, 0.18))
	vbox.add_child(hp_bar_ui)
	hp_label_ui = Label.new()
	hp_label_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label_ui.add_theme_font_size_override("font_size", 12)
	hp_bar_ui.add_child(hp_label_ui)
	hp_label_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	mana_bar_ui = _create_bar(Color("#3182ce"), Color(0.12, 0.18, 0.30))
	vbox.add_child(mana_bar_ui)
	mana_label_ui = Label.new()
	mana_label_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_label_ui.add_theme_font_size_override("font_size", 12)
	mana_bar_ui.add_child(mana_label_ui)
	mana_label_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var inv_row := HBoxContainer.new()
	inv_row.add_theme_constant_override("separation", 4)
	vbox.add_child(inv_row)
	
	for i in range(MAX_INVENTORY_SLOTS):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(36, 28)
		var slot_sb := StyleBoxFlat.new()
		slot_sb.bg_color = Color(0.12, 0.15, 0.22, 0.9)
		slot_sb.border_color = Color(0.3, 0.38, 0.5)
		slot_sb.set_border_width_all(1)
		slot_sb.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", slot_sb)
		
		var lbl := Label.new()
		lbl.text = "-"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		slot.add_child(lbl)
		
		inv_row.add_child(slot)
		slot_panels.append(slot)
		slot_labels.append(lbl)
	
	fountain_label_ui = Label.new()
	fountain_label_ui.text = "⚡ Фонтан: лікування і крамниця"
	fountain_label_ui.add_theme_color_override("font_color", Color("#68d391"))
	fountain_label_ui.add_theme_font_size_override("font_size", 13)
	vbox.add_child(fountain_label_ui)
	
	elixir_label_ui = Label.new()
	elixir_label_ui.visible = false
	elixir_label_ui.add_theme_color_override("font_color", Color("#f6ad55"))
	elixir_label_ui.add_theme_font_size_override("font_size", 13)
	vbox.add_child(elixir_label_ui)

func _build_skills_hud() -> void:
	var canvas := get_node("HudLayer")
	
	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root_ctrl)
	
	var bar_panel := PanelContainer.new()
	bar_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar_panel.offset_bottom = -14
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.13, 0.9)
	sb.border_color = Color(0.25, 0.35, 0.5, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	bar_panel.add_theme_stylebox_override("panel", sb)
	root_ctrl.add_child(bar_panel)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	bar_panel.add_child(hbox)
	
	var skills_meta := [
		{"key": "[Q]", "title": "Залп", "cost": int(Q_MANA)},
		{"key": "[E]", "title": "Блінк", "cost": int(E_MANA)},
		{"key": "[R]", "title": "Удар", "cost": int(R_MANA)}
	]
	
	for info in skills_meta:
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(106, 54)
		var box_sb := StyleBoxFlat.new()
		box_sb.bg_color = Color(0.11, 0.16, 0.24, 0.95)
		box_sb.border_color = Color("#4fd1c5")
		box_sb.set_border_width_all(2)
		box_sb.set_corner_radius_all(6)
		box_sb.set_content_margin_all(6)
		box.add_theme_stylebox_override("panel", box_sb)
		hbox.add_child(box)
		
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		box.add_child(vbox)
		
		var top_lbl := Label.new()
		top_lbl.text = "%s %s (%d MP)" % [info["key"], info["title"], info["cost"]]
		top_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(top_lbl)
		
		var status_lbl := Label.new()
		status_lbl.text = "ГОТОВО"
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(status_lbl)
		
		skill_panels.append(box)
		skill_status_labels.append(status_lbl)

func _update_skills_hud() -> void:
	var cds: Array[float] = [q_cd, e_cd, r_cd]
	var costs: Array[float] = [Q_MANA, E_MANA, R_MANA]
	var ready_colors: Array[Color] = [Color("#00f5d4"), Color("#63b3ed"), Color("#b794f4")]
	
	for i in range(3):
		var box: PanelContainer = skill_panels[i]
		var lbl: Label = skill_status_labels[i]
		var box_sb := box.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		
		if cds[i] > 0.0:
			lbl.text = "%.1f с" % cds[i]
			lbl.add_theme_color_override("font_color", Color("#a0aec0"))
			box_sb.bg_color = Color(0.08, 0.10, 0.14, 0.95)
			box_sb.border_color = Color(0.28, 0.32, 0.40)
		elif mana < costs[i]:
			lbl.text = "МАЛО MP"
			lbl.add_theme_color_override("font_color", Color("#63b3ed"))
			box_sb.bg_color = Color(0.09, 0.12, 0.20, 0.95)
			box_sb.border_color = Color("#3182ce")
		else:
			lbl.text = "ГОТОВО"
			lbl.add_theme_color_override("font_color", Color("#68d391"))
			box_sb.bg_color = Color(0.11, 0.16, 0.24, 0.95)
			box_sb.border_color = ready_colors[i]
			
		box.add_theme_stylebox_override("panel", box_sb)

func _build_shop_ui() -> void:
	var canvas := get_node("HudLayer")
	
	shop_panel = PanelContainer.new()
	shop_panel.visible = false
	shop_panel.position = Vector2(265, 36)
	shop_panel.custom_minimum_size = Vector2(620, 480)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.97)
	sb.border_color = Color("#ecc94b")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	shop_panel.add_theme_stylebox_override("panel", sb)
	canvas.add_child(shop_panel)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	shop_panel.add_child(main_vbox)
	
	var header := HBoxContainer.new()
	main_vbox.add_child(header)
	
	var title := Label.new()
	title.text = "КРАМНИЦЯ: ЕВОЛЮЦІЯ ПРЕДМЕТІВ (T1 → T2)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("#ffd700"))
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)
	
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func(): toggle_shop(false))
	header.add_child(close_btn)
	
	shop_zone_label = Label.new()
	shop_zone_label.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(shop_zone_label)
	
	shop_stats_label = Label.new()
	shop_stats_label.add_theme_color_override("font_color", Color("#a0aec0"))
	shop_stats_label.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(shop_stats_label)
	
	var cons_row := HBoxContainer.new()
	cons_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(cons_row)
	
	for i in range(consumables.size()):
		var c: Dictionary = consumables[i]
		var c_btn := Button.new()
		c_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_btn.custom_minimum_size = Vector2(0, 30)
		c_btn.text = "%s (%dg)" % [c["name"], c["cost"]]
		c_btn.add_theme_font_size_override("font_size", 11)
		c_btn.focus_mode = Control.FOCUS_NONE
		c_btn.pressed.connect(buy_consumable.bind(i))
		cons_row.add_child(c_btn)
		consumable_buttons.append(c_btn)
	
	main_vbox.add_child(HSeparator.new())
	
	for i in range(item_catalog.size()):
		var entry: Dictionary = item_catalog[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		main_vbox.add_child(row)
		
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(54, 34)
		var badge_sb := StyleBoxFlat.new()
		badge_sb.bg_color = entry["color"]
		badge_sb.set_corner_radius_all(6)
		badge.add_theme_stylebox_override("panel", badge_sb)
		var badge_lbl := Label.new()
		badge_lbl.text = str(entry["t1_short"])
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_lbl.add_theme_font_size_override("font_size", 11)
		badge.add_child(badge_lbl)
		row.add_child(badge)
		item_badge_labels.append(badge_lbl)
		
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 1)
		row.add_child(info_vbox)
		
		var name_lbl := Label.new()
		name_lbl.text = str(entry["t1_name"])
		name_lbl.add_theme_font_size_override("font_size", 14)
		info_vbox.add_child(name_lbl)
		item_name_labels.append(name_lbl)
		
		var desc_lbl := Label.new()
		desc_lbl.text = str(entry["t1_desc"])
		desc_lbl.add_theme_color_override("font_color", Color("#cbd5e0"))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		info_vbox.add_child(desc_lbl)
		item_desc_labels.append(desc_lbl)
		
		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(148, 34)
		buy_btn.add_theme_font_size_override("font_size", 12)
		buy_btn.focus_mode = Control.FOCUS_NONE
		buy_btn.pressed.connect(buy_or_upgrade_item.bind(i))
		row.add_child(buy_btn)
		shop_buy_buttons.append(buy_btn)

func _update_inventory_slots() -> void:
	for i in range(MAX_INVENTORY_SLOTS):
		var slot: PanelContainer = slot_panels[i]
		var lbl: Label = slot_labels[i]
		var slot_sb := slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if i < inventory.size():
			slot_sb.bg_color = inventory[i]["color"]
			if int(inventory[i]["tier"]) == 2:
				slot_sb.border_color = Color("#ffd700")
				slot_sb.set_border_width_all(2)
			else:
				slot_sb.border_color = Color(0.8, 0.85, 0.95)
				slot_sb.set_border_width_all(1)
			lbl.text = str(inventory[i]["short"])
		else:
			slot_sb.bg_color = Color(0.12, 0.15, 0.22, 0.9)
			slot_sb.border_color = Color(0.3, 0.38, 0.5)
			slot_sb.set_border_width_all(1)
			lbl.text = "-"
		slot.add_theme_stylebox_override("panel", slot_sb)

func _refresh_shop_ui() -> void:
	var can_buy: bool = _can_shop_here()
	if can_buy:
		shop_zone_label.text = "✓ Ви на базі — покупки та покращення доступні"
		shop_zone_label.add_theme_color_override("font_color", Color("#68d391"))
	else:
		shop_zone_label.text = "⚠ Поверніться на фонтан біля свого Трону, щоб купити предмети"
		shop_zone_label.add_theme_color_override("font_color", Color("#fc8181"))
		
	var attacks_per_sec: float = 1.0 / _get_effective_attack_cooldown()
	shop_stats_label.text = "Атака: %d | Шв.Ат: %.2f/с | Вампіризм: %d%% | Крит: %d%% | Скіли: +%d%%" % [
		int(_get_effective_damage()), attacks_per_sec, int(lifesteal * 100), int(crit_chance * 100), int(spell_amp * 100)
	]
	
	for i in range(consumables.size()):
		consumable_buttons[i].disabled = (not can_buy) or (gold < int(consumables[i]["cost"]))
		
	for i in range(item_catalog.size()):
		var entry: Dictionary = item_catalog[i]
		var slot_idx: int = _find_inventory_slot(str(entry["id"]))
		var btn: Button = shop_buy_buttons[i]
		
		if slot_idx == -1:
			var t1_cost: int = int(entry["t1_cost"])
			item_badge_labels[i].text = str(entry["t1_short"])
			item_name_labels[i].text = "%s [T1]" % entry["t1_name"]
			item_name_labels[i].add_theme_color_override("font_color", Color.WHITE)
			item_desc_labels[i].text = str(entry["t1_desc"])
			btn.text = "Купити (%dg)" % t1_cost
			btn.disabled = (not can_buy) or (gold < t1_cost)
		elif int(inventory[slot_idx]["tier"]) == 1:
			var t2_cost: int = int(entry["t2_cost"])
			item_badge_labels[i].text = str(entry["t2_short"])
			item_name_labels[i].text = "↑ %s [T2]" % entry["t2_name"]
			item_name_labels[i].add_theme_color_override("font_color", Color("#ffd700"))
			item_desc_labels[i].text = str(entry["t2_desc"])
			btn.text = "Покращити (%dg)" % t2_cost
			btn.disabled = (not can_buy) or (gold < t2_cost)
		else:
			item_badge_labels[i].text = str(entry["t2_short"])
			item_name_labels[i].text = "★ %s [MAX]" % entry["t2_name"]
			item_name_labels[i].add_theme_color_override("font_color", Color("#68d391"))
			item_desc_labels[i].text = str(entry["t2_desc"])
			btn.text = "Зібрано"
			btn.disabled = true

func _create_bar(fill_col: Color, bg_col: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(236, 20)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_col
	fill_sb.set_corner_radius_all(4)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = bg_col
	bg_sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_sb)
	bar.add_theme_stylebox_override("background", bg_sb)
	return bar

func _update_hud(on_fountain: bool) -> void:
	gold_label_ui.text = "Золото: %d g" % gold
	hp_bar_ui.max_value = max_hp
	hp_bar_ui.value = hp
	var bonus_hp: float = 45.0 if on_fountain else 0.0
	hp_label_ui.text = "HP: %d / %d (+%.1f/с)" % [int(hp), int(max_hp), hp_regen + bonus_hp]
	
	mana_bar_ui.max_value = max_mana
	mana_bar_ui.value = mana
	var bonus_mp: float = 35.0 if on_fountain else 0.0
	mana_label_ui.text = "MP: %d / %d (+%.1f/с)" % [int(mana), int(max_mana), mana_regen + bonus_mp]
	fountain_label_ui.visible = on_fountain
	
	if elixir_timer > 0.0:
		elixir_label_ui.visible = true
		elixir_label_ui.text = "🔥 Еліксир люті: %.1f с" % elixir_timer
	else:
		elixir_label_ui.visible = false
