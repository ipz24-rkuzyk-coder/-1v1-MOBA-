extends Node

# Mini-MOBA 1v1 — class-specific ability HUD.
# Autoload name: ClassHUD
# Only decorates existing Q/E/R panels; never changes combat logic.

const SCAN_INTERVAL: float = 0.20
const PANEL_WIDTH: float = 174.0
const PANEL_HEIGHT: float = 97.0

const CLASS_SKILLS = [
	[
		{"name": "Залп", "desc": "Плазмовий залп зі зброї Стрільця.", "cost": 35},
		{"name": "Блінк", "desc": "Ривок, після якого Стрілець ненадовго прискорюється.", "cost": 40},
		{"name": "Орбіт. удар", "desc": "Дистанційний орбітальний удар по площі.", "cost": 80}
	],
	[
		{"name": "Магічна сфера", "desc": "Магічний снаряд. Q також вражає ворогів поруч і сповільнює їх.", "cost": 35},
		{"name": "Містичний стрибок", "desc": "Телепортація, яка створює поле сповільнення біля Мага.", "cost": 40},
		{"name": "Чарівний вибух", "desc": "Удар по площі з додатковим сповільненням ворогів.", "cost": 80}
	],
	[
		{"name": "Захисний щит", "desc": "Створює тимчасовий запас захисту на 4 секунди.", "cost": 35},
		{"name": "Бойовий ривок", "desc": "Ривок Воїна з ударною хвилею поблизу місця прибуття.", "cost": 40},
		{"name": "Ударна хвиля", "desc": "Удар по площі з потужним сповільненням супротивників.", "cost": 80}
	]
]

const CLASS_COLORS = [
	Color("#44cfff"),
	Color("#bf8dff"),
	Color("#f4c369")
]

var scan_timer: float = 0.0
var active_hero: Node2D = null
var active_class: int = -1


class SkillGlyph:
	extends Control

	var hero_class: int = 0
	var skill_index: int = 0
	var accent: Color = Color("#44cfff")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(25.0, 25.0)

	func configure(next_class: int, next_skill: int, next_color: Color) -> void:
		hero_class = next_class
		skill_index = next_skill
		accent = next_color
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		draw_circle(c, 11.5, Color("#101725"))
		draw_arc(c, 11.0, 0.0, TAU, 32, accent, 1.6, true)

		match hero_class:
			0: # Стрілець: залп, ривок, приціл
				match skill_index:
					0:
						for y in [-4.0, 0.0, 4.0]:
							draw_line(c + Vector2(-6.0, y), c + Vector2(6.0, y), accent, 2.0, true)
							draw_circle(c + Vector2(7.0, y), 1.2, Color.WHITE)
					1:
						for x in [-4.0, 2.0]:
							draw_line(c + Vector2(x - 2.0, -5.0), c + Vector2(x + 3.0, 0.0), accent, 2.0, true)
							draw_line(c + Vector2(x + 3.0, 0.0), c + Vector2(x - 2.0, 5.0), accent, 2.0, true)
					2:
						draw_arc(c, 6.0, 0.0, TAU, 24, accent, 1.8, true)
						draw_line(c + Vector2(-9.0, 0.0), c + Vector2(9.0, 0.0), accent, 1.2)
						draw_line(c + Vector2(0.0, -9.0), c + Vector2(0.0, 9.0), accent, 1.2)
			1: # Маг: кристал, портал, вибух
				match skill_index:
					0:
						draw_colored_polygon(PackedVector2Array([
							c + Vector2(0.0, -7.0), c + Vector2(6.0, 0.0),
							c + Vector2(0.0, 7.0), c + Vector2(-6.0, 0.0)
						]), accent)
					1:
						draw_arc(c, 7.0, -PI * 0.78, PI * 0.78, 24, accent, 2.2, true)
						draw_circle(c + Vector2(3.0, 0.0), 2.5, Color.WHITE)
					2:
						for i in range(8):
							var a: float = TAU * float(i) / 8.0
							draw_line(c + Vector2.from_angle(a) * 3.0, c + Vector2.from_angle(a) * 9.0, accent, 1.7, true)
							draw_circle(c, 3.0, Color.WHITE)
			2: # Воїн: щит, меч, ударна хвиля
				match skill_index:
					0:
						draw_colored_polygon(PackedVector2Array([
							c + Vector2(-6.0, -7.0), c + Vector2(6.0, -7.0),
							c + Vector2(5.0, 3.0), c + Vector2(0.0, 8.0),
							c + Vector2(-5.0, 3.0)
						]), accent)
						draw_line(c + Vector2(0.0, -5.0), c + Vector2(0.0, 5.0), Color("#493416"), 1.6)
					1:
						draw_line(c + Vector2(-6.0, 6.0), c + Vector2(6.0, -6.0), accent, 3.1, true)
						draw_line(c + Vector2(-6.0, 1.0), c + Vector2(-1.0, 6.0), Color.WHITE, 1.6, true)
					2:
						for r in [3.0, 6.5]:
							draw_arc(c, r, 0.0, TAU, 24, accent, 1.8, true)
						draw_line(c + Vector2(-8.0, 8.0), c + Vector2(8.0, -8.0), Color.WHITE, 1.2, true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 120


func _process(delta: float) -> void:
	scan_timer -= delta
	if scan_timer > 0.0:
		return
	scan_timer = SCAN_INTERVAL

	var hero: Node2D = _find_player_hero()
	if not is_instance_valid(hero):
		active_hero = null
		active_class = -1
		return

	var panels = hero.get("skill_panels")
	if not (panels is Array) or panels.size() < 3:
		return

	var class_id: int = clampi(int(Engine.get_meta("player_hero_class", 0)), 0, 2)
	var marker: Node = hero.get_node_or_null("ClassMarker")
	if is_instance_valid(marker):
		class_id = clampi(int(marker.get("class_id")), 0, 2)

	if hero != active_hero or class_id != active_class or not _has_custom_hud(panels):
		_update_class_hud(hero, panels, class_id)
		active_hero = hero
		active_class = class_id


func _find_player_hero() -> Node2D:
	for unit in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(unit):
			continue
		if unit.is_queued_for_deletion():
			continue
		if not (unit is Node2D):
			continue
		if unit.get("direction") == null:
			continue
		if int(unit.get("direction")) != 1:
			continue
		# Only the real player has the skill_panels HUD array.
		if unit.get("skill_panels") is Array:
			return unit as Node2D
	return null


func _has_custom_hud(panels: Array) -> bool:
	for i in range(3):
		var panel: PanelContainer = panels[i] as PanelContainer
		if not is_instance_valid(panel):
			return false
		if panel.get_child_count() == 0:
			return false
		var vbox: VBoxContainer = panel.get_child(0) as VBoxContainer
		if not is_instance_valid(vbox) or not vbox.has_node("ClassSkillRow"):
			return false
	return true


func _update_class_hud(_hero: Node2D, panels: Array, class_id: int) -> void:
	for i in range(3):
		var panel: PanelContainer = panels[i] as PanelContainer
		if not is_instance_valid(panel) or panel.get_child_count() == 0:
			continue
		var vbox: VBoxContainer = panel.get_child(0) as VBoxContainer
		if not is_instance_valid(vbox):
			continue

		var row: HBoxContainer = vbox.get_node_or_null("ClassSkillRow") as HBoxContainer
		if not is_instance_valid(row):
			var original_title: Label = null
			for child in vbox.get_children():
				if child is Label and str(child.text).begins_with("["):
					original_title = child as Label
					break
			if not is_instance_valid(original_title):
				continue

			vbox.remove_child(original_title)
			row = HBoxContainer.new()
			row.name = "ClassSkillRow"
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 4)
			vbox.add_child(row)
			vbox.move_child(row, 1)

			var glyph := SkillGlyph.new()
			glyph.name = "SkillGlyph"
			row.add_child(glyph)
			row.add_child(original_title)
			original_title.name = "SkillTitle"
			original_title.add_theme_font_size_override("font_size", 10)
			original_title.clip_text = true

			var mana_label := Label.new()
			mana_label.name = "SkillManaCost"
			mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mana_label.add_theme_font_size_override("font_size", 10)
			mana_label.add_theme_color_override("font_color", Color("#a4b7ce"))
			vbox.add_child(mana_label)
			vbox.move_child(mana_label, 2)

		panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
		var record: Dictionary = CLASS_SKILLS[class_id][i]
		var color: Color = CLASS_COLORS[class_id]
		var title: Label = row.get_node_or_null("SkillTitle") as Label
		var icon: SkillGlyph = row.get_node_or_null("SkillGlyph") as SkillGlyph
		var mana: Label = vbox.get_node_or_null("SkillManaCost") as Label

		var key: String = ["Q", "E", "R"][i]
		var description: String = "%s — %s\n%d MP\n%s" % [key, record["name"], record["cost"], record["desc"]]
		if is_instance_valid(title):
			title.text = "%s · %s" % [key, record["name"]]
			title.add_theme_color_override("font_color", color)
			title.tooltip_text = description
		if is_instance_valid(icon):
			icon.configure(class_id, i, color)
		if is_instance_valid(mana):
			mana.text = "%d MP" % record["cost"]
			mana.tooltip_text = description

		panel.tooltip_text = description
		var upgrade: Button = vbox.get_child(0) as Button
		if is_instance_valid(upgrade):
			upgrade.tooltip_text = description

	print("ClassHUD: оновлено Q/E/R для класу %d" % class_id)
