
extends Node

# Mini-MOBA 1v1 — система мінікарти
# Відображає героїв, кріпів, катапульти,
# будівлі, руни та поточну область камери.


class MinimapView:
	extends Control

	const MAP_MARGIN: float = 14.0
	const TRACK_TOP: float = 31.0
	const TRACK_HEIGHT: float = 34.0

	const LANE_MIN_Y: float = 248.0
	const LANE_MAX_Y: float = 400.0

	var world_left: float = 160.0
	var world_right: float = 2640.0


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	func _map_x(world_x: float) -> float:
		var world_width: float = maxf(
			world_right - world_left, 1.0
		)

		var normalized: float = clampf(
			(world_x - world_left) / world_width,
			0.0,
			1.0
		)

		return lerpf(
			MAP_MARGIN,
			size.x - MAP_MARGIN,
			normalized
		)


	func _map_y(world_y: float) -> float:
		var normalized: float = clampf(
			(world_y - LANE_MIN_Y) /
			(LANE_MAX_Y - LANE_MIN_Y),
			0.0,
			1.0
		)

		return TRACK_TOP + 5.0 + normalized * (
			TRACK_HEIGHT - 10.0
		)


	func _draw() -> void:
		var main: Node2D = (
			get_tree().get_first_node_in_group("main")
			as Node2D
		)

		if not is_instance_valid(main):
			return

		var blue_pos: Vector2 = main.get(
			"blue_throne_pos"
		)

		var red_pos: Vector2 = main.get(
			"red_throne_pos"
		)

		world_left = blue_pos.x
		world_right = red_pos.x

		if world_right <= world_left:
			return

		# Фон мінікарти
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(0.04, 0.07, 0.12, 0.94)
		)

		# Зовнішня рамка
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color("#526987"),
			false,
			2.0
		)

		# Заголовок
		draw_string(
			ThemeDB.fallback_font,
			Vector2(12.0, 18.0),
			"MINIMAP",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color("#dce6f5")
		)

		# Доріжка
		draw_rect(
			Rect2(
				MAP_MARGIN,
				TRACK_TOP,
				size.x - MAP_MARGIN * 2.0,
				TRACK_HEIGHT
			),
			Color("#273548")
		)

		# Центральна річка
		var middle_x: float = _map_x(
			(world_left + world_right) * 0.5
		)

		draw_rect(
			Rect2(
				middle_x - 5.0,
				TRACK_TOP,
				10.0,
				TRACK_HEIGHT
			),
			Color("#286892")
		)

		# Центральна вісь лінії
		draw_line(
			Vector2(MAP_MARGIN, TRACK_TOP + 17.0),
			Vector2(
				size.x - MAP_MARGIN,
				TRACK_TOP + 17.0
			),
			Color("#63748b"),
			1.0
		)

		_draw_camera_view()
		_draw_structures()
		_draw_creeps()
		_draw_runes()
		_draw_heroes()


	# Рамка видимої частини камери
	func _draw_camera_view() -> void:
		var camera: Camera2D = (
			get_viewport().get_camera_2d()
		)

		if not is_instance_valid(camera):
			return

		var center_x: float = (
			camera.get_screen_center_position().x
		)

		var zoom_x: float = maxf(
			camera.zoom.x, 0.01
		)

		var visible_width: float = (
			get_viewport_rect().size.x / zoom_x
		)

		var left_x: float = _map_x(
			center_x - visible_width * 0.5
		)

		var right_x: float = _map_x(
			center_x + visible_width * 0.5
		)

		draw_rect(
			Rect2(
				left_x,
				TRACK_TOP - 3.0,
				maxf(right_x - left_x, 1.0),
				TRACK_HEIGHT + 6.0
			),
			Color("#f8fafc"),
			false,
			1.5
		)


	# Вежі та Трони
	func _draw_structures() -> void:
		for structure in get_tree().get_nodes_in_group(
			"structures"
		):
			if not is_instance_valid(structure):
				continue

			if structure.is_queued_for_deletion():
				continue

			if float(structure.get("hp")) <= 0.0:
				continue

			var team: int = int(
				structure.get("direction")
			)

			var color: Color = (
				Color("#60a5fa")
				if team == 1
				else Color("#fb7185")
			)

			var is_throne: bool = bool(
				structure.get("is_throne")
			)

			var marker_width: float = (
				11.0 if is_throne else 6.0
			)

			var marker_height: float = (
				29.0 if is_throne else 18.0
			)

			var x: float = _map_x(
				structure.global_position.x
			)

			var y: float = _map_y(
				structure.global_position.y
			)

			draw_rect(
				Rect2(
					x - marker_width * 0.5,
					y - marker_height * 0.5,
					marker_width,
					marker_height
				),
				color
			)


	# Звичайні кріпи та катапульти
	func _draw_creeps() -> void:
		for creep in get_tree().get_nodes_in_group(
			"creeps"
		):
			if not is_instance_valid(creep):
				continue

			if creep.is_queued_for_deletion():
				continue

			if float(creep.get("hp")) <= 0.0:
				continue

			var team: int = int(
				creep.get("direction")
			)

			var color: Color = (
				Color("#64b5f6")
				if team == 1
				else Color("#f87171")
			)

			var pos: Vector2 = Vector2(
				_map_x(creep.global_position.x),
				_map_y(creep.global_position.y)
			)

			var is_catapult: bool = (
				creep.is_in_group("catapults")
			)

			if is_catapult:
				# Великий квадрат катапульти
				draw_rect(
					Rect2(
						pos - Vector2(4.0, 4.0),
						Vector2(8.0, 8.0)
					),
					color
				)

				draw_rect(
					Rect2(
						pos - Vector2(4.0, 4.0),
						Vector2(8.0, 8.0)
					),
					Color.WHITE,
					false,
					1.0
				)
			else:
				# Маленька точка кріпа
				draw_circle(
					pos,
					2.4,
					color
				)


	# Активні руни
	func _draw_runes() -> void:
		for rune in get_tree().get_nodes_in_group(
			"runes"
		):
			if not is_instance_valid(rune):
				continue

			if rune.is_queued_for_deletion():
				continue

			var kind: int = int(rune.get("kind"))

			var color: Color = Color("#f6e05e")

			match kind:
				0:
					color = Color("#f6e05e")
				1:
					color = Color("#fc8181")
				2:
					color = Color("#68d391")

			var pos: Vector2 = Vector2(
				_map_x(rune.global_position.x),
				_map_y(rune.global_position.y)
			)

			draw_circle(
				pos,
				6.0,
				color
			)

			draw_circle(
				pos,
				2.5,
				Color.WHITE
			)


	# Герой гравця та ШІ-бот
	func _draw_heroes() -> void:
		for hero in get_tree().get_nodes_in_group(
			"heroes"
		):
			if not is_instance_valid(hero):
				continue

			if hero.get("is_dead") == true:
				continue

			var team: int = int(
				hero.get("direction")
			)

			var color: Color = (
				Color("#3b82f6")
				if team == 1
				else Color("#ef4444")
			)

			var pos: Vector2 = Vector2(
				_map_x(hero.global_position.x),
				_map_y(hero.global_position.y)
			)

			# Контур героя
			draw_circle(
				pos,
				7.0,
				Color.WHITE
			)

			# Колір команди
			draw_circle(
				pos,
				5.0,
				color
			)


# Головний контролер мінікарти

const UPDATE_INTERVAL: float = 0.12

var map_canvas: CanvasLayer
var minimap: MinimapView
var refresh_timer: float = 0.0


func _ready() -> void:
	# Працює також під час меню та паузи
	process_mode = Node.PROCESS_MODE_ALWAYS

	map_canvas = CanvasLayer.new()
	map_canvas.name = "MinimapLayer"
	map_canvas.layer = 12

	add_child(map_canvas)

	# Контейнер мінікарти
	minimap = MinimapView.new()
	minimap.name = "Minimap"

	map_canvas.add_child(minimap)

	# Верхній правий кут
	minimap.set_anchors_preset(
		Control.PRESET_TOP_RIGHT
	)

	minimap.offset_left = -340.0
	minimap.offset_top = 16.0
	minimap.offset_right = -16.0
	minimap.offset_bottom = 96.0

	minimap.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	minimap.visible = false


func _process(delta: float) -> void:
	var main: Node2D = (
		get_tree().get_first_node_in_group("main")
		as Node2D
	)

	if not is_instance_valid(main):
		minimap.visible = false
		return

	# Ховаємо мінікарту в меню та після матчу
	if get_tree().paused:
		minimap.visible = false
		return

	if main.get("is_match_over") == true:
		minimap.visible = false
		return

	minimap.visible = true

	# Оновлюємо мінікарту кілька разів на секунду
	refresh_timer -= delta

	if refresh_timer <= 0.0:
		refresh_timer = UPDATE_INTERVAL
		minimap.queue_redraw()
