
extends Node

# Mini-MOBA: додаткові ефекти навичок за класами.
# Autoload: ClassSkillFX. Залиш HeroClasses увімкненим.
# Q Мага та щит Q Воїна вже реалізовано у HeroClasses.

var hero_cache: Dictionary = {}
var slows: Dictionary = {}
var speed_buffs: Dictionary = {}
var tracked_main: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 120

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	var main: Node = get_tree().get_first_node_in_group("main")

	if not is_instance_valid(main):
		return

	if main.is_queued_for_deletion():
		return

	# Очищення старих даних при новому матчі
	if main != tracked_main:
		tracked_main = main
		hero_cache.clear()
		slows.clear()
		speed_buffs.clear()

	if main.get("is_match_over") == true:
		return

	_update_effects(delta)

	for unit in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(unit):
			continue

		if unit.is_queued_for_deletion():
			continue

		if unit.get("is_dead") == true:
			continue

		var hero: Node2D = unit as Node2D

		if not is_instance_valid(hero):
			continue

		var marker: Node = hero.get_node_or_null("ClassMarker")

		if not is_instance_valid(marker):
			continue

		var class_id: int = int(marker.get("class_id"))
		var id: int = hero.get_instance_id()

		var e: float = float(hero.get("e_cd"))
		var r: float = float(hero.get("r_cd"))

		if not hero_cache.has(id):
			hero_cache[id] = {"e": e, "r": r}
			continue

		var previous: Dictionary = hero_cache[id]

		if e > float(previous["e"]) + 0.65:
			_on_e_cast(hero, class_id, main)

		if r > float(previous["r"]) + 0.65:
			_on_r_cast(hero, class_id, main)

		hero_cache[id] = {"e": e, "r": r}


# ==========================================
# ЗДІБНОСТІ E
# ==========================================

func _on_e_cast(hero: Node2D, class_id: int, main: Node) -> void:
	match class_id:
		0:
			# Стрілець: бонус швидкості після ривка
			_add_speed(hero, 28.0, 1.5)
			_burst(main, hero.global_position, Color("#54ccff"), 36.0)

		1:
			# Маг: магічна хвиля сповільнення
			_area_effect(
				hero, hero.global_position,
				112.0, 0.0, 0.22, 1.5
			)

			_burst(main, hero.global_position, Color("#be80ff"), 108.0)

		2:
			# Воїн: ударна хвиля після ривка
			_area_effect(
				hero, hero.global_position,
				95.0,
				22.0 + float(hero.get("e_level")) * 5.0,
				0.18, 1.0
			)

			_burst(main, hero.global_position, Color("#ffc566"), 96.0)


# ==========================================
# ЗДІБНОСТІ R
# ==========================================

func _on_r_cast(hero: Node2D, class_id: int, main: Node) -> void:
	match class_id:
		0:
			# Стрілець: стандартний орбітальний вибух
			pass

		1:
			# Маг: контроль реалізований в HeroClasses
			pass

		2:
			# Воїн: ударна хвиля
			var impact: Vector2 = hero.global_position
			var effects = hero.get("active_effects")

			if effects is Array:
				for i in range(effects.size() - 1, -1, -1):
					var effect: Dictionary = effects[i]

					if str(effect.get("type", "")) == "blast":
						impact = effect["pos"]
						break

			_area_effect(
				hero, impact,
				145.0, 0.0, 0.65, 0.75
			)

			_burst(main, impact, Color("#ffe39a"), 145.0)


# ==========================================
# ШКОДА ТА СПОВІЛЬНЕННЯ ПО ПЛОЩІ
# ==========================================

func _area_effect(
	caster: Node2D,
	center: Vector2,
	radius: float,
	damage: float,
	slow_factor: float,
	slow_time: float
) -> void:

	for group in ["heroes", "creeps"]:
		for unit in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(unit):
				continue

			if unit.is_queued_for_deletion():
				continue

			if unit == caster or unit.get("direction") == null:
				continue

			if int(unit.get("direction")) == int(caster.get("direction")):
				continue

			if unit.get("is_dead") == true or float(unit.get("hp")) <= 0.0:
				continue

			if unit.global_position.distance_to(center) > radius:
				continue

			if damage > 0.0 and unit.has_method("take_damage"):
				if "last_attacker" in unit:
					unit.last_attacker = caster

				unit.take_damage(damage)

			if slow_factor > 0.0:
				if is_instance_valid(unit):
					if not unit.is_queued_for_deletion():
						_add_slow(
							unit as Node2D,
							slow_factor,
							slow_time
						)


# ==========================================
# БЕЗПЕЧНЕ СПОВІЛЬНЕННЯ
# ==========================================

func _add_slow(unit: Node2D, factor: float, duration: float) -> void:
	if not is_instance_valid(unit):
		return

	if unit.is_queued_for_deletion() or unit.get("speed") == null:
		return

	var id: int = unit.get_instance_id()

	# Не накопичуємо штраф при повторному ефекті
	if slows.has(id):
		var old: Dictionary = slows[id]
		unit.set(
			"speed",
			float(unit.get("speed")) + float(old["amount"])
		)

	var current_speed: float = float(unit.get("speed"))

	var target_speed: float = maxf(
		60.0,
		current_speed * (1.0 - clampf(factor, 0.0, 0.90))
	)

	# Зберігаємо реальне зниження швидкості
	var reduction: float = maxf(
		0.0,
		current_speed - target_speed
	)

	unit.set("speed", current_speed - reduction)

	slows[id] = {
		"node": unit,
		"amount": reduction,
		"time": duration
	}


# ==========================================
# ПРИСКОРЕННЯ
# ==========================================

func _add_speed(unit: Node2D, amount: float, duration: float) -> void:
	if not is_instance_valid(unit):
		return

	if unit.is_queued_for_deletion() or unit.get("speed") == null:
		return

	var id: int = unit.get_instance_id()

	if speed_buffs.has(id):
		var old: Dictionary = speed_buffs[id]

		unit.set(
			"speed",
			float(unit.get("speed")) - float(old["amount"])
		)

	unit.set("speed", float(unit.get("speed")) + amount)

	speed_buffs[id] = {
		"node": unit,
		"amount": amount,
		"time": duration
	}


# ==========================================
# ОНОВЛЕННЯ ЕФЕКТІВ БЕЗ ВИЛЬОТІВ
# ==========================================

func _update_effects(delta: float) -> void:
	# Перевіряємо посилання до приведення типу.
	for id in slows.keys():
		var entry: Dictionary = slows[id]
		var unit_ref = entry.get("node", null)

		if not is_instance_valid(unit_ref):
			slows.erase(id)
			continue

		if not (unit_ref is Node2D):
			slows.erase(id)
			continue

		var unit: Node2D = unit_ref

		if unit.is_queued_for_deletion():
			slows.erase(id)
			continue

		entry["time"] = float(entry["time"]) - delta

		if float(entry["time"]) <= 0.0:
			if unit.get("speed") != null:
				unit.set(
					"speed",
					float(unit.get("speed")) + float(entry["amount"])
				)

			slows.erase(id)
		else:
			slows[id] = entry

	# Окремо перевіряємо прискорення
	for id in speed_buffs.keys():
		var entry: Dictionary = speed_buffs[id]
		var unit_ref = entry.get("node", null)

		if not is_instance_valid(unit_ref):
			speed_buffs.erase(id)
			continue

		if not (unit_ref is Node2D):
			speed_buffs.erase(id)
			continue

		var unit: Node2D = unit_ref

		if unit.is_queued_for_deletion():
			speed_buffs.erase(id)
			continue

		entry["time"] = float(entry["time"]) - delta

		if float(entry["time"]) <= 0.0:
			if unit.get("speed") != null:
				unit.set(
					"speed",
					float(unit.get("speed")) - float(entry["amount"])
				)

			speed_buffs.erase(id)
		else:
			speed_buffs[id] = entry


# ==========================================
# ВІЗУАЛЬНИЙ ЕФЕКТ
# ==========================================

func _burst(
	main: Node,
	at: Vector2,
	tint: Color,
	radius: float
) -> void:
	if not is_instance_valid(main):
		return

	if main.is_queued_for_deletion():
		return

	if main.has_method("spawn_hit_effect"):
		main.spawn_hit_effect(at, tint, radius, 14)
