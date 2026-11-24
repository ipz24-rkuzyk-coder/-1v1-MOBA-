
extends Node

# Mini-MOBA 1v1 — мальовані герої (Godot 4)
# Підключити через Autoload як HeroVisuals.
# Не змінює характеристики, колізії та бойові скрипти.

const SCAN_INTERVAL: float = 0.25
var scan_timer: float = 0.0


class HeroAppearance:
	extends Node2D

	var actor: CharacterBody2D
	var aim_angle: float = 0.0
	var walk_phase: float = 0.0
	var recoil: float = 0.0
	var q_flash: float = 0.0
	var e_flash: float = 0.0
	var r_flash: float = 0.0
	var old_attack: float = 0.0
	var old_q: float = 0.0
	var old_e: float = 0.0
	var old_r: float = 0.0

	func _ready() -> void:
		z_index = 2
		if is_instance_valid(actor):
			old_attack = float(actor.get("cooldown_timer"))
			old_q = float(actor.get("q_cd"))
			old_e = float(actor.get("e_cd"))
			old_r = float(actor.get("r_cd"))
			aim_angle = 0.0 if int(actor.get("direction")) == 1 else PI

	func _process(delta: float) -> void:
		if not is_instance_valid(actor):
			queue_free()
			return

		visible = actor.get("is_dead") != true
		if not visible:
			return

		var heading: Vector2 = Vector2.RIGHT
		if int(actor.get("direction")) == -1:
			heading = Vector2.LEFT
			for other in get_tree().get_nodes_in_group("heroes"):
				if not is_instance_valid(other) or other == actor:
					continue
				if int(other.get("direction")) == 1 and other.get("is_dead") != true:
					var toward: Vector2 = other.global_position - actor.global_position
					if toward.length_squared() < 650.0 * 650.0:
						heading = toward
						break
		else:
			heading = actor.get_global_mouse_position() - actor.global_position

		if heading.length_squared() > 1.0:
			aim_angle = lerp_angle(aim_angle, heading.angle(), clampf(delta * 14.0, 0.0, 1.0))

		if actor.velocity.length() > 5.0:
			walk_phase += delta * 12.0
		else:
			walk_phase += delta * 1.8

		recoil = maxf(0.0, recoil - delta * 5.0)
		q_flash = maxf(0.0, q_flash - delta)
		e_flash = maxf(0.0, e_flash - delta)
		r_flash = maxf(0.0, r_flash - delta)

		var attack: float = float(actor.get("cooldown_timer"))
		var q: float = float(actor.get("q_cd"))
		var e: float = float(actor.get("e_cd"))
		var r: float = float(actor.get("r_cd"))

		if attack > old_attack + 0.12:
			recoil = 1.0
		if q > old_q + 0.35:
			q_flash = 0.32
			recoil = 1.0
		if e > old_e + 0.35:
			e_flash = 0.40
		if r > old_r + 0.35:
			r_flash = 0.85

		old_attack = attack
		old_q = q
		old_e = e
		old_r = r
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(actor) or actor.get("is_dead") == true:
			return

		var blue: bool = int(actor.get("direction")) == 1
		var armor: Color = Color("#214e76") if blue else Color("#6d2935")
		var shade: Color = Color("#10273a") if blue else Color("#35151e")
		var accent: Color = Color("#35caff") if blue else Color("#ff5c54")
		var highlight: Color = Color("#a6ebff") if blue else Color("#ffac81")
		var metal: Color = Color("#9baec4") if blue else Color("#b8a4a0")
		var movement: float = clampf(actor.velocity.length() / 200.0, 0.0, 1.0)
		var sway: float = sin(walk_phase) * movement
		var bob: float = absf(sway) * -1.8

		# Тінь і маркер команди під ногами
		draw_circle(Vector2(0.0, 12.0), 19.0, Color(0.02, 0.03, 0.06, 0.22))
		draw_arc(Vector2(0.0, 9.0), 19.0, 0.0, TAU, 32, accent.darkened(0.22), 1.7, true)

		# Аура активної руни (за наявності RuneSystem)
		var runes: Node = get_node_or_null("/root/RuneSystem")
		if is_instance_valid(runes):
			var speed_buffs = runes.get("speed_buffs")
			var damage_buffs = runes.get("damage_buffs")
			var id: int = actor.get_instance_id()
			if speed_buffs is Dictionary and speed_buffs.has(id):
				draw_arc(Vector2.ZERO, 26.0 + sin(walk_phase) * 2.0, 0.0, TAU, 36, Color(1.0, 0.86, 0.25, 0.75), 2.5, true)
			if damage_buffs is Dictionary and damage_buffs.has(id):
				draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 36, Color(1.0, 0.25, 0.19, 0.83), 2.5, true)

		draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)

		# Плащ за спиною і рухомі броньовані чоботи
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12.0, 1.0), Vector2(12.0, 1.0),
			Vector2(9.0 - sway * 2.0, 21.0), Vector2(-11.0 - sway * 2.0, 21.0)
		]), shade)
		draw_rect(Rect2(-14.0, 8.0 + sway * 2.2, 10.0, 10.0), metal.darkened(0.35))
		draw_rect(Rect2(4.0, 8.0 - sway * 2.2, 10.0, 10.0), metal.darkened(0.35))
		draw_rect(Rect2(-15.0, 13.0 + sway * 2.2, 12.0, 5.0), shade)
		draw_rect(Rect2(3.0, 13.0 - sway * 2.2, 12.0, 5.0), shade)

		# Бронежилет із зовнішньою окантовкою
		draw_colored_polygon(PackedVector2Array([
			Vector2(-14.0, -12.0), Vector2(14.0, -12.0),
			Vector2(15.0, 7.0), Vector2(9.0, 13.0),
			Vector2(-9.0, 13.0), Vector2(-15.0, 7.0)
		]), shade)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-11.0, -10.0), Vector2(11.0, -10.0),
			Vector2(12.0, 5.0), Vector2(7.0, 10.0),
			Vector2(-7.0, 10.0), Vector2(-12.0, 5.0)
		]), armor)
		draw_line(Vector2(-9.0, 1.0), Vector2(9.0, 1.0), metal, 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-5.0, -2.0), Vector2(5.0, -2.0),
			Vector2(4.0, 5.0), Vector2(-4.0, 5.0)
		]), accent)

		# Плечові пластини
		draw_circle(Vector2(-15.0, -7.0), 7.0, shade)
		draw_circle(Vector2(15.0, -7.0), 7.0, shade)
		draw_rect(Rect2(-20.0, -12.0, 9.0, 8.0), armor)
		draw_rect(Rect2(11.0, -12.0, 9.0, 8.0), armor)
		draw_line(Vector2(-19.0, -11.0), Vector2(-13.0, -11.0), accent, 1.5)
		draw_line(Vector2(13.0, -11.0), Vector2(19.0, -11.0), accent, 1.5)

		# Шолом, візор, антена
		draw_circle(Vector2(0.0, -14.0), 11.5, shade)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9.0, -20.0), Vector2(0.0, -25.0),
			Vector2(9.0, -20.0), Vector2(10.0, -10.0),
			Vector2(-10.0, -10.0)
		]), metal.darkened(0.20))
		draw_rect(Rect2(-9.0, -17.0, 18.0, 5.0), shade)
		draw_line(Vector2(-7.0, -14.5), Vector2(7.0, -14.5), highlight, 3.0, true)
		draw_line(Vector2(0.0, -24.0), Vector2(0.0, -28.0), accent, 1.5)
		draw_circle(Vector2(0.0, -29.0), 2.0, accent)

		# Зброя повертається до курсора / суперника
		draw_set_transform(Vector2(0.0, bob - 3.0), aim_angle, Vector2.ONE)
		draw_rect(Rect2(-3.0 - recoil * 4.0, -5.0, 19.0, 10.0), shade)
		draw_rect(Rect2(5.0 - recoil * 4.0, -3.0, 24.0, 6.0), metal)
		draw_rect(Rect2(19.0 - recoil * 4.0, -4.5, 10.0, 9.0), armor)
		draw_line(Vector2(8.0, -2.0), Vector2(24.0, -2.0), accent, 1.8)
		draw_circle(Vector2(2.0 - recoil * 3.0, 0.0), 5.0, armor.lightened(0.30))
		if recoil > 0.05:
			draw_circle(Vector2(31.0, 0.0), 6.0 * recoil, Color(accent.r, accent.g, accent.b, recoil))
			draw_line(Vector2(28.0, 0.0), Vector2(38.0 + recoil * 5.0, 0.0), highlight, 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Анімації здібностей
		if q_flash > 0.0:
			var q_alpha: float = q_flash / 0.32
			draw_arc(Vector2.ZERO, 25.0 + (1.0 - q_alpha) * 12.0, 0.0, TAU, 36, Color(accent.r, accent.g, accent.b, q_alpha), 3.0, true)
		if e_flash > 0.0:
			var e_alpha: float = e_flash / 0.40
			draw_arc(Vector2.ZERO, 32.0 * (1.4 - e_alpha * 0.4), 0.0, TAU, 36, Color(0.5, 0.9, 1.0, e_alpha * 0.8), 3.0, true)
		if r_flash > 0.0:
			var r_alpha: float = r_flash / 0.85
			draw_arc(Vector2.ZERO, 26.0 + (1.0 - r_alpha) * 35.0, 0.0, TAU, 48, Color(0.82, 0.58, 1.0, r_alpha * 0.8), 4.0, true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	scan_timer -= delta
	if scan_timer > 0.0:
		return
	scan_timer = SCAN_INTERVAL

	for node in get_tree().get_nodes_in_group("heroes"):
		if not (node is CharacterBody2D):
			continue
		var hero: CharacterBody2D = node as CharacterBody2D
		if hero.has_node("HeroAppearance"):
			continue

		var original: CanvasItem = hero.get_node_or_null("ColorRect") as CanvasItem
		if is_instance_valid(original):
			original.visible = false

		var hp_bar: Control = hero.get_node_or_null("HpBar") as Control
		if is_instance_valid(hp_bar):
			hp_bar.position.y = -29.0
			hp_bar.z_index = 5

		var skin := HeroAppearance.new()
		skin.name = "HeroAppearance"
		skin.actor = hero
		hero.add_child(skin)
