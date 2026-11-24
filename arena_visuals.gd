
extends Node

# Mini-MOBA 1v1 — футуристична арена
# Autoload: ArenaVisuals
# Не змінює бойову логіку, колізії, HUD або камеру.

const CHECK_INTERVAL: float = 0.35
var check_timer: float = 0.0
var current_main: Node2D = null
var arena_art: ArenaArt = null


class ArenaArt:
	extends Node2D

	const MAP_HEIGHT: float = 648.0
	const FLOOR_LEFT: float = 80.0
	const FLOOR_RIGHT_MARGIN: float = 80.0
	const FLOOR_TOP: float = 144.0
	const FLOOR_BOTTOM: float = 504.0
	const LANE_CENTER: float = 324.0

	var blue_throne: Vector2 = Vector2(160.0, 324.0)
	var red_throne: Vector2 = Vector2(2640.0, 324.0)
	var animation_time: float = 0.0
	var redraw_timer: float = 0.0

	func _ready() -> void:
		name = "ArenaArt"
		z_as_relative = false
		z_index = -5
		process_mode = Node.PROCESS_MODE_PAUSABLE
		queue_redraw()

	func _process(delta: float) -> void:
		animation_time += delta
		redraw_timer += delta
		if redraw_timer >= 0.15:
			redraw_timer = 0.0
			queue_redraw()

	func _draw() -> void:
		var world_right: float = maxf(2800.0, red_throne.x + 160.0)
		var middle_x: float = (blue_throne.x + red_throne.x) * 0.5

		# Суцільне покриття замість старих сірих ColorRect.
		draw_rect(Rect2(0.0, 0.0, world_right, MAP_HEIGHT), Color("#0a101c"))
		_draw_outer_terrain(world_right)
		_draw_road(world_right)
		_draw_middle_canal(middle_x)
		_draw_base(blue_throne, true)
		_draw_base(red_throne, false)
		_draw_structure_pads()

	func _draw_outer_terrain(world_right: float) -> void:
		# Верхня і нижня технічні смуги.
		draw_rect(Rect2(0.0, 0.0, world_right, 132.0), Color("#0c1625"))
		draw_rect(Rect2(0.0, 516.0, world_right, 132.0), Color("#0c1625"))

		# Сітка технічних панелей.
		for x in range(0, int(world_right), 88):
			var fx: float = float(x)
			var panel: Color = Color("#122033") if int(x / 88) % 2 == 0 else Color("#101b2b")
			draw_rect(Rect2(fx + 3.0, 12.0, 80.0, 94.0), panel)
			draw_rect(Rect2(fx + 3.0, 542.0, 80.0, 94.0), panel)
			draw_line(Vector2(fx + 14.0, 45.0), Vector2(fx + 66.0, 45.0), Color("#24374b"), 1.0)
			draw_line(Vector2(fx + 14.0, 603.0), Vector2(fx + 66.0, 603.0), Color("#24374b"), 1.0)
			if int(x / 88) % 3 == 0:
				draw_rect(Rect2(fx + 31.0, 63.0, 24.0, 5.0), Color("#243f54"))
				draw_rect(Rect2(fx + 31.0, 581.0, 24.0, 5.0), Color("#243f54"))

		# Дві магістралі вздовж арени.
		for y in [119.0, 527.0]:
			draw_line(Vector2(0.0, y), Vector2(world_right, y), Color("#263748"), 6.0)
			draw_line(Vector2(0.0, y), Vector2(world_right, y), Color("#42647b"), 1.0)

	func _draw_road(world_right: float) -> void:
		var road_width: float = world_right - FLOOR_LEFT - FLOOR_RIGHT_MARGIN
		draw_rect(Rect2(FLOOR_LEFT, FLOOR_TOP, road_width, FLOOR_BOTTOM - FLOOR_TOP), Color("#19283b"))

		# Велика доріжка складається з броньованих плит.
		for x in range(80, int(world_right - 80.0), 120):
			var fx: float = float(x)
			var color: Color = Color("#223246") if int(x / 120) % 2 == 0 else Color("#1d2d40")
			draw_rect(Rect2(fx + 3.0, 150.0, 113.0, 348.0), color)
			draw_line(Vector2(fx + 7.0, 192.0), Vector2(fx + 108.0, 192.0), Color("#35485d"), 1.0)
			draw_line(Vector2(fx + 7.0, 458.0), Vector2(fx + 108.0, 458.0), Color("#35485d"), 1.0)
			for y in [169.0, 477.0]:
				draw_circle(Vector2(fx + 12.0, y), 2.0, Color("#556779"))
				draw_circle(Vector2(fx + 106.0, y), 2.0, Color("#556779"))

		# Центральна смуга для переміщення юнітів.
		draw_rect(Rect2(FLOOR_LEFT, 246.0, road_width, 156.0), Color("#27384c"))
		draw_line(Vector2(FLOOR_LEFT, 246.0), Vector2(world_right - 80.0, 246.0), Color("#526a7b"), 3.0)
		draw_line(Vector2(FLOOR_LEFT, 402.0), Vector2(world_right - 80.0, 402.0), Color("#526a7b"), 3.0)

		# Дорожня розмітка.
		for x in range(106, int(world_right - 80.0), 95):
			var fx: float = float(x)
			draw_line(Vector2(fx, LANE_CENTER), Vector2(fx + 45.0, LANE_CENTER), Color(0.65, 0.78, 0.88, 0.20), 2.0)
			# Декоративні шеврони на плечах доріжки.
			if int(x / 95) % 3 == 0:
				draw_line(Vector2(fx, 221.0), Vector2(fx + 12.0, 228.0), Color("#466077"), 2.0)
				draw_line(Vector2(fx, 427.0), Vector2(fx + 12.0, 420.0), Color("#466077"), 2.0)

		# Кольорові магістралі команд по краях доріжки.
		var middle: float = (blue_throne.x + red_throne.x) * 0.5
		draw_line(Vector2(FLOOR_LEFT, 145.0), Vector2(middle - 80.0, 145.0), Color(0.17, 0.57, 0.91, 0.65), 4.0)
		draw_line(Vector2(middle + 80.0, 145.0), Vector2(world_right - 80.0, 145.0), Color(0.88, 0.27, 0.33, 0.65), 4.0)
		draw_line(Vector2(FLOOR_LEFT, 503.0), Vector2(middle - 80.0, 503.0), Color(0.17, 0.57, 0.91, 0.65), 4.0)
		draw_line(Vector2(middle + 80.0, 503.0), Vector2(world_right - 80.0, 503.0), Color(0.88, 0.27, 0.33, 0.65), 4.0)

	func _draw_middle_canal(middle_x: float) -> void:
		# Вертикальний енергоканал у центрі карти.
		draw_rect(Rect2(middle_x - 70.0, 144.0, 140.0, 360.0), Color("#0d3048"))
		draw_line(Vector2(middle_x - 70.0, 144.0), Vector2(middle_x - 70.0, 504.0), Color("#3c8aac"), 3.0)
		draw_line(Vector2(middle_x + 70.0, 144.0), Vector2(middle_x + 70.0, 504.0), Color("#3c8aac"), 3.0)

		# Рухомі течії енергії в каналі.
		for y in range(155, 499, 30):
			var fy: float = float(y)
			var shift: float = sin(animation_time * 1.3 + fy * 0.04) * 12.0
			draw_line(Vector2(middle_x - 42.0 + shift, fy), Vector2(middle_x + 42.0 + shift, fy), Color(0.27, 0.75, 0.93, 0.30), 2.0)

		# Міст через канал. Це тільки зображення, без колізій.
		draw_rect(Rect2(middle_x - 81.0, 246.0, 162.0, 156.0), Color("#30475b"))
		for x in range(-76, 77, 25):
			var fx: float = middle_x + float(x)
			draw_line(Vector2(fx, 250.0), Vector2(fx, 398.0), Color("#526879"), 1.0)
		draw_line(Vector2(middle_x - 79.0, 248.0), Vector2(middle_x + 79.0, 248.0), Color("#63c6e5"), 3.0)
		draw_line(Vector2(middle_x - 79.0, 400.0), Vector2(middle_x + 79.0, 400.0), Color("#63c6e5"), 3.0)
		draw_arc(Vector2(middle_x, 324.0), 43.0, 0.0, TAU, 48, Color(0.43, 0.88, 1.0, 0.40), 2.0, true)
		draw_circle(Vector2(middle_x, 324.0), 7.0, Color("#50b8d7"))

	func _draw_base(pos: Vector2, is_blue: bool) -> void:
		var col: Color = Color("#42b8f4") if is_blue else Color("#ff6a70")
		var dim: Color = Color(col.r, col.g, col.b, 0.10)
		var medium: Color = Color(col.r, col.g, col.b, 0.35)

		# Фонтан і кругла посадкова платформа.
		draw_circle(pos, 103.0, dim)
		draw_arc(pos, 114.0, 0.0, TAU, 64, medium, 3.0, true)
		draw_arc(pos, 82.0, 0.0, TAU, 64, Color(col.r, col.g, col.b, 0.21), 2.0, true)
		for k in range(8):
			var angle: float = TAU * float(k) / 8.0
			var p1: Vector2 = pos + Vector2.from_angle(angle) * 95.0
			var p2: Vector2 = pos + Vector2.from_angle(angle) * 110.0
			draw_line(p1, p2, medium, 3.0)

		# Висвітлення реальної зони лікування: радіус 200 px.
		draw_arc(pos, 199.0, 0.0, TAU, 80, Color(col.r, col.g, col.b, 0.16), 1.4, true)
		var marker_x: float = pos.x + (70.0 if is_blue else -70.0)
		_draw_symbol(Vector2(marker_x, 186.0), col)
		_draw_symbol(Vector2(marker_x, 461.0), col)

	func _draw_symbol(pos: Vector2, color: Color) -> void:
		draw_line(pos + Vector2(-7.0, 0.0), pos + Vector2(7.0, 0.0), Color(color.r, color.g, color.b, 0.68), 2.0)
		draw_line(pos + Vector2(0.0, -7.0), pos + Vector2(0.0, 7.0), Color(color.r, color.g, color.b, 0.68), 2.0)

	func _draw_structure_pads() -> void:
		# Декоративні фундаменти під живими спорудами.
		for node in get_tree().get_nodes_in_group("structures"):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			if node.is_queued_for_deletion():
				continue
			var hp_value = node.get("hp")
			if hp_value == null or float(hp_value) <= 0.0:
				continue
			var pos: Vector2 = node.global_position
			var col: Color = Color("#51b8f7") if int(node.get("direction")) == 1 else Color("#ef6875")
			var r: float = 57.0 if node.get("is_throne") == true else 42.0
			draw_circle(pos, r, Color(col.r, col.g, col.b, 0.06))
			draw_arc(pos, r, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.25), 2.0, true)


func _ready() -> void:
	# Підключаємо декорації навіть коли стартове меню на паузі.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	check_timer -= delta
	if check_timer > 0.0:
		return
	check_timer = CHECK_INTERVAL

	var main: Node2D = get_tree().get_first_node_in_group("main") as Node2D
	if not is_instance_valid(main):
		current_main = null
		arena_art = null
		return

	if is_instance_valid(current_main) and main == current_main and is_instance_valid(arena_art):
		return

	current_main = main
	_attach_arena(main)


func _attach_arena(main: Node2D) -> void:
	# Приховуємо тільки три старі елементи фону сцени.
	for node_path in ["Background", "LaneFloor", "River"]:
		var old_item: CanvasItem = main.get_node_or_null(node_path) as CanvasItem
		if is_instance_valid(old_item):
			old_item.visible = false

	# Маленький білий квадрат — застарілий шаблон EndScreen.
	# Справжній фінальний екран main.gd створює окремо.
	var old_end: Control = main.get_node_or_null("CanvasLayer/EndScreen") as Control
	if is_instance_valid(old_end):
		old_end.visible = false

	arena_art = ArenaArt.new()
	arena_art.blue_throne = main.get("blue_throne_pos")
	arena_art.red_throne = main.get("red_throne_pos")
	main.add_child(arena_art)
	arena_art.queue_redraw()
	print("ArenaVisuals: нову арену підключено")
