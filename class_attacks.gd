
extends Node

# Mini-MOBA 1v1 — Class Attacks
# Autoload: ClassAttacks
# Реальний ближній удар Воїна та сфери Мага.

const MELEE_REACH: float = 105.0
const WARRIOR_ATTACK_RANGE: float = 95.0
const MELEE_CONE_DOT: float = 0.15

var swing_sound: AudioStreamWAV
var swing_player: AudioStreamPlayer


# Магічна сфера
class MagicOrb:
	extends Node2D

	var tint: Color = Color("#b6a0ff")
	var pulse: float = 0.0

	func _ready() -> void:
		z_index = 5

	func _process(delta: float) -> void:
		pulse += delta * 10.0
		queue_redraw()

	func _draw() -> void:
		var radius: float = (
			12.0 + sin(pulse) * 2.0
		)

		draw_circle(
			Vector2.ZERO,
			radius,
			Color(
				tint.r,
				tint.g,
				tint.b,
				0.20
			)
		)

		draw_circle(
			Vector2.ZERO,
			7.0,
			tint
		)

		draw_circle(
			Vector2.ZERO,
			3.0,
			Color.WHITE
		)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = 100

	# Відстежуємо момент створення снаряда
	get_tree().node_added.connect(
		_on_node_added
	)

	# Окремий звук помаху мечем
	swing_sound = _create_swing_sound()

	swing_player = AudioStreamPlayer.new()
	swing_player.name = "SwordSwing"
	swing_player.stream = swing_sound
	swing_player.volume_db = -9.0

	add_child(swing_player)

	print("ClassAttacks: система атак класів готова")


func _process(_delta: float) -> void:
	if get_tree().paused:
		return

	# Воїн повинен мати коротку дистанцію атаки,
	# а не старі 185 або 230 пікселів.
	for node in get_tree().get_nodes_in_group(
		"heroes"
	):
		if not is_instance_valid(node):
			continue

		if node.is_queued_for_deletion():
			continue

		if _get_class(node) != 2:
			continue

		if node.get("attack_range") == null:
			continue

		if not is_equal_approx(
			float(node.get("attack_range")),
			WARRIOR_ATTACK_RANGE
		):
			node.set(
				"attack_range",
				WARRIOR_ATTACK_RANGE
			)


func _get_class(hero: Node) -> int:
	var meta_name: String = (
		"player_hero_class"
		if int(hero.get("direction")) == 1
		else "bot_hero_class"
	)

	var class_id: int = int(
		Engine.get_meta(meta_name, 0)
	)

	var marker: Node = hero.get_node_or_null(
		"ClassMarker"
	)

	if is_instance_valid(marker):
		class_id = int(marker.get("class_id"))

	return clampi(class_id, 0, 2)


# =========================================
# ПЕРЕХОПЛЕННЯ СНАРЯДІВ
# =========================================

func _on_node_added(node: Node) -> void:
	if not (node is Area2D):
		return

	var projectile: Area2D = node as Area2D

	var script: Script = (
		projectile.get_script() as Script
	)

	if script == null:
		return

	if script.resource_path != "res://projectile.gd":
		return

	var attacker = projectile.get("owner_unit")

	if not is_instance_valid(attacker):
		return

	if not (attacker is CharacterBody2D):
		return

	if not attacker.is_in_group("heroes"):
		return

	var hero: CharacterBody2D = (
		attacker as CharacterBody2D
	)

	var class_id: int = _get_class(hero)

	match class_id:
		0:
			# Стрілець — стандартний снаряд
			pass

		1:
			# Маг — магічна сфера
			_apply_mage_projectile(
				projectile,
				hero
			)

		2:
			# Воїн не стріляє.
			# Його звичайна атака — удар мечем.
			var is_skill: bool = (
				projectile.get("is_skill") == true
			)

			if not is_skill:
				_warrior_melee_attack(
					hero,
					projectile
				)

			# Прибираємо старий снаряд.
			# Для Q щит обробляє HeroClasses.
			projectile.queue_free()


# =========================================
# МАГ — МАГІЧНІ СНАРЯДИ
# =========================================

func _apply_mage_projectile(
	projectile: Area2D,
	hero: CharacterBody2D
) -> void:
	var old_bullet: CanvasItem = (
		projectile.get_node_or_null("ColorRect")
		as CanvasItem
	)

	if is_instance_valid(old_bullet):
		old_bullet.visible = false

	var orb := MagicOrb.new()

	orb.name = "MagicOrb"

	orb.tint = (
		Color("#a99cff")
		if int(hero.get("direction")) == 1
		else Color("#ff87d1")
	)

	# Сильніша сфера для Q
	if projectile.get("is_skill") == true:
		orb.scale = Vector2(1.5, 1.5)

	projectile.add_child(orb)


# =========================================
# ВОЇН — РЕАЛЬНИЙ УДАР МЕЧЕМ
# =========================================

func _warrior_melee_attack(
	hero: CharacterBody2D,
	projectile: Area2D
) -> void:
	if hero.get("is_dead") == true:
		return

	var facing: Vector2 = Vector2.RIGHT

	# Напрямок удару гравця
	if int(hero.get("direction")) == 1:
		facing = (
			hero.get_global_mouse_position()
			- hero.global_position
		)

	# Напрямок удару бота
	else:
		var locked = projectile.get("target")

		if is_instance_valid(locked):
			facing = (
				locked.global_position
				- hero.global_position
			)
		else:
			facing = Vector2.LEFT

	if facing.length_squared() < 0.1:
		facing = Vector2(
			float(hero.get("direction")),
			0.0
		)

	facing = facing.normalized()

	var best_target: Node2D = null
	var nearest: float = INF

	# Шукаємо ворога у секторі перед мечем
	for group_name in [
		"creeps",
		"heroes",
		"structures"
	]:
		for unit in get_tree().get_nodes_in_group(
			group_name
		):
			if not is_instance_valid(unit):
				continue

			if not (unit is Node2D):
				continue

			if unit == hero:
				continue

			if unit.is_queued_for_deletion():
				continue

			if not unit.has_method("take_damage"):
				continue

			var team_value = unit.get("direction")

			if team_value == null:
				continue

			if int(team_value) == int(
				hero.get("direction")
			):
				continue

			if unit.get("is_dead") == true:
				continue

			var health_value = unit.get("hp")

			if health_value == null:
				continue

			if float(health_value) <= 0.0:
				continue

			if unit.has_method("is_invulnerable"):
				if unit.is_invulnerable():
					continue

			var to_enemy: Vector2 = (
				unit.global_position
				- hero.global_position
			)

			var distance: float = (
				to_enemy.length()
			)

			if distance > MELEE_REACH:
				continue

			if distance < 0.01:
				continue

			# Ворог повинен бути перед героєм
			var dot_value: float = (
				facing.dot(to_enemy.normalized())
			)

			if dot_value < MELEE_CONE_DOT:
				continue

			if distance < nearest:
				nearest = distance
				best_target = unit as Node2D

	# Звук помаху навіть без попадання
	if is_instance_valid(swing_player):
		swing_player.pitch_scale = randf_range(
			0.90,
			1.08
		)
		swing_player.play()

	if not is_instance_valid(best_target):
		return

	# Шкода зберігається з основної
	# системи атаки та предметів.
	var damage: float = float(
		projectile.get("damage")
	)

	var lifesteal: float = float(
		projectile.get("lifesteal")
	)

	# Нарахування добивання герою
	if "last_attacker" in best_target:
		best_target.set(
			"last_attacker",
			hero
		)

	best_target.take_damage(damage)

	# Вампіризм
	if lifesteal > 0.0:
		if is_instance_valid(hero):
			if not best_target.is_in_group(
				"structures"
			):
				if hero.has_method("heal"):
					hero.heal(
						damage * lifesteal
					)

	# Ефект влучання меча
	var main: Node = (
		get_tree().get_first_node_in_group(
			"main"
		)
	)

	if is_instance_valid(main):
		if main.has_method("spawn_hit_effect"):
			main.spawn_hit_effect(
				best_target.global_position,
				Color("#ffd36f"),
				35.0,
				9
			)


# =========================================
# ОРИГІНАЛЬНИЙ ЗВУК МЕЧА
# =========================================

func _create_swing_sound() -> AudioStreamWAV:
	var rate: int = 22050
	var duration: float = 0.22
	var count: int = int(duration * rate)

	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	var phase: float = 0.0

	for i in range(count):
		var t: float = float(i) / float(rate)
		var progress: float = t / duration

		var frequency: float = lerpf(
			480.0,
			95.0,
			progress
		)

		phase += TAU * frequency / float(rate)

		var envelope: float = (
			sin(progress * PI)
			* pow(1.0 - progress, 0.65)
		)

		var tone: float = sin(phase) * 0.35
		var noise: float = randf_range(
			-1.0,
			1.0
		) * 0.55

		var value: float = (
			tone + noise
		) * envelope * 0.55

		var sample: int = int(
			clampf(value, -1.0, 1.0)
			* 32767.0
		)

		var encoded: int = sample & 0xFFFF

		bytes[i * 2] = encoded & 0xFF
		bytes[i * 2 + 1] = (
			encoded >> 8
		) & 0xFF

	var stream := AudioStreamWAV.new()

	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes

	return stream
