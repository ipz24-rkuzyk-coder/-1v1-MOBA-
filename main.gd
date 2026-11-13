extends Node2D

const CREEP_SCENE = preload("res://creep.tscn")
const PLAYER_SCENE = preload("res://player.tscn")
const ENEMY_HERO_SCRIPT = preload("res://enemy_hero.gd")

var blue_throne_pos: Vector2 = Vector2(135.0, 324.0)
var red_throne_pos: Vector2 = Vector2(1045.0, 324.0)

var match_time: float = 0.0
var is_match_over: bool = false
var wave_timer: float = 13.5

var bg_layer: ArenaBackground
var vfx_layer: CombatVfxLayer
var ui_layer: CanvasLayer
var start_overlay: ColorRect
var end_overlay: ColorRect
var end_selected_diff: String = "norm"
var diff_buttons_end: Dictionary = {}

func _ready() -> void:
	if get_tree().get_nodes_in_group("main").size() > 0:
		set_physics_process(false)
		return
	add_to_group("main")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	for t in find_children("*", "Timer", true, false):
		if t is Timer and not (t.get_parent() and t.get_parent().is_in_group("structures")):
			t.stop()
			
	_resolve_throne_positions()
	
	bg_layer = ArenaBackground.new()
	bg_layer.blue_fountain = blue_throne_pos
	bg_layer.red_fountain = red_throne_pos
	bg_layer.z_index = -10
	add_child(bg_layer)
	
	vfx_layer = CombatVfxLayer.new()
	vfx_layer.z_index = 25
	add_child(vfx_layer)
	
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)
	
	var saved_diff: String = str(Engine.get_meta("bot_difficulty", "norm"))
	end_selected_diff = saved_diff
	
	if not Engine.has_meta("skip_start_menu"):
		_build_start_menu()
		get_tree().paused = true
	else:
		Engine.remove_meta("skip_start_menu")
		
	call_deferred("_ensure_bot_and_difficulty")

func _ensure_bot_and_difficulty() -> void:
	_resolve_throne_positions()
	if is_instance_valid(bg_layer):
		bg_layer.blue_fountain = blue_throne_pos
		bg_layer.red_fountain = red_throne_pos
		bg_layer.queue_redraw()
		
	var has_bot: bool = false
	for h in get_tree().get_nodes_in_group("heroes"):
		if is_instance_valid(h) and int(h.get("direction")) == -1:
			has_bot = true
			break
	if not has_bot:
		var bot := PLAYER_SCENE.instantiate()
		bot.name = "EnemyHero"
		bot.set_script(ENEMY_HERO_SCRIPT)
		add_child(bot)
	for h in get_tree().get_nodes_in_group("heroes"):
		if is_instance_valid(h) and h.has_method("sync_throne_positions"):
			h.sync_throne_positions(blue_throne_pos, red_throne_pos)
	_apply_bot_difficulty(end_selected_diff)

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

func _physics_process(delta: float) -> void:
	if is_match_over:
		return
		
	match_time += delta
	var player: Node2D = _get_player()
	if is_instance_valid(player) and player.has_method("set_match_time"):
		player.set_match_time(match_time)
		
	wave_timer += delta
	if wave_timer >= 15.0:
		wave_timer = 0.0
		_spawn_wave()

func _spawn_wave() -> void:
	_resolve_throne_positions()
	var y_offsets: Array[float] = [-16.0, 0.0, 16.0]
	for i in range(3):
		var offset_x: float = float(i) * 32.0
		var offset_y: float = y_offsets[i]
		
		var blue_creep := CREEP_SCENE.instantiate()
		blue_creep.direction = 1
		add_child(blue_creep)
		blue_creep.global_position = Vector2(blue_throne_pos.x + 65.0 + offset_x, 324.0 + offset_y)
		
		var red_creep := CREEP_SCENE.instantiate()
		red_creep.direction = -1
		add_child(red_creep)
		red_creep.global_position = Vector2(red_throne_pos.x - 65.0 - offset_x, 324.0 + offset_y)

func spawn_hit_effect(pos: Vector2, col: Color, radius: float = 24.0, particle_count: int = 8) -> void:
	if is_instance_valid(vfx_layer):
		vfx_layer.add_burst(pos, col, radius, particle_count)

func end_match(winner_team: int) -> void:
	if is_match_over:
		return
	is_match_over = true
	
	var loser_pos: Vector2 = red_throne_pos if winner_team == 1 else blue_throne_pos
	var boom_col: Color = Color("#63b3ed") if winner_team == 1 else Color("#fc8181")
	spawn_hit_effect(loser_pos, boom_col, 150.0, 32)
	spawn_hit_effect(loser_pos + Vector2(28, -22), Color("#ffd700"), 110.0, 20)
	
	Engine.time_scale = 0.35
	await get_tree().create_timer(0.55, true, false, true).timeout
	Engine.time_scale = 1.0
	
	_build_end_screen(winner_team)
	get_tree().paused = true

func _apply_bot_difficulty(diff: String) -> void:
	Engine.set_meta("bot_difficulty", diff)
	for h in get_tree().get_nodes_in_group("heroes"):
		if is_instance_valid(h) and h.has_method("set_difficulty"):
			h.set_difficulty(diff)

func _get_player() -> Node2D:
	for h in get_tree().get_nodes_in_group("heroes"):
		if is_instance_valid(h) and h.get("direction") == 1:
			return h
	return null

func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	var mins: int = int(total / 60.0)
	var secs: int = total % 60
	return "%02d:%02d" % [mins, secs]

func _difficulty_title(diff: String) -> String:
	if diff == "easy":
		return "Легкий"
	elif diff == "hard":
		return "Хард"
	return "Нормальний"

func _build_start_menu() -> void:
	start_overlay = ColorRect.new()
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.color = Color(0.03, 0.05, 0.09, 0.84)
	ui_layer.add_child(start_overlay)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 360)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.14, 0.98)
	sb.border_color = Color("#4fd1c5")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	
	var title := Label.new()
	title.text = "MINI-MOBA 1v1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffd700"))
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)
	
	var sub := Label.new()
	sub.text = "Оберіть рівень складності супротивника:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color("#cbd5e0"))
	sub.add_theme_font_size_override("font_size", 15)
	vbox.add_child(sub)
	
	var modes := [
		{"id": "easy", "title": "ЛЕГКИЙ — Розминка", "desc": "Повільніший, не ухиляється від скілів, рано відступає на базу", "col": Color("#38a169")},
		{"id": "norm", "title": "НОРМАЛЬНИЙ — Стандарт", "desc": "Комбить Q/E/R і тримає позицію, але стріляє без випередження", "col": Color("#dd6b20")},
		{"id": "hard", "title": "ХАРД — Повний інтелект", "desc": "Стріляє на випередження, ухиляється блінком від Q і жорстко пушить", "col": Color("#e53e3e")}
	]
	
	for m in modes:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 62)
		btn.text = "%s\n%s" % [m["title"], m["desc"]]
		btn.focus_mode = Control.FOCUS_NONE
		var b_sb := StyleBoxFlat.new()
		b_sb.bg_color = Color(0.11, 0.15, 0.22, 0.95)
		b_sb.border_color = m["col"]
		b_sb.set_border_width_all(2)
		b_sb.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", b_sb)
		btn.pressed.connect(_on_start_difficulty_chosen.bind(m["id"]))
		vbox.add_child(btn)

func _on_start_difficulty_chosen(diff: String) -> void:
	end_selected_diff = diff
	_apply_bot_difficulty(diff)
	if is_instance_valid(start_overlay):
		start_overlay.queue_free()
	get_tree().paused = false

func _build_end_screen(winner_team: int) -> void:
	end_overlay = ColorRect.new()
	end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.color = Color(0.03, 0.05, 0.09, 0.86)
	ui_layer.add_child(end_overlay)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 410)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.14, 0.98)
	sb.border_color = Color("#ffd700") if winner_team == 1 else Color("#fc8181")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	var header := Label.new()
	header.text = "ПЕРЕМОГА!" if winner_team == 1 else "ПОРАЗКА"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color("#ffd700") if winner_team == 1 else Color("#fc8181"))
	header.add_theme_font_size_override("font_size", 32)
	vbox.add_child(header)
	
	var sub := Label.new()
	sub.text = "Ворожий Трон зруйновано!" if winner_team == 1 else "Ваш Трон зруйновано!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color("#cbd5e0"))
	sub.add_theme_font_size_override("font_size", 15)
	vbox.add_child(sub)
	
	vbox.add_child(HSeparator.new())
	
	var player: Node2D = _get_player()
	var p_kills: int = int(player.get("player_kills")) if is_instance_valid(player) else 0
	var b_kills: int = int(player.get("bot_kills")) if is_instance_valid(player) else 0
	var p_gold: int = int(player.get("gold")) if is_instance_valid(player) else 0
	var inv_size: int = player.inventory.size() if is_instance_valid(player) else 0
	var t2_count: int = 0
	if is_instance_valid(player):
		for item in player.inventory:
			if int(item["tier"]) == 2:
				t2_count += 1
				
	var stats_lines := [
		"Тривалість матчу:   %s" % _format_time(match_time),
		"Складність бота:   %s" % _difficulty_title(end_selected_diff),
		"Рахунок вбивств (Ви : Бот):   %d  :  %d" % [p_kills, b_kills],
		"Зібрані предмети:   %d / 6  (легендарних T2: %d)" % [inv_size, t2_count],
		"Залишок золота:   %d g" % p_gold
	]
	
	for line in stats_lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 15)
		vbox.add_child(lbl)
		
	vbox.add_child(HSeparator.new())
	
	var mode_lbl := Label.new()
	mode_lbl.text = "Складність на наступний бій:"
	mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_lbl.add_theme_color_override("font_color", Color("#a0aec0"))
	mode_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(mode_lbl)
	
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 10)
	vbox.add_child(diff_row)
	
	diff_buttons_end.clear()
	for d_info in [{"id": "easy", "label": "Легко"}, {"id": "norm", "label": "Норм"}, {"id": "hard", "label": "Хард"}]:
		var d_btn := Button.new()
		d_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_btn.custom_minimum_size = Vector2(0, 34)
		d_btn.text = d_info["label"]
		d_btn.focus_mode = Control.FOCUS_NONE
		d_btn.pressed.connect(_select_end_difficulty.bind(d_info["id"]))
		diff_row.add_child(d_btn)
		diff_buttons_end[d_info["id"]] = d_btn
	_refresh_end_diff_buttons()
	
	var replay_btn := Button.new()
	replay_btn.custom_minimum_size = Vector2(0, 44)
	replay_btn.text = "ЗІГРАТИ ЩЕ РАЗ"
	replay_btn.focus_mode = Control.FOCUS_NONE
	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color("#2b6cb0")
	r_sb.border_color = Color("#63b3ed")
	r_sb.set_border_width_all(2)
	r_sb.set_corner_radius_all(8)
	replay_btn.add_theme_stylebox_override("normal", r_sb)
	replay_btn.pressed.connect(_on_replay_pressed)
	vbox.add_child(replay_btn)

func _select_end_difficulty(diff: String) -> void:
	end_selected_diff = diff
	Engine.set_meta("bot_difficulty", diff)
	_refresh_end_diff_buttons()

func _refresh_end_diff_buttons() -> void:
	for k in diff_buttons_end.keys():
		var btn: Button = diff_buttons_end[k]
		var active: bool = (k == end_selected_diff)
		var b_sb := StyleBoxFlat.new()
		b_sb.bg_color = Color("#2c5282") if active else Color(0.12, 0.15, 0.22)
		b_sb.border_color = Color("#ffd700") if active else Color(0.3, 0.38, 0.5)
		b_sb.set_border_width_all(2 if active else 1)
		b_sb.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", b_sb)

func _on_replay_pressed() -> void:
	Engine.set_meta("bot_difficulty", end_selected_diff)
	Engine.set_meta("skip_start_menu", true)
	get_tree().paused = false
	get_tree().reload_current_scene()


class ArenaBackground extends Node2D:
	var blue_fountain: Vector2 = Vector2(135.0, 324.0)
	var red_fountain: Vector2 = Vector2(1045.0, 324.0)
	
	func _ready() -> void:
		queue_redraw()
		
	func _draw() -> void:
		var vp: Vector2 = get_viewport_rect().size
		if vp == Vector2.ZERO:
			vp = Vector2(1152, 648)
			
		var total_w: float = maxf(vp.x, red_fountain.x + 110.0)
		draw_rect(Rect2(Vector2.ZERO, Vector2(total_w, vp.y)), Color("#0b1120"), true)
		
		for x in range(64, int(total_w), 64):
			draw_line(Vector2(x, 0), Vector2(x, vp.y), Color(1, 1, 1, 0.025), 1.0)
		for y in range(64, int(vp.y), 64):
			draw_line(Vector2(0, y), Vector2(total_w, y), Color(1, 1, 1, 0.025), 1.0)
			
		var lane_left: float = minf(70.0, blue_fountain.x - 65.0)
		var lane_right: float = maxf(vp.x - 70.0, red_fountain.x + 65.0)
		var lane_rect := Rect2(lane_left, 234, lane_right - lane_left, 180.0)
		draw_rect(lane_rect, Color("#162033"), true)
		draw_rect(lane_rect, Color("#2d3748"), false, 2.0)
		
		for x in range(int(lane_left) + 40, int(lane_right) - 40, 44):
			draw_line(Vector2(x, 324), Vector2(x + 22, 324), Color(1, 1, 1, 0.08), 2.0)
			
		var mid_x: float = (blue_fountain.x + red_fountain.x) * 0.5
		draw_line(Vector2(mid_x, 40), Vector2(mid_x, vp.y - 40.0), Color(0.22, 0.70, 0.67, 0.18), 4.0)
		draw_circle(Vector2(mid_x, 324), 54.0, Color(0.22, 0.70, 0.67, 0.07))
		draw_arc(Vector2(mid_x, 324), 54.0, 0.0, TAU, 48, Color(0.22, 0.70, 0.67, 0.25), 2.0)
		
		draw_circle(blue_fountain, 200.0, Color(0.20, 0.55, 0.95, 0.09))
		draw_arc(blue_fountain, 200.0, 0.0, TAU, 64, Color(0.38, 0.75, 0.98, 0.32), 2.0)
		draw_arc(blue_fountain, 95.0, 0.0, TAU, 48, Color(0.38, 0.75, 0.98, 0.18), 1.5)
		
		draw_circle(red_fountain, 200.0, Color(0.95, 0.24, 0.24, 0.09))
		draw_arc(red_fountain, 200.0, 0.0, TAU, 64, Color(0.98, 0.45, 0.45, 0.32), 2.0)
		draw_arc(red_fountain, 95.0, 0.0, TAU, 48, Color(0.98, 0.45, 0.45, 0.18), 1.5)


class CombatVfxLayer extends Node2D:
	var bursts: Array[Dictionary] = []
	
	func add_burst(pos: Vector2, col: Color, max_radius: float, count: int) -> void:
		var pts: Array[Dictionary] = []
		for i in range(count):
			var ang: float = randf() * TAU
			var spd: float = randf_range(0.45, 1.15) * max_radius * 2.2
			pts.append({"dir": Vector2.from_angle(ang), "spd": spd, "size": randf_range(2.5, 5.5)})
		bursts.append({
			"pos": pos,
			"col": col,
			"radius": max_radius,
			"time": 0.36,
			"max_time": 0.36,
			"pts": pts
		})
		queue_redraw()
		
	func _physics_process(delta: float) -> void:
		if bursts.is_empty():
			return
		for i in range(bursts.size() - 1, -1, -1):
			bursts[i]["time"] -= delta
			if float(bursts[i]["time"]) <= 0.0:
				bursts.remove_at(i)
		queue_redraw()
		
	func _draw() -> void:
		for b in bursts:
			var t: float = float(b["time"]) / float(b["max_time"])
			var progress: float = 1.0 - t
			var pos: Vector2 = b["pos"]
			var col: Color = b["col"]
			var rad: float = float(b["radius"]) * (0.35 + progress * 0.65)
			
			draw_circle(pos, rad * 0.55, Color(col.r, col.g, col.b, t * 0.28))
			draw_arc(pos, rad, 0.0, TAU, 36, Color(col.r, col.g, col.b, t * 0.85), 2.5)
			
			var elapsed: float = float(b["max_time"]) - float(b["time"])
			for p in b["pts"]:
				var p_pos: Vector2 = pos + p["dir"] * float(p["spd"]) * elapsed
				draw_circle(p_pos, float(p["size"]) * t, Color(col.r, col.g, col.b, t))
