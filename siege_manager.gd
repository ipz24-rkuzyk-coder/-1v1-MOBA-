
extends Node

# Mini-MOBA 1v1 — облогові катапульти
# Кожна третя хвиля створює по катапульті для обох команд.

const SIEGE_EVERY: int = 3
const LANE_Y: float = 324.0

var current_main: Node2D = null
var previous_wave_timer: float = 0.0
var wave_number: int = 0


# Клас катапульти
class CatapultUnit:
	extends CharacterBody2D

	const PROJECTILE_SCENE = preload("res://projectile.tscn")

	const LANE_MIN_Y: float = 245.0
	const LANE_MAX_Y: float = 405.0
	const LANE_Y: float = 324.0

	var direction: int = 1

	var max_hp: float = 286.0
	var hp: float = 286.0

	var speed: float = 82.0
	var attack_damage: float = 20.0
	var attack_range: float = 260.0
	var aggro_range: float = 315.0
	var attack_cooldown: float = 1.5

	var cooldown_timer: float = 0.0
	var last_attacker: Node2D = null

	var hp_fill: ColorRect


	func _ready() -> void:
		add_to_group("creeps")
		add_to_group("catapults")

		hp = max_hp
		collision_layer = 1
		collision_mask = 1

		# Фізична форма
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()

		shape.size = Vector2(38.0, 28.0)
		collider.shape = shape
		add_child(collider)

		# Тло шкали здоров'я
		var hp_bg := ColorRect.new()
		hp_bg.position = Vector2(-22.0, -30.0)
		hp_bg.size = Vector2(44.0, 5.0)
		hp_bg.color = Color("#303640")
		hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hp_bg)

		# Зелена шкала здоров'я
		hp_fill = ColorRect.new()
		hp_fill.position = Vector2(-22.0, -30.0)
		hp_fill.size = Vector2(44.0, 5.0)
		hp_fill.color = Color("#68d391")
		hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hp_fill)

		# Позначення катапульти
		var label := Label.new()
		label.text = "CAT"
		label.position = Vector2(-20.0, -10.0)
		label.size = Vector2(40.0, 20.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override(
			"font_color", Color.WHITE
		)

		add_child(label)
		queue_redraw()


	# Малювання корпусу та коліс
	func _draw() -> void:
		var body_color: Color = (
			Color("#277da1")
			if direction == 1
			else Color("#c05242")
		)

		draw_rect(
			Rect2(-21.0, -14.0, 42.0, 28.0),
			body_color
		)

		draw_rect(
			Rect2(-15.0, -9.0, 30.0, 18.0),
			Color("#343a40")
		)

		# Колеса
		draw_circle(
			Vector2(-15.0, 14.0),
			7.0,
			Color("#20242a")
		)

		draw_circle(
			Vector2(15.0, 14.0),
			7.0,
			Color("#20242a")
		)

		# Облоговий ствол
		draw_line(
			Vector2(-3.0, -1.0),
			Vector2(float(direction) * 27.0, -6.0),
			Color("#ffd166"),
			6.0
		)


	func _physics_process(delta: float) -> void:
		if hp <= 0.0:
			return

		cooldown_timer = maxf(
			0.0,
			cooldown_timer - delta
		)

		var target: Node2D = _find_enemy()

		if is_instance_valid(target):
			var distance: float = global_position.distance_to(
				target.global_position
			)

			if distance <= attack_range:
				velocity = Vector2.ZERO

				if cooldown_timer <= 0.0:
					_fire_projectile(target)
					cooldown_timer = attack_cooldown
			else:
				velocity = (
					target.global_position - global_position
				).normalized() * speed
		else:
			# Рухаємось до ворожої бази
			var correct_y: float = clampf(
				(LANE_Y - global_position.y) * 2.0,
				-45.0,
				45.0
			)

			velocity = Vector2(
				float(direction) * speed,
				correct_y
			)

		move_and_slide()

		global_position.y = clampf(
			global_position.y,
			LANE_MIN_Y,
			LANE_MAX_Y
		)


	# Пошук ворога
	func _find_enemy() -> Node2D:
		var best_target: Node2D = null
		var best_distance: float = aggro_range

		for node in get_parent().get_children():
			if node == self:
				continue

			if not (node is Node2D):
				continue

			if not node.has_method("take_damage"):
				continue

			var team_value = node.get("direction")

			if team_value == null:
				continue

			if int(team_value) == direction:
				continue

			if node.get("is_dead") == true:
				continue

			var health_value = node.get("hp")

			if health_value == null:
				continue

			if float(health_value) <= 0.0:
				continue

			if node.has_method("is_invulnerable"):
				if node.is_invulnerable():
					continue

			var distance: float = global_position.distance_to(
				node.global_position
			)

			if distance < best_distance:
				best_distance = distance
				best_target = node

		return best_target


	# Стріляємо снарядом
	func _fire_projectile(target: Node2D) -> void:
		if not is_instance_valid(target):
			return

		var final_damage: float = attack_damage

		# Бонус проти будівель
		if target.is_in_group("structures"):
			final_damage *= 1.75

		var projectile: Area2D = PROJECTILE_SCENE.instantiate()

		projectile.set("team", direction)
		projectile.set("damage", final_damage)
		projectile.set("speed", 430.0)
		projectile.set("max_range", 390.0)
		projectile.set("target", target)
		projectile.set("owner_unit", self)

		get_parent().add_child(projectile)

		projectile.global_position = (
			global_position
			+ Vector2(float(direction) * 25.0, -5.0)
		)


	# Отримання шкоди
	func take_damage(amount: float) -> void:
		if hp <= 0.0:
			return

		hp -= amount

		if is_instance_valid(hp_fill):
			hp_fill.size.x = (
				44.0 * maxf(hp, 0.0) / max_hp
			)

		if hp > 0.0:
			return

		hp = 0.0

		# XP героям поблизу
		for hero in get_tree().get_nodes_in_group("heroes"):
			if not is_instance_valid(hero):
				continue

			if not hero.has_method("gain_xp"):
				continue

			if int(hero.get("direction")) == direction:
				continue

			if hero.get("is_dead") == true:
				continue

			if global_position.distance_to(
				hero.global_position
			) <= 550.0:
				hero.gain_xp(70)

		# Подвійне золото за добивання
		if is_instance_valid(last_attacker):
			if last_attacker.is_in_group("heroes"):
				if last_attacker.has_method("add_gold"):
					last_attacker.add_gold(
						56,
						global_position
					)

		# Ефект руйнування
		var main: Node = (
			get_tree().get_first_node_in_group("main")
		)

		if is_instance_valid(main):
			if main.has_method("spawn_hit_effect"):
				main.spawn_hit_effect(
					global_position,
					Color("#ffd166"),
					36.0,
					12
				)

		queue_free()


# Менеджер хвиль
func _ready() -> void:
	process_priority = 100
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _physics_process(_delta: float) -> void:
	var main: Node2D = (
		get_tree().get_first_node_in_group("main") as Node2D
	)

	if not is_instance_valid(main):
		current_main = null
		return

	# Скидання після нового матчу
	if main != current_main:
		current_main = main
		wave_number = 0
		previous_wave_timer = float(main.get("wave_timer"))
		return

	if main.get("is_match_over") == true:
		return

	var current_timer: float = float(
		main.get("wave_timer")
	)

	# Основна гра обнуляє таймер раз на 15 секунд.
	# Це означає, що почалася нова хвиля.
	if current_timer < previous_wave_timer:
		wave_number += 1

		if wave_number % SIEGE_EVERY == 0:
			_spawn_siege_wave(main)

	previous_wave_timer = current_timer


# Створення облогової хвилі
func _spawn_siege_wave(main: Node2D) -> void:
	var blue_pos: Vector2 = main.get("blue_throne_pos")
	var red_pos: Vector2 = main.get("red_throne_pos")

	_create_catapult(
		main,
		1,
		Vector2(blue_pos.x + 45.0, LANE_Y + 28.0)
	)

	_create_catapult(
		main,
		-1,
		Vector2(red_pos.x - 45.0, LANE_Y - 28.0)
	)

	print(
		"Облогова хвиля №%d: створено 2 катапульти"
		% wave_number
	)


func _create_catapult(
	main: Node2D,
	team: int,
	spawn_pos: Vector2
) -> void:
	var unit := CatapultUnit.new()

	unit.direction = team
	unit.name = (
		"BlueCatapult"
		if team == 1
		else "RedCatapult"
	)

	main.add_child(unit)
	unit.global_position = spawn_pos
