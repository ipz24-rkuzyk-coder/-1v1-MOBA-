extends Node

# Mini-MOBA 1v1
# Візуали кріпів, катапульт, веж і Тронів
# Підключити через Autoload як BattlefieldVisuals

const SCAN_INTERVAL: float = 0.25
var scan_timer: float = 0.0

# =========================================================
# КРІПИ
# =========================================================
class CreepAppearance:
	extends Node2D

	var actor: Node2D
	var walk_phase: float = 0.0
	var attack_flash: float = 0.0
	var old_cd: float = 0.0

	func _ready() -> void:
		z_index = 2
		if is_instance_valid(actor):
			var cd_value = actor.get("cooldown_timer")
			if cd_value != null:
				old_cd = float(cd_value)

	func _process(delta: float) -> void:
		if not is_instance_valid(actor):
			queue_free()
			return

		var hp_value = actor.get("hp")
		if hp_value != null and float(hp_value) <= 0.0:
			visible = false
			return

		visible = true

		var vel_value = actor.get("velocity")
		var speed: float = 0.0
		if vel_value is Vector2:
			speed = vel_value.length()

		if speed > 3.0:
			walk_phase += delta * 10.0
		else:
			walk_phase += delta * 2.0

		var cd_value = actor.get("cooldown_timer")
		if cd_value != null:
			var cd: float = float(cd_value)
			if cd > old_cd + 0.10:
				attack_flash = 0.22
			old_cd = cd

		attack_flash = maxf(0.0, attack_flash - delta)
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(actor):
			return

		var team_blue: bool = int(actor.get("direction")) == 1

		var armor: Color = Color("#3f7cc5") if team_blue else Color("#b14a4a")
		var shade: Color = Color("#1e3f63") if team_blue else Color("#5b2323")
		var accent: Color = Color("#9dd9ff") if team_blue else Color("#ffc09f")
		var metal: Color = Color("#94a3b8")

		var sway: float = sin(walk_phase) * 1.6
		var bob: float = absf(sin(walk_phase)) * -1.2

		# Тінь + командне кільце
		draw_circle(Vector2(0.0, 8.0), 12.0, Color(0.02, 0.03, 0.06, 0.20))
		draw_arc(
			Vector2(0.0, 7.0),
			12.0,
			0.0,
			TAU,
			24,
			armor.lightened(0.15),
			1.5,
			true
		)

		draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)

		# Ноги
		draw_rect(
			Rect2(-8.0, 4.0 + sway, 6.0, 8.0),
			metal.darkened(0.35)
		)
		draw_rect(
			Rect2(2.0, 4.0 - sway, 6.0, 8.0),
			metal.darkened(0.35)
		)

		# Тіло
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-10.0, -8.0),
				Vector2(10.0, -8.0),
				Vector2(9.0, 5.0),
				Vector2(-9.0, 5.0)
			]),
			shade
		)

		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-8.0, -6.0),
				Vector2(8.0, -6.0),
				Vector2(7.0, 3.0),
				Vector2(-7.0, 3.0)
			]),
			armor
		)

		# Шолом
		draw_circle(Vector2(0.0, -10.0), 6.5, metal.darkened(0.20))
		draw_rect(Rect2(-5.0, -11.0, 10.0, 3.0), shade)
		draw_line(
			Vector2(-3.5, -9.5),
			Vector2(3.5, -9.5),
			accent,
			2.0,
			true
		)

		# Плечі
		draw_circle(Vector2(-9.0, -4.0), 3.5, shade)
		draw_circle(Vector2(9.0, -4.0), 3.5, shade)

		# Малий щит/бронепластина спереду
		draw_rect(Rect2(-4.0, -1.0, 8.0, 5.0), accent.darkened(0.15))

		# Зброя
		var angle: float = 0.0
		if int(actor.get("direction")) == -1:
			angle = PI

		draw_set_transform(Vector2(0.0, bob - 1.0), angle, Vector2.ONE)
		draw_rect(Rect2(-2.0, -2.0, 10.0, 4.0), metal.darkened(0.25))
		draw_rect(Rect2(7.0, -1.0, 9.0, 2.0), armor.lightened(0.10))

		if attack_flash > 0.0:
			var alpha: float = attack_flash / 0.22
			draw_circle(
				Vector2(17.0, 0.0),
				3.5 * alpha,
				Color(accent.r, accent.g, accent.b, alpha)
			)

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# =========================================================
# КАТАПУЛЬТИ
# =========================================================
class CatapultAppearance:
	extends Node2D

	var actor: Node2D
	var recoil: float = 0.0
	var old_cd: float = 0.0

	func _ready() -> void:
		z_index = 3
		if is_instance_valid(actor):
			var cd_value = actor.get("cooldown_timer")
			if cd_value != null:
				old_cd = float(cd_value)

	func _process(delta: float) -> void:
		if not is_instance_valid(actor):
			queue_free()
			return

		var hp_value = actor.get("hp")
		if hp_value != null and float(hp_value) <= 0.0:
			visible = false
			return

		visible = true

		var cd_value = actor.get("cooldown_timer")
		if cd_value != null:
			var cd: float = float(cd_value)
			if cd > old_cd + 0.15:
				recoil = 1.0
			old_cd = cd

		recoil = maxf(0.0, recoil - delta * 3.5)
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(actor):
			return

		var team_blue: bool = int(actor.get("direction")) == 1

		var armor: Color = Color("#4d87d1") if team_blue else Color("#b64c4c")
		var shade: Color = Color("#24384a") if team_blue else Color("#552828")
		var wood: Color = Color("#7a5a42")
		var metal: Color = Color("#b0bec5")
		var accent: Color = Color("#7dd3fc") if team_blue else Color("#fca5a5")

		# Тінь
		draw_circle(Vector2(0.0, 14.0), 22.0, Color(0.02, 0.03, 0.06, 0.22))

		# Колеса
		draw_circle(Vector2(-15.0, 9.0), 8.0, shade)
		draw_circle(Vector2(15.0, 9.0), 8.0, shade)
		draw_circle(Vector2(-15.0, 9.0), 4.0, metal.darkened(0.30))
		draw_circle(Vector2(15.0, 9.0), 4.0, metal.darkened(0.30))

		# Платформа
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-20.0, -5.0),
				Vector2(20.0, -5.0),
				Vector2(15.0, 8.0),
				Vector2(-15.0, 8.0)
			]),
			wood
		)

		# Корпус
		draw_rect(Rect2(-13.0, -13.0, 26.0, 12.0), shade)
		draw_rect(Rect2(-10.0, -10.0, 20.0, 7.0), armor)

		# Броня
		draw_line(Vector2(-9.0, -6.0), Vector2(9.0, -6.0), accent, 1.8)
		draw_rect(Rect2(-3.0, -9.0, 6.0, 5.0), metal.darkened(0.25))

		# Гармата / стріла облогового механізму
		var angle: float = 0.0
		if int(actor.get("direction")) == -1:
			angle = PI

		draw_set_transform(Vector2(0.0, -6.0), angle, Vector2.ONE)
		draw_rect(Rect2(-4.0 - recoil * 5.0, -3.0, 24.0, 6.0), metal.darkened(0.15))
		draw_rect(Rect2(15.0 - recoil * 5.0, -4.0, 10.0, 8.0), armor)

		if recoil > 0.0:
			draw_circle(
				Vector2(27.0, 0.0),
				5.0 * recoil,
				Color(accent.r, accent.g, accent.b, recoil)
			)

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# =========================================================
# ВЕЖІ / ТРОНИ
# =========================================================
class StructureAppearance:
	extends Node2D

	var actor: Node2D
	var pulse: float = 0.0
	var old_beam: float = 0.0

	func _ready() -> void:
		z_index = 2
		if is_instance_valid(actor):
			var beam_value = actor.get("beam_timer")
			if beam_value != null:
				old_beam = float(beam_value)

	func _process(delta: float) -> void:
		if not is_instance_valid(actor):
			queue_free()
			return

		var hp_value = actor.get("hp")
		if hp_value != null and float(hp_value) <= 0.0:
			visible = false
			return

		visible = true

		var beam_value = actor.get("beam_timer")
		if beam_value != null:
			var beam: float = float(beam_value)
			if beam > old_beam + 0.025:
				pulse = 0.35
			old_beam = beam

		pulse = maxf(0.0, pulse - delta)
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(actor):
			return

		var team_blue: bool = int(actor.get("direction")) == 1
		var is_throne: bool = actor.get("is_throne") == true

		var armor: Color = Color("#4d85cc") if team_blue else Color("#c05656")
		var shade: Color = Color("#26384a") if team_blue else Color("#572727")
		var accent: Color = Color("#67e8f9") if team_blue else Color("#fca5a5")
		var core: Color = Color("#c4f1ff") if team_blue else Color("#ffd1c7")
		var metal: Color = Color("#9aa7b1")

		if is_throne:
			# Основа Трону
			draw_circle(Vector2(0.0, 18.0), 28.0, Color(0.02, 0.03, 0.06, 0.25))
			draw_rect(Rect2(-24.0, 2.0, 48.0, 16.0), shade)
			draw_rect(Rect2(-18.0, -10.0, 36.0, 14.0), armor)

			# Бічні опори
			draw_rect(Rect2(-22.0, -24.0, 10.0, 16.0), shade)
			draw_rect(Rect2(12.0, -24.0, 10.0, 16.0), shade)
			draw_rect(Rect2(-19.0, -21.0, 4.0, 10.0), metal)
			draw_rect(Rect2(15.0, -21.0, 4.0, 10.0), metal)

			# Центральне ядро
			draw_circle(Vector2(0.0, -10.0), 12.0, shade)
			draw_circle(Vector2(0.0, -10.0), 8.5, core)
			draw_circle(
				Vector2(0.0, -10.0),
				5.5 + pulse * 4.0,
				Color(accent.r, accent.g, accent.b, 0.75)
			)

			# Вежі-антени
			draw_line(Vector2(-8.0, -20.0), Vector2(-8.0, -32.0), accent, 2.0)
			draw_line(Vector2(8.0, -20.0), Vector2(8.0, -32.0), accent, 2.0)
			draw_circle(Vector2(-8.0, -34.0), 2.5, accent)
			draw_circle(Vector2(8.0, -34.0), 2.5, accent)

			# Пульсація атаки
			if pulse > 0.0:
				var alpha: float = pulse / 0.35
				draw_arc(
					Vector2.ZERO,
					38.0 - alpha * 6.0,
					0.0,
					TAU,
					48,
					Color(accent.r, accent.g, accent.b, alpha * 0.8),
					3.0,
					true
				)
		else:
			# Звичайна вежа
			draw_circle(Vector2(0.0, 14.0), 22.0, Color(0.02, 0.03, 0.06, 0.22))

			# Підставка
			draw_rect(Rect2(-20.0, 6.0, 40.0, 12.0), shade)

			# Головний корпус
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(-15.0, 6.0),
					Vector2(15.0, 6.0),
					Vector2(11.0, -20.0),
					Vector2(-11.0, -20.0)
				]),
				armor
			)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(-12.0, 4.0),
					Vector2(12.0, 4.0),
					Vector2(9.0, -16.0),
					Vector2(-9.0, -16.0)
				]),
				shade
			)

			# Світлове ядро
			draw_circle(Vector2(0.0, -4.0), 6.0, core)
			draw_circle(
				Vector2(0.0, -4.0),
				3.8 + pulse * 3.0,
				Color(accent.r, accent.g, accent.b, 0.75)
			)

			# Верхня гармата
			draw_rect(Rect2(-4.0, -26.0, 8.0, 10.0), metal.darkened(0.20))
			draw_rect(Rect2(-2.0, -35.0, 4.0, 10.0), accent)

			if pulse > 0.0:
				var alpha: float = pulse / 0.35
				draw_circle(
					Vector2(0.0, -39.0),
					4.0 + 5.0 * alpha,
					Color(accent.r, accent.g, accent.b, alpha)
				)

# =========================================================
# ГОЛОВНИЙ МЕНЕДЖЕР
# =========================================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	scan_timer -= delta
	if scan_timer > 0.0:
		return

	scan_timer = SCAN_INTERVAL

	_apply_creep_visuals()
	_apply_catapult_visuals()
	_apply_structure_visuals()

func _apply_creep_visuals() -> void:
	for node in get_tree().get_nodes_in_group("creeps"):
		if not (node is Node2D):
			continue

		if node.is_in_group("catapults"):
			continue

		if node.has_node("CreepAppearance"):
			continue

		var creep := node as Node2D

		var color_rect: CanvasItem = creep.get_node_or_null("ColorRect") as CanvasItem
		if is_instance_valid(color_rect):
			color_rect.visible = false

		var hp_bar: Control = creep.get_node_or_null("HpBar") as Control
		if is_instance_valid(hp_bar):
			hp_bar.position.y = -23.0
			hp_bar.z_index = 5

		var skin := CreepAppearance.new()
		skin.name = "CreepAppearance"
		skin.actor = creep
		creep.add_child(skin)

func _apply_catapult_visuals() -> void:
	for node in get_tree().get_nodes_in_group("catapults"):
		if not (node is Node2D):
			continue

		if node.has_node("CatapultAppearance"):
			continue

		var catapult := node as Node2D

		# Сховаємо старий напис CAT, якщо він є
		for child in catapult.get_children():
			if child is Label:
				var label := child as Label
				if label.text == "CAT":
					label.visible = false

		var hp_bar_candidate: Control = catapult.get_node_or_null("HpBar") as Control
		if is_instance_valid(hp_bar_candidate):
			hp_bar_candidate.z_index = 5

		var skin := CatapultAppearance.new()
		skin.name = "CatapultAppearance"
		skin.actor = catapult
		catapult.add_child(skin)

func _apply_structure_visuals() -> void:
	for node in get_tree().get_nodes_in_group("structures"):
		if not (node is Node2D):
			continue

		if node.has_node("StructureAppearance"):
			continue

		var structure := node as Node2D

		var color_rect: CanvasItem = structure.get_node_or_null("ColorRect") as CanvasItem
		if is_instance_valid(color_rect):
			color_rect.visible = false

		var hp_bar: Control = structure.get_node_or_null("HpBar") as Control
		if is_instance_valid(hp_bar):
			if structure.get("is_throne") == true:
				hp_bar.position.y = -48.0
			else:
				hp_bar.position.y = -38.0
			hp_bar.z_index = 5

		var skin := StructureAppearance.new()
		skin.name = "StructureAppearance"
		skin.actor = structure
		structure.add_child(skin)
