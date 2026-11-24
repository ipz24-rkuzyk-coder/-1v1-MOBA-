
extends Node

# Mini-MOBA 1v1
# Система вибору трьох класів героїв.
# Autoload: HeroClasses

const CLASS_NAMES: Array[String] = [
	"Стрілець",
	"Маг",
	"Воїн"
]

const CLASS_DESCRIPTIONS: Array[String] = [
	"Дальній бій, швидкі атаки, критичні удари.",
	"Магічні сфери, більше мани, AoE та сповільнення.",
	"Важка броня, меч, більше HP і захисний щит."
]

var current_main: Node2D = null

var picker_layer: CanvasLayer = null
var picker_background: ColorRect = null
var picker_center: CenterContainer = null
var player_option: OptionButton = null
var bot_option: OptionButton = null

var classes_confirmed: bool = false

var hero_states: Dictionary = {}
var slowed_units: Dictionary = {}


# ==========================================
# ВІЗУАЛЬНИЙ МАРКЕР КЛАСУ
# ==========================================

class ClassMarker:
	extends Node2D

	var actor: Node2D
	var class_id: int = 0
	var shield_active: bool = false
	var pulse: float = 0.0

	func _ready() -> void:
		z_index = 4

		var caption := Label.new()

		caption.text = [
			"СТРІЛЕЦЬ",
			"МАГ",
			"ВОЇН"
		][class_id]

		caption.position = Vector2(-38.0, -62.0)
		caption.size = Vector2(76.0, 15.0)

		caption.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)

		caption.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		caption.add_theme_font_size_override(
			"font_size", 10
		)

		var colors: Array[Color] = [
			Color("#8fd5ff"),
			Color("#d9a6ff"),
			Color("#ffca70")
		]

		caption.add_theme_color_override(
			"font_color",
			colors[class_id]
		)

		caption.add_theme_color_override(
			"font_outline_color",
			Color.BLACK
		)

		caption.add_theme_constant_override(
			"outline_size", 3
		)

		add_child(caption)

	func _process(delta: float) -> void:
		if not is_instance_valid(actor):
			queue_free()
			return

		visible = actor.get("is_dead") != true
		pulse += delta * 3.0
		queue_redraw()

	func _draw() -> void:
		if not visible:
			return

		match class_id:
			1:
				draw_arc(
					Vector2.ZERO,
					22.0 + sin(pulse) * 2.0,
					0.0,
					TAU,
					40,
					Color(0.65, 0.32, 1.0, 0.56),
					2.2,
					true
				)

			2:
				draw_arc(
					Vector2.ZERO,
					22.0,
					0.0,
					TAU,
					40,
					Color(1.0, 0.68, 0.18, 0.43),
					2.1,
					true
				)

				if shield_active:
					draw_circle(
						Vector2.ZERO,
						26.0 + sin(pulse * 2.0) * 2.0,
						Color(1.0, 0.75, 0.2, 0.12)
					)

					draw_arc(
						Vector2.ZERO,
						28.0,
						0.0,
						TAU,
						40,
						Color(1.0, 0.88, 0.45, 0.9),
						3.0,
						true
					)


# ==========================================
# ЗАПУСК МЕНЕДЖЕРА
# ==========================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_resize_class_picker)


func _process(delta: float) -> void:
	var main: Node2D = (
		get_tree().get_first_node_in_group("main")
		as Node2D
	)

	if not is_instance_valid(main):
		current_main = null
		return

	# Нова головна сцена — новий матч
	if main != current_main:
		current_main = main

		hero_states.clear()
		slowed_units.clear()

		classes_confirmed = false

		if is_instance_valid(picker_layer):
			picker_layer.queue_free()

		picker_layer = null
		picker_background = null
		picker_center = null
		player_option = null
		bot_option = null

	# ВИПРАВЛЕННЯ:
	# Меню вибору героя створюється незалежно
	# від того, коли створився start_overlay.
	if not classes_confirmed:
		# Якщо стандартне меню з’явилося пізніше, ховаємо його теж.
		_set_difficulty_menu_visible(false)
		if not is_instance_valid(picker_layer):
			_create_class_picker()

		return

	# Під час стартового меню матч зупинений
	if get_tree().paused:
		return

	if main.get("is_match_over") == true:
		return

	_update_slowed(delta)
	_update_heroes(delta)
	_check_skill_projectiles(main)


# ==========================================
# МЕНЮ ВИБОРУ КЛАСІВ
# ==========================================

func _create_class_picker() -> void:
	if is_instance_valid(picker_layer):
		return

	_set_difficulty_menu_visible(false)
	picker_layer = CanvasLayer.new()

	picker_layer.name = "HeroClassSelection"
	picker_layer.layer = 35
	picker_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(picker_layer)

	# Темний фон поверх стартового меню
	var shade := ColorRect.new()

	shade.color = Color(
		0.015,
		0.025,
		0.05,
		0.96
	)

	shade.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	picker_layer.add_child(shade)
	picker_background = shade

	# Центр повинен мати реальні розміри viewport,
	# а не мінімальний розмір дочірньої панелі.
	var center := CenterContainer.new()
	shade.add_child(center)
	picker_center = center
	_resize_class_picker()

	# Основна панель
	var panel := PanelContainer.new()

	panel.custom_minimum_size = Vector2(
		630.0,
		420.0
	)

	var style := StyleBoxFlat.new()

	style.bg_color = Color("#101b2b")
	style.border_color = Color("#4cb9ea")

	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(22)

	panel.add_theme_stylebox_override(
		"panel",
		style
	)

	center.add_child(panel)

	# Вертикальне розташування елементів
	var column := VBoxContainer.new()

	column.add_theme_constant_override(
		"separation",
		12
	)

	panel.add_child(column)

	# Заголовок
	var heading := Label.new()

	heading.text = "MINI-MOBA 1v1"
	heading.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	heading.add_theme_font_size_override(
		"font_size",
		27
	)

	heading.add_theme_color_override(
		"font_color",
		Color("#64d5ff")
	)

	column.add_child(heading)

	var subtitle := Label.new()

	subtitle.text = "ВИБІР КЛАСУ ГЕРОЯ"

	subtitle.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	subtitle.add_theme_font_size_override(
		"font_size",
		17
	)

	subtitle.add_theme_color_override(
		"font_color",
		Color("#f6d365")
	)

	column.add_child(subtitle)

	var help := Label.new()

	help.text = (
		"Обери героя для себе та суперника"
	)

	help.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	column.add_child(help)

	# Вибір гравця
	column.add_child(
		_make_label(
			"ТВІЙ ГЕРОЙ — СИНЯ КОМАНДА"
		)
	)

	player_option = _create_option(
		column,
		int(Engine.get_meta(
			"player_hero_class",
			0
		))
	)

	# Вибір бота
	column.add_child(
		_make_label(
			"ВОРОЖИЙ ГЕРОЙ — ЧЕРВОНА КОМАНДА"
		)
	)

	bot_option = _create_option(
		column,
		int(Engine.get_meta(
			"bot_hero_class",
			0
		))
	)

	# Опис вибраного класу
	var description := Label.new()

	description.name = "ClassDescription"

	description.text = (
		CLASS_NAMES[player_option.selected]
		+ ": "
		+ CLASS_DESCRIPTIONS[player_option.selected]
	)

	description.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	description.custom_minimum_size.y = 44.0

	description.add_theme_color_override(
		"font_color",
		Color("#c7d9e9")
	)

	column.add_child(description)

	player_option.item_selected.connect(
		func(index: int) -> void:
			description.text = (
				CLASS_NAMES[index]
				+ ": "
				+ CLASS_DESCRIPTIONS[index]
			)
	)

	# Кнопка підтвердження
	var start_button := Button.new()

	start_button.text = (
		"ПІДТВЕРДИТИ ГЕРОЇВ"
	)

	start_button.custom_minimum_size.y = 52.0

	start_button.pressed.connect(
		_confirm_classes
	)

	column.add_child(start_button)

	print(
		"HeroClasses: меню вибору героїв відкрито"
	)


# Центруємо меню відносно всього ігрового вікна.
# Під час зміни роздільності розмір перераховується.
func _resize_class_picker() -> void:
	if not is_instance_valid(picker_background):
		return
	if not is_instance_valid(picker_center):
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	picker_background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	picker_background.position = Vector2.ZERO
	picker_background.size = viewport_size
	picker_center.set_anchors_preset(Control.PRESET_TOP_LEFT)
	picker_center.position = Vector2.ZERO
	picker_center.size = viewport_size


# Приховуємо старе меню складності, доки гравець вибирає клас.
func _set_difficulty_menu_visible(show_menu: bool) -> void:
	if not is_instance_valid(current_main):
		return
	var overlay_ref = current_main.get("start_overlay")
	if not is_instance_valid(overlay_ref):
		return
	if overlay_ref is CanvasItem:
		overlay_ref.visible = show_menu


func _make_label(value: String) -> Label:
	var label := Label.new()

	label.text = value

	label.add_theme_color_override(
		"font_color",
		Color("#cbd5e0")
	)

	return label


func _create_option(
	parent: VBoxContainer,
	selected_class: int
) -> OptionButton:

	var option := OptionButton.new()

	option.custom_minimum_size.y = 45.0

	for class_title in CLASS_NAMES:
		option.add_item(class_title)

	option.select(
		clampi(selected_class, 0, 2)
	)

	parent.add_child(option)

	return option


# ==========================================
# ПІДТВЕРДЖЕННЯ ВИБОРУ
# ==========================================

func _confirm_classes() -> void:
	if not is_instance_valid(player_option):
		return

	if not is_instance_valid(bot_option):
		return

	var selected_player: int = (
		player_option.selected
	)

	var selected_bot: int = (
		bot_option.selected
	)

	Engine.set_meta(
		"player_hero_class",
		selected_player
	)

	Engine.set_meta(
		"bot_hero_class",
		selected_bot
	)

	classes_confirmed = true

	print(
		"Вибрано героя: ",
		CLASS_NAMES[selected_player]
	)

	print(
		"Клас бота: ",
		CLASS_NAMES[selected_bot]
	)

	if is_instance_valid(picker_layer):
		picker_layer.queue_free()

	picker_layer = null
	picker_background = null
	picker_center = null
	_set_difficulty_menu_visible(true)

	# Після закриття нашого меню
	# залишається стандартне меню складності.


# ==========================================
# ХАРАКТЕРИСТИКИ КЛАСІВ
# ==========================================

func _update_heroes(delta: float) -> void:
	for unit in get_tree().get_nodes_in_group(
		"heroes"
	):
		if not is_instance_valid(unit):
			continue

		if not (unit is Node2D):
			continue

		var hero: Node2D = unit as Node2D

		if hero.is_queued_for_deletion():
			continue

		var id: int = hero.get_instance_id()

		if not hero_states.has(id):
			var class_id: int = 0

			if int(hero.get("direction")) == 1:
				class_id = int(
					Engine.get_meta(
						"player_hero_class", 0
					)
				)
			else:
				class_id = int(
					Engine.get_meta(
						"bot_hero_class", 0
					)
				)

			class_id = clampi(class_id, 0, 2)

			_apply_class(hero, class_id)

			hero_states[id] = {
				"hero": hero,
				"class": class_id,
				"q_prev": float(hero.get("q_cd")),
				"r_prev": float(hero.get("r_cd")),
				"shield_total": 0.0,
				"shield_left": 0.0,
				"shield_time": 0.0,
				"hp_prev": float(hero.get("hp"))
			}

		var info: Dictionary = hero_states[id]

		_tick_shield(hero, info, delta)

		var q: float = float(hero.get("q_cd"))
		var r: float = float(hero.get("r_cd"))

		if hero.get("is_dead") != true:

			# Воїн: захисний щит Q
			if int(info["class"]) == 2:
				if q > float(info["q_prev"]) + 0.6:
					_start_warrior_shield(
						hero,
						info
					)

			# Маг: контроль від R
			if int(info["class"]) == 1:
				if r > float(info["r_prev"]) + 0.6:
					_apply_mage_ultimate_control(
						hero
					)

		info["q_prev"] = q
		info["r_prev"] = r

		info["hp_prev"] = float(
			hero.get("hp")
		)

		hero_states[id] = info


func _apply_class(
	hero: Node2D,
	class_id: int
) -> void:

	match class_id:

		0:
			# Стрілець — стандартні характеристики
			pass

		1:
			# Маг
			hero.set(
				"max_hp",
				maxf(
					180.0,
					float(hero.get("max_hp")) - 55.0
				)
			)

			hero.set(
				"max_mana",
				float(hero.get("max_mana")) + 130.0
			)

			hero.set(
				"mana_regen",
				float(hero.get("mana_regen")) + 4.0
			)

			hero.set(
				"attack_damage",
				float(hero.get("attack_damage")) - 3.0
			)

			hero.set(
				"spell_amp",
				float(hero.get("spell_amp")) + 0.45
			)

		2:
			# Воїн
			hero.set(
				"max_hp",
				float(hero.get("max_hp")) + 200.0
			)

			hero.set(
				"hp_regen",
				float(hero.get("hp_regen")) + 2.0
			)

			hero.set(
				"attack_damage",
				float(hero.get("attack_damage")) + 8.0
			)

			hero.set(
				"speed",
				float(hero.get("speed")) - 12.0
			)

			hero.set(
				"attack_range",
				185.0
			)

	hero.set(
		"hp",
		float(hero.get("max_hp"))
	)

	hero.set(
		"mana",
		float(hero.get("max_mana"))
	)

	_update_hp_bar(hero)

	hero.queue_redraw()

	# Додаємо маркер класу
	if not hero.has_node("ClassMarker"):
		var marker := ClassMarker.new()

		marker.name = "ClassMarker"
		marker.actor = hero
		marker.class_id = class_id

		hero.add_child(marker)


# ==========================================
# ЗАХИСНИЙ ЩИТ ВОЇНА
# ==========================================

func _start_warrior_shield(
	hero: Node2D,
	info: Dictionary
) -> void:

	var bonus: float = (
		120.0
		+ float(int(hero.get("q_level")) - 1)
		* 25.0
	)

	# Знімаємо залишок попереднього щита
	if float(info["shield_time"]) > 0.0:
		var old_total: float = float(
			info["shield_total"]
		)

		var old_left: float = float(
			info["shield_left"]
		)

		hero.set(
			"max_hp",
			float(hero.get("max_hp")) - old_total
		)

		hero.set(
			"hp",
			maxf(
				0.0,
				float(hero.get("hp")) - old_left
			)
		)

	info["shield_total"] = bonus
	info["shield_left"] = bonus
	info["shield_time"] = 4.0

	hero.set(
		"max_hp",
		float(hero.get("max_hp")) + bonus
	)

	hero.set(
		"hp",
		float(hero.get("hp")) + bonus
	)

	_update_hp_bar(hero)

	var marker: ClassMarker = (
		hero.get_node_or_null("ClassMarker")
		as ClassMarker
	)

	if is_instance_valid(marker):
		marker.shield_active = true

	if hero.has_method("spawn_floating_text"):
		hero.call(
			"spawn_floating_text",
			hero.global_position,
			"ЩИТ +%d" % int(bonus),
			Color("#ffd16a")
		)


func _tick_shield(
	hero: Node2D,
	info: Dictionary,
	delta: float
) -> void:

	if float(info["shield_time"]) <= 0.0:
		return

	var hp_now: float = float(hero.get("hp"))
	var hp_previous: float = float(
		info["hp_prev"]
	)

	if hp_now < hp_previous:
		info["shield_left"] = maxf(
			0.0,
			float(info["shield_left"])
			- (hp_previous - hp_now)
		)

	info["shield_time"] = (
		float(info["shield_time"]) - delta
	)

	if (
		float(info["shield_time"]) <= 0.0
		or hero.get("is_dead") == true
	):
		var new_max: float = (
			float(hero.get("max_hp"))
			- float(info["shield_total"])
		)

		var new_hp: float = (
			float(hero.get("hp"))
			- float(info["shield_left"])
		)

		hero.set("max_hp", new_max)

		hero.set(
			"hp",
			clampf(
				new_hp,
				0.0,
				new_max
			)
		)

		info["shield_total"] = 0.0
		info["shield_left"] = 0.0
		info["shield_time"] = 0.0

		_update_hp_bar(hero)

		var marker: ClassMarker = (
			hero.get_node_or_null("ClassMarker")
			as ClassMarker
		)

		if is_instance_valid(marker):
			marker.shield_active = false


func _update_hp_bar(hero: Node2D) -> void:
	var bar: ColorRect = (
		hero.get_node_or_null("HpBar")
		as ColorRect
	)

	if not is_instance_valid(bar):
		return

	var max_hp: float = maxf(
		1.0,
		float(hero.get("max_hp"))
	)

	bar.size.x = (
		float(hero.get("hp_bar_width"))
		* clampf(
			float(hero.get("hp")) / max_hp,
			0.0,
			1.0
		)
	)


# ==========================================
# Q МАГА — ВИБУХ ПО ПЛОЩІ
# ==========================================

func _check_skill_projectiles(
	main: Node2D
) -> void:

	for node in main.get_children():

		if not (node is Area2D):
			continue

		if node.is_queued_for_deletion():
			continue

		var projectile: Area2D = (
			node as Area2D
		)

		var script: Script = (
			projectile.get_script() as Script
		)

		if script == null:
			continue

		if script.resource_path != "res://projectile.gd":
			continue

		if projectile.get("is_skill") != true:
			continue

		if projectile.has_meta(
			"class_skill_checked"
		):
			continue

		projectile.set_meta(
			"class_skill_checked",
			true
		)

		var caster = projectile.get(
			"owner_unit"
		)

		if not is_instance_valid(caster):
			continue

		var hero_id: int = (
			caster.get_instance_id()
		)

		if not hero_states.has(hero_id):
			continue

		var class_id: int = int(
			hero_states[hero_id]["class"]
		)

		match class_id:
			1:
				# Маг: вибух при контакті
				projectile.body_entered.connect(
					_on_mage_q_hit.bind(
						projectile,
						caster
					)
				)

			2:
				# Воїн: Q — захисний щит
				projectile.queue_free()


func _on_mage_q_hit(
	body: Node2D,
	projectile: Area2D,
	caster: Node2D
) -> void:

	if not is_instance_valid(body):
		return

	if not is_instance_valid(projectile):
		return

	if not is_instance_valid(caster):
		return

	if projectile.has_meta("mage_exploded"):
		return

	if not body.has_method("take_damage"):
		return

	if body.get("direction") == null:
		return

	if int(body.get("direction")) == int(
		caster.get("direction")
	):
		return

	if body.is_in_group("structures"):
		return

	projectile.set_meta(
		"mage_exploded",
		true
	)

	var center: Vector2 = (
		projectile.global_position
	)

	var splash_damage: float = (
		float(projectile.get("damage"))
		* 0.38
	)

	for group in ["creeps", "heroes"]:
		for enemy in get_tree().get_nodes_in_group(
			group
		):
			if not is_instance_valid(enemy):
				continue

			if enemy.is_queued_for_deletion():
				continue

			if enemy == body:
				continue

			if int(enemy.get("direction")) == int(
				caster.get("direction")
			):
				continue

			if enemy.get("is_dead") == true:
				continue

			if float(enemy.get("hp")) <= 0.0:
				continue

			if enemy.global_position.distance_to(
				center
			) <= 82.0:

				if "last_attacker" in enemy:
					enemy.last_attacker = caster

				enemy.take_damage(
					splash_damage
				)

				if is_instance_valid(enemy):
					if not enemy.is_queued_for_deletion():
						_apply_slow(
							enemy,
							0.25,
							1.35
						)

	# Сповільнення основної цілі
	if is_instance_valid(body):
		if not body.is_queued_for_deletion():
			if body.get("speed") != null:
				_apply_slow(
					body,
					0.25,
					1.35
				)

	var main: Node2D = (
		get_tree().get_first_node_in_group(
			"main"
		) as Node2D
	)

	if is_instance_valid(main):
		if main.has_method(
			"spawn_hit_effect"
		):
			main.spawn_hit_effect(
				center,
				Color("#b684ff"),
				80.0,
				14
			)


# ==========================================
# R МАГА — КОНТРОЛЬ ПО ПЛОЩІ
# ==========================================

func _apply_mage_ultimate_control(
	hero: Node2D
) -> void:

	var blast_pos: Vector2 = (
		hero.global_position
	)

	var effects = hero.get("active_effects")

	if effects is Array:
		for i in range(
			effects.size() - 1,
			-1,
			-1
		):
			var effect: Dictionary = (
				effects[i]
			)

			if str(effect.get("type", "")) == "blast":
				blast_pos = effect["pos"]
				break

	for group in ["creeps", "heroes"]:
		for enemy in get_tree().get_nodes_in_group(
			group
		):
			if not is_instance_valid(enemy):
				continue

			if enemy.is_queued_for_deletion():
				continue

			if enemy == hero:
				continue

			if enemy.get("direction") == null:
				continue

			if int(enemy.get("direction")) == int(
				hero.get("direction")
			):
				continue

			if enemy.get("is_dead") == true:
				continue

			if float(enemy.get("hp")) <= 0.0:
				continue

			if enemy.global_position.distance_to(
				blast_pos
			) <= 170.0:

				_apply_slow(
					enemy,
					0.32,
					1.8
				)


# ==========================================
# ТИМЧАСОВІ СПОВІЛЬНЕННЯ
# ==========================================

func _apply_slow(
	unit: Node2D,
	factor: float,
	duration: float
) -> void:

	# Ефект може спрацювати під час знищення кріпа.
	if not is_instance_valid(unit):
		return
	if unit.is_queued_for_deletion():
		return

	if unit.get("speed") == null:
		return

	var id: int = unit.get_instance_id()

	if slowed_units.has(id):
		var old: Dictionary = (
			slowed_units[id]
		)

		unit.set(
			"speed",
			float(unit.get("speed"))
			+ float(old["reduction"])
		)

	var reduction: float = (
		float(unit.get("speed"))
		* factor
	)

	unit.set(
		"speed",
		float(unit.get("speed"))
		- reduction
	)

	slowed_units[id] = {
		"unit": unit,
		"reduction": reduction,
		"time": duration
	}


func _update_slowed(delta: float) -> void:
	for id in slowed_units.keys():
		var info: Dictionary = (
			slowed_units[id]
		)

		# Спочатку перевіряємо Variant, а вже потім приводимо до Node2D.
		# Приведення звільненого об'єкта викликало "Trying to cast a freed object".
		var unit_ref = info.get("unit", null)
		if not is_instance_valid(unit_ref):
			slowed_units.erase(id)
			continue
		if not (unit_ref is Node2D):
			slowed_units.erase(id)
			continue
		var unit: Node2D = unit_ref as Node2D
		if unit.is_queued_for_deletion():
			slowed_units.erase(id)
			continue

		info["time"] = (
			float(info["time"]) - delta
		)

		if float(info["time"]) <= 0.0:
			unit.set(
				"speed",
				float(unit.get("speed"))
				+ float(info["reduction"])
			)

			slowed_units.erase(id)
		else:
			slowed_units[id] = info
