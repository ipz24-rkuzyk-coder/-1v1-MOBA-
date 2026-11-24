extends Node

# Mini-MOBA 1v1 — Головне меню та налаштування (Godot 4)
# Autoload: GameMenu
# Не змінює hero_classes.gd та старе меню складності.

const SETTINGS_PATH: String = "user://mini_moba_settings.cfg"

var tracked_main: Node2D = null
var menu_layer: CanvasLayer
var background: ColorRect
var home_panel: PanelContainer
var settings_panel: PanelContainer
var volume_slider: HSlider
var volume_value_label: Label
var fullscreen_check: CheckButton

var volume_value: float = 0.80
var fullscreen_enabled: bool = false
var opened_from_game: bool = false
var pause_before_settings: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_audio()
	_apply_fullscreen()
	_build_ui()
	get_viewport().size_changed.connect(_resize_menu)
	_resize_menu()
	menu_layer.visible = false


func _process(_delta: float) -> void:
	var main: Node2D = get_tree().get_first_node_in_group("main") as Node2D

	if not is_instance_valid(main):
		tracked_main = null
		if is_instance_valid(menu_layer):
			menu_layer.visible = false
		return

	# При кожному новому матчі показуємо головне меню.
	if not is_instance_valid(tracked_main) or tracked_main != main:
		tracked_main = main
		opened_from_game = false
		_show_home()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	# F11: повноекранний / віконний режим у будь-який момент.
	if key.keycode == KEY_F11:
		_set_fullscreen(not fullscreen_enabled)
		get_viewport().set_input_as_handled()

	# F10: налаштування під час матчу.
	elif key.keycode == KEY_F10 and is_instance_valid(tracked_main):
		if menu_layer.visible:
			if settings_panel.visible and opened_from_game:
				_on_settings_back()
			elif home_panel.visible:
				_open_settings(false)
		else:
			_open_settings(true)
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "GameMenuLayer"
	menu_layer.layer = 60 # Поверх вибору героїв (35) та складності (20).
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_layer)

	background = ColorRect.new()
	background.name = "MenuBackground"
	background.color = Color("#09101bef")
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(background)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "CenteredContent"
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	background.add_child(center)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

	home_panel = _make_panel(Color("#47c7ed"))
	center.add_child(home_panel)
	_build_home_panel(home_panel)

	settings_panel = _make_panel(Color("#c49bff"))
	center.add_child(settings_panel)
	_build_settings_panel(settings_panel)
	settings_panel.hide()


func _resize_menu() -> void:
	# Центруємо відносно ігрового viewport навіть після F11.
	if not is_instance_valid(background):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	background.position = Vector2.ZERO
	background.size = viewport_size
	var center: CenterContainer = background.get_node_or_null("CenteredContent") as CenterContainer
	if is_instance_valid(center):
		center.position = Vector2.ZERO
		center.size = viewport_size


func _make_panel(outline: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 380.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101b2cf8")
	style.border_color = outline
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_heading(value: String, size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", tint)
	label.add_theme_font_size_override("font_size", size)
	return label


func _make_button(value: String, border_tint: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 52)
	button.focus_mode = Control.FOCUS_NONE

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#1d2d41")
	normal.border_color = border_tint.darkened(0.30)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	normal.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#2b4560")
	hover.border_color = border_tint
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button


func _build_home_panel(panel: PanelContainer) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 15)
	panel.add_child(col)

	col.add_child(_make_heading("MINI-MOBA 1v1", 32, Color("#78dfff")))
	col.add_child(_make_heading("АРЕНА ТРЬОХ КЛАСІВ", 15, Color("#e6c475")))

	var description := _make_heading(
		"Стрілець  •  Маг  •  Воїн\nЗахисти свій Трон та знищ ворожий!",
		14, Color("#bcd0e6")
	)
	col.add_child(description)

	var play_button := _make_button("ГРАТИ", Color("#49d5f7"))
	play_button.pressed.connect(_on_play_pressed)
	col.add_child(play_button)

	var options_button := _make_button("НАЛАШТУВАННЯ", Color("#bd99ff"))
	options_button.pressed.connect(func() -> void: _open_settings(false))
	col.add_child(options_button)

	var exit_button := _make_button("ВИХІД ІЗ ГРИ", Color("#f07878"))
	exit_button.pressed.connect(_on_exit_pressed)
	col.add_child(exit_button)

	col.add_child(_make_heading(
		"Після «Грати» обери клас героя, клас бота та складність.",
		12, Color("#8da8c1")
	))


func _build_settings_panel(panel: PanelContainer) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	col.add_child(_make_heading("НАЛАШТУВАННЯ", 27, Color("#d2b6ff")))
	col.add_child(_make_heading("ЗВУК", 15, Color("#d5e6f5")))

	volume_value_label = _make_heading("Гучність: 80%", 14, Color("#bed3e5"))
	col.add_child(volume_value_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.custom_minimum_size = Vector2(0, 30)
	volume_slider.value = volume_value
	volume_slider.value_changed.connect(_on_volume_changed)
	col.add_child(volume_slider)
	_update_volume_text()

	col.add_child(_make_heading("ЗОБРАЖЕННЯ", 15, Color("#d5e6f5")))

	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Повний екран (F11)"
	fullscreen_check.button_pressed = fullscreen_enabled
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	col.add_child(fullscreen_check)

	var hint := _make_heading(
		"F10 — налаштування під час матчу\nF11 — перемикання повного екрана",
		13, Color("#96abc0")
	)
	col.add_child(hint)

	var back_button := _make_button("НАЗАД", Color("#bd99ff"))
	back_button.pressed.connect(_on_settings_back)
	col.add_child(back_button)


# ==========================================
# ПОКАЗ МЕНЮ / ПЕРЕХІД ДО ВИБОРУ КЛАСІВ
# ==========================================

func _show_home() -> void:
	opened_from_game = false
	settings_panel.hide()
	home_panel.show()
	menu_layer.show()


func _on_play_pressed() -> void:
	# HeroClasses вже показує вибір героїв під цим меню.
	# Не змінюємо pause: його контролює стартове меню main.gd.
	menu_layer.hide()


func _open_settings(from_game: bool) -> void:
	opened_from_game = from_game
	if from_game:
		pause_before_settings = get_tree().paused
		get_tree().paused = true
	else:
		pause_before_settings = true

	home_panel.hide()
	settings_panel.show()
	menu_layer.show()


func _on_settings_back() -> void:
	if opened_from_game:
		settings_panel.hide()
		menu_layer.hide()
		opened_from_game = false
		get_tree().paused = pause_before_settings
	else:
		_show_home()


func _on_exit_pressed() -> void:
	_save_settings()
	get_tree().quit()


# ==========================================
# ЗВУК / ПОВНИЙ ЕКРАН / ЗБЕРЕЖЕННЯ
# ==========================================

func _on_volume_changed(value: float) -> void:
	volume_value = clampf(value, 0.0, 1.0)
	_apply_audio()
	_update_volume_text()
	_save_settings()


func _apply_audio() -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus < 0:
		return
	AudioServer.set_bus_mute(master_bus, volume_value <= 0.001)
	AudioServer.set_bus_volume_db(
		master_bus,
		linear_to_db(maxf(0.001, volume_value))
	)


func _update_volume_text() -> void:
	if is_instance_valid(volume_value_label):
		volume_value_label.text = "Гучність: %d%%" % int(round(volume_value * 100.0))


func _on_fullscreen_toggled(enabled: bool) -> void:
	_set_fullscreen(enabled)


func _set_fullscreen(enabled: bool) -> void:
	fullscreen_enabled = enabled
	_apply_fullscreen()
	if is_instance_valid(fullscreen_check):
		fullscreen_check.set_pressed_no_signal(enabled)
	_save_settings()


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if fullscreen_enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	volume_value = clampf(
		float(config.get_value("audio", "master", 0.80)),
		0.0, 1.0
	)
	fullscreen_enabled = bool(config.get_value("display", "fullscreen", false))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", volume_value)
	config.set_value("display", "fullscreen", fullscreen_enabled)
	var result: Error = config.save(SETTINGS_PATH)
	if result != OK:
		push_warning("GameMenu: не вдалося зберегти налаштування")
