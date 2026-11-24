
extends Node

# Mini-MOBA 1v1 — система рун

const RUNE_INTERVAL: float = 60.0
const BUFF_DURATION: float = 12.0
const LANE_Y: float = 324.0
const LANE_MIN_Y: float = 248.0
const LANE_MAX_Y: float = 400.0


# Клас руни, яка з'являється на карті
class RunePickup:
	extends Area2D

	signal collected(hero: Node2D, kind: int, at_position: Vector2)

	var kind: int = 0
	var pulse: float = 0.0
	var taken: bool = false

	func _ready() -> void:
		add_to_group("runes")

		collision_layer = 0
		collision_mask = 1
		monitoring = true
		z_index = 8

		# Зона підбирання
		var hitbox := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 32.0
		hitbox.shape = circle

		add_child(hitbox)
		body_entered.connect(_on_body_entered)

		# Позначення типу руни
		var glyph := Label.new()
		glyph.text = ["S", "D", "+"][kind]
		glyph.position = Vector2(-22, -18)
		glyph.size = Vector2(44, 36)

		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE

		glyph.add_theme_font_size_override("font_size", 23)
		glyph.add_theme_color_override(
			"font_color", Color.WHITE
		)
		glyph.add_theme_color_override(
			"font_outline_color", Color.BLACK
		)
		glyph.add_theme_constant_override(
			"outline_size", 4
		)

		add_child(glyph)

	func _physics_process(delta: float) -> void:
		pulse += delta * 3.0
		queue_redraw()

		if taken:
			return

		# Підбирання за відстанню
		for unit in get_tree().get_nodes_in_group("heroes"):
			if not is_instance_valid(unit):
				continue

			if not (unit is Node2D):
				continue

			if global_position.distance_squared_to(
				unit.global_position
			) <= 32.0 * 32.0:

				_on_body_entered(unit)

				if taken:
					break

	func _draw() -> void:
		var colors: Array[Color] = [
			Color("#f6e05e"),
			Color("#fc8181"),
			Color("#68d391")
		]

		var color: Color = colors[kind]
		var size_factor: float = 1.0 + sin(pulse) * 0.08

		# Світіння
		draw_circle(
			Vector2.ZERO,
			29.0 * size_factor,
			Color(color.r, color.g, color.b, 0.20)
		)

		# Центральна частина
		draw_circle(
			Vector2.ZERO,
			20.0 * size_factor,
			color.darkened(0.35)
		)

		# Зовнішнє кільце
		draw_arc(
			Vector2.ZERO,
			26.0 * size_factor,
			0.0,
			TAU,
			36,
			color,
			3.0,
			true
		)

	func _on_body_entered(body: Node2D) -> void:
		if taken:
			return

		if not body.is_in_group("heroes"):
			return

		if body.get("is_dead") == true:
			return

		taken = true

		collected.emit(
			body,
			kind,
			global_position
		)

		queue_free()


# Основний менеджер рун
var current_main: Node2D = null
var active_rune: RunePickup = null

var rune_timer: float = 0.0

var speed_buffs: Dictionary = {}
var damage_buffs: Dictionary = {}


func _ready() -> void:
	process_priority = 100
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	var main: Node2D = (
		get_tree().get_first_node_in_group("main") as Node2D
	)

	if not is_instance_valid(main):
		return

	# Початок нового матчу
	if main != current_main:
		_reset_for_new_match()
		current_main = main

	if main.get("is_match_over") == true:
		return

	_tick_buffs(delta)

	# Таймер появи рун
	rune_timer += delta

	if rune_timer >= RUNE_INTERVAL:
		rune_timer -= RUNE_INTERVAL
		_spawn_rune(main)

	# Допоміжний рух бота до руни
	_guide_bot_to_rune(delta)


func _reset_for_new_match() -> void:
	if is_instance_valid(active_rune):
		active_rune.queue_free()

	active_rune = null
	rune_timer = 0.0

	speed_buffs.clear()
	damage_buffs.clear()


# Створення нової руни
func _spawn_rune(main: Node2D) -> void:
	if is_instance_valid(active_rune):
		active_rune.queue_free()

	var blue: Vector2 = main.get("blue_throne_pos")
	var red: Vector2 = main.get("red_throne_pos")

	var rune := RunePickup.new()

	# Випадковий тип
	rune.kind = randi_range(0, 2)

	rune.collected.connect(_on_rune_collected)

	main.add_child(rune)

	# Центр лінії
	rune.global_position = Vector2(
		(blue.x + red.x) * 0.5,
		LANE_Y
	)

	active_rune = rune


# Герой підібрав руну
func _on_rune_collected(
	hero: Node2D,
	kind: int,
	pos: Vector2
) -> void:

	active_rune = null

	if not is_instance_valid(hero):
		return

	if hero.get("is_dead") == true:
		return

	match kind:
		0:
			_apply_speed_rune(hero)

			_announce(
				hero,
				"РУНА: ПРИСКОРЕННЯ!",
				Color("#f6e05e")
			)

		1:
			_apply_damage_rune(hero)

			_announce(
				hero,
				"РУНА: ПОСИЛЕННЯ!",
				Color("#fc8181")
			)

		2:
			# Відновлення здоров'я
			if hero.has_method("heal"):
				hero.call(
					"heal",
					float(hero.get("max_hp")) * 0.35
				)

			# Відновлення мани
			var mana: float = float(hero.get("mana"))
			var max_mana: float = float(hero.get("max_mana"))

			hero.set(
				"mana",
				minf(max_mana, mana + max_mana * 0.40)
			)

			_announce(
				hero,
				"РУНА: HP / MP!",
				Color("#68d391")
			)

	# Візуальний ефект
	var main: Node2D = (
		get_tree().get_first_node_in_group("main") as Node2D
	)

	if is_instance_valid(main):
		if main.has_method("spawn_hit_effect"):
			main.call(
				"spawn_hit_effect",
				pos,
				Color("#ffd700"),
				55.0,
				16
			)


func _announce(
	hero: Node2D,
	message: String,
	color: Color
) -> void:

	if hero.has_method("spawn_floating_text"):
		hero.call(
			"spawn_floating_text",
			hero.global_position,
			message,
			color
		)


# Руна прискорення
func _apply_speed_rune(hero: Node2D) -> void:
	var id: int = hero.get_instance_id()

	if speed_buffs.has(id):
		var previous: Dictionary = speed_buffs[id]

		hero.set(
			"speed",
			float(hero.get("speed")) - float(previous["bonus"])
		)

	var bonus: float = float(hero.get("speed")) * 0.35

	hero.set(
		"speed",
		float(hero.get("speed")) + bonus
	)

	speed_buffs[id] = {
		"hero": hero,
		"bonus": bonus,
		"remaining": BUFF_DURATION
	}


# Руна посилення шкоди
func _apply_damage_rune(hero: Node2D) -> void:
	var id: int = hero.get_instance_id()

	if damage_buffs.has(id):
		var previous: Dictionary = damage_buffs[id]

		hero.set(
			"attack_damage",
			float(hero.get("attack_damage")) - float(previous["bonus"])
		)

		hero.set(
			"spell_amp",
			float(hero.get("spell_amp")) - 0.25
		)

	var bonus: float = float(hero.get("attack_damage")) * 0.40

	hero.set(
		"attack_damage",
		float(hero.get("attack_damage")) + bonus
	)

	hero.set(
		"spell_amp",
		float(hero.get("spell_amp")) + 0.25
	)

	damage_buffs[id] = {
		"hero": hero,
		"bonus": bonus,
		"remaining": BUFF_DURATION
	}


# Завершення тимчасових підсилень
func _tick_buffs(delta: float) -> void:

	# Прискорення
	for id in speed_buffs.keys():
		var buff: Dictionary = speed_buffs[id]
		var hero: Node2D = buff["hero"] as Node2D

		if not is_instance_valid(hero):
			speed_buffs.erase(id)
			continue

		buff["remaining"] = float(buff["remaining"]) - delta

		if float(buff["remaining"]) <= 0.0:
			hero.set(
				"speed",
				float(hero.get("speed")) - float(buff["bonus"])
			)

			speed_buffs.erase(id)
		else:
			speed_buffs[id] = buff

	# Посилення шкоди
	for id in damage_buffs.keys():
		var buff: Dictionary = damage_buffs[id]
		var hero: Node2D = buff["hero"] as Node2D

		if not is_instance_valid(hero):
			damage_buffs.erase(id)
			continue

		buff["remaining"] = float(buff["remaining"]) - delta

		if float(buff["remaining"]) <= 0.0:
			hero.set(
				"attack_damage",
				float(hero.get("attack_damage")) - float(buff["bonus"])
			)

			hero.set(
				"spell_amp",
				float(hero.get("spell_amp")) - 0.25
			)

			damage_buffs.erase(id)
		else:
			damage_buffs[id] = buff


# Допоміжна навігація бота до руни
func _guide_bot_to_rune(delta: float) -> void:
	if not is_instance_valid(active_rune):
		return

	if active_rune.is_queued_for_deletion():
		return

	for unit in get_tree().get_nodes_in_group("heroes"):

		if not is_instance_valid(unit):
			continue

		if not (unit is CharacterBody2D):
			continue

		if int(unit.get("direction")) != -1:
			continue

		if unit.get("is_dead") == true:
			continue

		# Легкий бот не шукає руни
		if str(unit.get("difficulty")) == "easy":
			return

		# Не перериваємо лікування
		if unit.get("is_healing") == true:
			return

		if unit.get("going_to_shop") == true:
			return

		if float(unit.get("hp")) < float(unit.get("max_hp")) * 0.45:
			return

		var bot: CharacterBody2D = unit as CharacterBody2D
		var target: Vector2 = active_rune.global_position

		var distance: float = bot.global_position.distance_to(
			target
		)

		# Бот реагує на руну поблизу
		if distance < 33.0 or distance > 470.0:
			return

		# Уникаємо небезпечних веж
		if _would_enter_unsafe_tower_zone(bot, target):
			return

		var direction_to_rune: Vector2 = (
			target - bot.global_position
		).normalized()

		var distance_step: float = minf(
			distance - 30.0,
			float(bot.get("speed")) * delta * 0.55
		)

		if distance_step > 0.0:
			bot.move_and_collide(
				direction_to_rune * distance_step
			)

			bot.global_position.y = clampf(
				bot.global_position.y,
				LANE_MIN_Y,
				LANE_MAX_Y
			)

		return


# Перевірка небезпечної території
func _would_enter_unsafe_tower_zone(
	bot: CharacterBody2D,
	goal: Vector2
) -> bool:

	var destination: Vector2 = bot.global_position.move_toward(
		goal,
		60.0
	)

	for structure in get_tree().get_nodes_in_group("structures"):

		if not is_instance_valid(structure):
			continue

		if not (structure is Node2D):
			continue

		if int(structure.get("direction")) != 1:
			continue

		if float(structure.get("hp")) <= 0.0:
			continue

		if destination.distance_to(
			structure.global_position
		) >= 245.0:
			continue

		var friendly_creep_nearby: bool = false

		for creep in get_tree().get_nodes_in_group("creeps"):

			if not is_instance_valid(creep):
				continue

			if not (creep is Node2D):
				continue

			if int(creep.get("direction")) == -1:
				if float(creep.get("hp")) > 45.0:
					if creep.global_position.distance_to(
						structure.global_position
					) <= 240.0:

						friendly_creep_nearby = true
						break

		if not friendly_creep_nearby:
			return true

	return false
