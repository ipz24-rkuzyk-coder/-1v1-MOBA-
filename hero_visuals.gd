
extends Node

# Mini-MOBA 1v1 — Class Hero Skins V2
# Autoload: HeroVisuals

const SCAN_TIME: float = 0.15
var scan_timer: float = 0.0


class ClassHeroSkin:
	extends Node2D

	var hero: CharacterBody2D
	var class_id: int = 0
	var aim: float = 0.0
	var walk_time: float = 0.0
	var attack_time: float = 0.0
	var q_time: float = 0.0
	var e_time: float = 0.0
	var r_time: float = 0.0

	var previous_attack: float = 0.0
	var previous_q: float = 0.0
	var previous_e: float = 0.0
	var previous_r: float = 0.0


	func _ready() -> void:
		z_index = 6

		if not is_instance_valid(hero):
			return

		previous_attack = float(hero.get("cooldown_timer"))
		previous_q = float(hero.get("q_cd"))
		previous_e = float(hero.get("e_cd"))
		previous_r = float(hero.get("r_cd"))


	func _process(delta: float) -> void:
		if not is_instance_valid(hero):
			queue_free()
			return

		visible = hero.get("is_dead") != true

		if not visible:
			return

		# Беремо саме вибраний клас
		var meta_name: String = (
			"player_hero_class"
			if int(hero.get("direction")) == 1
			else "bot_hero_class"
		)

		class_id = clampi(
			int(Engine.get_meta(meta_name, 0)),
			0,
			2
		)

		var marker: Node = hero.get_node_or_null(
			"ClassMarker"
		)

		if is_instance_valid(marker):
			class_id = int(marker.get("class_id"))

		# Напрямок до цілі
		var target_direction: Vector2 = Vector2.RIGHT

		if int(hero.get("direction")) == 1:
			target_direction = (
				hero.get_global_mouse_position()
				- hero.global_position
			)
		else:
			target_direction = Vector2.LEFT

			var nearest: float = INF

			for other in get_tree().get_nodes_in_group(
				"heroes"
			):
				if not is_instance_valid(other):
					continue

				if other == hero:
					continue

				if other.get("is_dead") == true:
					continue

				if int(other.get("direction")) == int(
					hero.get("direction")
				):
					continue

				var distance: float = (
					hero.global_position.distance_to(
						other.global_position
					)
				)

				if distance < nearest:
					nearest = distance
					target_direction = (
						other.global_position
						- hero.global_position
					)

		if target_direction.length_squared() > 1.0:
			aim = lerp_angle(
				aim,
				target_direction.angle(),
				minf(1.0, delta * 13.0)
			)

		var movement: float = clampf(
			hero.velocity.length() / 180.0,
			0.0,
			1.0
		)

		walk_time += delta * (
			2.0 + movement * 11.0
		)

		attack_time = maxf(
			0.0, attack_time - delta
		)
		q_time = maxf(0.0, q_time - delta)
		e_time = maxf(0.0, e_time - delta)
		r_time = maxf(0.0, r_time - delta)

		var attack_cd: float = float(
			hero.get("cooldown_timer")
		)
		var q_cd: float = float(hero.get("q_cd"))
		var e_cd: float = float(hero.get("e_cd"))
		var r_cd: float = float(hero.get("r_cd"))

		if attack_cd > previous_attack + 0.10:
			attack_time = (
				0.32 if class_id == 2 else 0.22
			)

		if q_cd > previous_q + 0.30:
			q_time = 0.45

		if e_cd > previous_e + 0.30:
			e_time = 0.50

		if r_cd > previous_r + 0.30:
			r_time = 0.90

		previous_attack = attack_cd
		previous_q = q_cd
		previous_e = e_cd
		previous_r = r_cd

		queue_redraw()


	func _draw() -> void:
		if not is_instance_valid(hero):
			return

		if not visible:
			return

		var blue: bool = (
			int(hero.get("direction")) == 1
		)

		var team_color: Color = (
			Color("#52cfff")
			if blue
			else Color("#ff6c72")
		)

		# Тінь під героєм
		draw_circle(
			Vector2(0, 12),
			22.0,
			Color(0.0, 0.0, 0.0, 0.27)
		)

		draw_arc(
			Vector2(0, 9),
			23.0,
			0.0,
			TAU,
			40,
			team_color,
			2.0,
			true
		)

		match class_id:
			0:
				_draw_marksman(blue)

			1:
				_draw_mage(blue)

			2:
				_draw_warrior(blue)

		_draw_skill_effects()


	# ====================================
	# СТРІЛЕЦЬ — БРОНЯ ТА ЕНЕРГОЗБРОЯ
	# ====================================

	func _draw_marksman(blue: bool) -> void:
		var armor: Color = (
			Color("#316a9a")
			if blue else Color("#913847")
		)

		var light: Color = (
			Color("#60ddff")
			if blue else Color("#ff9292")
		)

		var steel := Color("#b5c7d5")
		var step: float = sin(walk_time) * 2.2

		# Ноги
		draw_rect(
			Rect2(-12, 7 + step, 9, 13),
			steel.darkened(0.45)
		)

		draw_rect(
			Rect2(3, 7 - step, 9, 13),
			steel.darkened(0.45)
		)

		# Корпус
		draw_rect(
			Rect2(-15, -12, 30, 24),
			armor.darkened(0.4)
		)

		draw_rect(
			Rect2(-11, -9, 22, 18),
			armor
		)

		draw_rect(
			Rect2(-5, -6, 10, 11),
			light.darkened(0.25)
		)

		# Плечі
		draw_circle(
			Vector2(-17, -7), 8, steel
		)
		draw_circle(
			Vector2(17, -7), 8, steel
		)

		# Шолом
		draw_circle(
			Vector2(0, -18),
			12,
			armor.darkened(0.25)
		)

		draw_rect(
			Rect2(-10, -20, 20, 7),
			light
		)

		# Енергетична зброя
		draw_set_transform(
			Vector2(2, -2),
			aim,
			Vector2.ONE
		)

		var recoil: float = (
			attack_time * 10.0
		)

		draw_rect(
			Rect2(-7 - recoil, -5, 26, 10),
			Color("#192637")
		)

		draw_rect(
			Rect2(13 - recoil, -3, 27, 6),
			steel
		)

		draw_line(
			Vector2(10, -2),
			Vector2(39, -2),
			light,
			2.0
		)

		if attack_time > 0.0:
			var alpha: float = (
				attack_time / 0.22
			)

			draw_circle(
				Vector2(42, 0),
				10.0 * alpha,
				Color(
					light.r,
					light.g,
					light.b,
					alpha
				)
			)

		draw_set_transform(Vector2.ZERO)


	# ====================================
	# МАГ — МАНТІЯ, КАПЮШОН, ПОСОХ
	# ====================================

	func _draw_mage(blue: bool) -> void:
		var robe: Color = (
			Color("#44398e")
			if blue else Color("#7b305a")
		)

		var magic: Color = (
			Color("#a4a5ff")
			if blue else Color("#ff8cdd")
		)

		var sway: float = sin(walk_time) * 2.0

		# Довга мантія
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-11, -12),
				Vector2(11, -12),
				Vector2(18 + sway, 24),
				Vector2(-18 + sway, 24)
			]),
			robe.darkened(0.35)
		)

		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-12, -14),
				Vector2(12, -14),
				Vector2(12, 7),
				Vector2(-12, 7)
			]),
			robe
		)

		# Магічні символи на одязі
		draw_line(
			Vector2(0, -7),
			Vector2(0, 16),
			magic,
			2.0
		)

		draw_circle(
			Vector2(0, 0),
			5,
			magic
		)

		# Капюшон
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-12, -17),
				Vector2(0, -34),
				Vector2(12, -17),
				Vector2(9, -9),
				Vector2(-9, -9)
			]),
			robe.darkened(0.15)
		)

		draw_rect(
			Rect2(-8, -20, 16, 6),
			Color("#17152d")
		)

		# Очі під капюшоном
		draw_line(
			Vector2(-6, -17),
			Vector2(6, -17),
			magic,
			2.0
		)

		# Посох
		draw_set_transform(
			Vector2(0, -2),
			aim,
			Vector2.ONE
		)

		draw_line(
			Vector2(-5, 11),
			Vector2(35, -9),
			Color("#80664b"),
			5.0
		)

		draw_circle(
			Vector2(36, -10),
			10,
			robe
		)

		var pulse: float = (
			4.0 + sin(walk_time * 2.0) * 1.0
		)

		draw_circle(
			Vector2(36, -10),
			pulse + attack_time * 20.0,
			magic
		)

		# Спалах магічної атаки
		if attack_time > 0.0:
			var alpha: float = (
				attack_time / 0.22
			)

			draw_arc(
				Vector2(36, -10),
				12.0 + (1.0 - alpha) * 12.0,
				0.0,
				TAU,
				32,
				Color(
					magic.r,
					magic.g,
					magic.b,
					alpha
				),
				3.0,
				true
			)

		draw_set_transform(Vector2.ZERO)


	# ====================================
	# ВОЇН — МЕЧ ТА ЗАХИСНИЙ ЩИТ
	# ====================================

	func _draw_warrior(blue: bool) -> void:
		var armor: Color = (
			Color("#416782")
			if blue else Color("#86414a")
		)

		var steel := Color("#c8d6df")
		var gold := Color("#f3c66b")
		var step: float = sin(walk_time) * 1.8

		# Важкі броньовані ноги
		draw_rect(
			Rect2(-14, 7 + step, 11, 16),
			Color("#293443")
		)

		draw_rect(
			Rect2(3, 7 - step, 11, 16),
			Color("#293443")
		)

		# Масивний панцир
		draw_rect(
			Rect2(-18, -13, 36, 27),
			armor.darkened(0.35)
		)

		draw_rect(
			Rect2(-13, -10, 26, 21),
			armor
		)

		draw_rect(
			Rect2(-5, -7, 10, 15),
			steel.darkened(0.25)
		)

		# Наплічники
		draw_circle(
			Vector2(-19, -8), 10, steel
		)

		draw_circle(
			Vector2(19, -8), 10, steel
		)

		# Лицарський шолом
		draw_circle(
			Vector2(0, -21),
			13,
			steel.darkened(0.3)
		)

		draw_rect(
			Rect2(-9, -24, 18, 9),
			steel
		)

		draw_line(
			Vector2(-7, -19),
			Vector2(7, -19),
			gold,
			3.0
		)

		# Гребінь шолома
		draw_line(
			Vector2(0, -34),
			Vector2(0, -41),
			gold,
			4.0
		)

		# Щит
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-27, -6),
				Vector2(-14, -9),
				Vector2(-10, 10),
				Vector2(-20, 20),
				Vector2(-29, 9)
			]),
			steel.darkened(0.2)
		)

		draw_line(
			Vector2(-20, -5),
			Vector2(-20, 12),
			gold,
			2.0
		)

		# Анімація замаху мечем
		var swing: float = 0.0

		if attack_time > 0.0:
			var progress: float = (
				1.0 - attack_time / 0.32
			)

			swing = lerpf(
				-1.35,
				1.20,
				progress
			)

		draw_set_transform(
			Vector2(5, -2),
			aim + swing,
			Vector2.ONE
		)

		# Руків'я меча
		draw_line(
			Vector2.ZERO,
			Vector2(15, 0),
			Color("#79543b"),
			6.0
		)

		# Гарда
		draw_line(
			Vector2(13, -9),
			Vector2(13, 9),
			gold,
			3.5
		)

		# Лезо
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(15, -5),
				Vector2(43, -4),
				Vector2(53, 0),
				Vector2(43, 4),
				Vector2(15, 5)
			]),
			steel
		)

		draw_line(
			Vector2(20, -2),
			Vector2(45, -1),
			Color.WHITE,
			1.5
		)

		# Дуга удару
		if attack_time > 0.0:
			var alpha: float = (
				attack_time / 0.32
			)

			draw_arc(
				Vector2.ZERO,
				55.0,
				-1.20,
				1.20,
				32,
				Color(
					gold.r,
					gold.g,
					gold.b,
					alpha
				),
				4.5,
				true
			)

		draw_set_transform(Vector2.ZERO)


	# ====================================
	# ЕФЕКТИ ЗДІБНОСТЕЙ
	# ====================================

	func _draw_skill_effects() -> void:
		var colors: Array[Color] = [
			Color("#56d5ff"),
			Color("#c28aff"),
			Color("#ffd36d")
		]

		var color: Color = colors[class_id]

		if q_time > 0.0:
			var alpha: float = q_time / 0.45

			draw_arc(
				Vector2.ZERO,
				25.0 + (1.0 - alpha) * 24.0,
				0.0,
				TAU,
				40,
				Color(
					color.r, color.g,
					color.b, alpha
				),
				3.0,
				true
			)

		if e_time > 0.0:
			var alpha: float = e_time / 0.50

			draw_arc(
				Vector2.ZERO,
				42.0 + (1.0 - alpha) * 18.0,
				0.0,
				TAU,
				40,
				Color(
					color.r, color.g,
					color.b, alpha * 0.75
				),
				3.0,
				true
			)

		if r_time > 0.0:
			var alpha: float = r_time / 0.90

			draw_arc(
				Vector2.ZERO,
				30.0 + (1.0 - alpha) * 48.0,
				0.0,
				TAU,
				48,
				Color(
					color.r, color.g,
					color.b, alpha * 0.8
				),
				4.0,
				true
			)


# ====================================
# МЕНЕДЖЕР МОДЕЛЕЙ
# ====================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	scan_timer -= delta

	if scan_timer > 0.0:
		return

	scan_timer = SCAN_TIME

	for node in get_tree().get_nodes_in_group(
		"heroes"
	):
		if not (node is CharacterBody2D):
			continue

		if node.is_queued_for_deletion():
			continue

		var hero: CharacterBody2D = (
			node as CharacterBody2D
		)

		# Приховуємо старий квадрат
		var old_square: CanvasItem = (
			hero.get_node_or_null("ColorRect")
			as CanvasItem
		)

		if is_instance_valid(old_square):
			old_square.visible = false

		# Видаляємо стару процедурну модель
		var old_skin: Node = hero.get_node_or_null(
			"HeroAppearance"
		)

		if is_instance_valid(old_skin):
			if not old_skin.is_queued_for_deletion():
				old_skin.queue_free()

		if hero.has_node("ClassHeroSkin"):
			continue

		var hp_bar: Control = (
			hero.get_node_or_null("HpBar")
			as Control
		)

		if is_instance_valid(hp_bar):
			hp_bar.position.y = -44.0
			hp_bar.z_index = 8

		var skin := ClassHeroSkin.new()

		skin.name = "ClassHeroSkin"
		skin.hero = hero

		hero.add_child(skin)
