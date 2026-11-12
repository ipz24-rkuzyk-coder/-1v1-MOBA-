extends Node2D

const CREEP_SCENE = preload("res://creep.tscn")

func _ready() -> void:
	$WaveTimer.timeout.connect(spawn_wave)
	$PlayerThrone.throne_destroyed.connect(_on_throne_destroyed)
	$BotThrone.throne_destroyed.connect(_on_throne_destroyed)
	
	# Налаштування екрану кінця матчу
	var vp_size := get_viewport_rect().size
	$CanvasLayer/EndScreen.visible = false
	$CanvasLayer/EndScreen.color = Color(0, 0, 0, 0.75)
	$CanvasLayer/EndScreen.size = vp_size
	
	$CanvasLayer/EndScreen/ResultLabel.size = Vector2(400, 80)
	$CanvasLayer/EndScreen/ResultLabel.position = Vector2(vp_size.x / 2.0 - 200.0, vp_size.y / 2.0 - 110.0)
	$CanvasLayer/EndScreen/ResultLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$CanvasLayer/EndScreen/ResultLabel.add_theme_font_size_override("font_size", 48)
	
	$CanvasLayer/EndScreen/RestartButton.text = "Грати знову"
	$CanvasLayer/EndScreen/RestartButton.size = Vector2(200, 50)
	$CanvasLayer/EndScreen/RestartButton.position = Vector2(vp_size.x / 2.0 - 100.0, vp_size.y / 2.0)
	$CanvasLayer/EndScreen/RestartButton.pressed.connect(_on_restart_pressed)
	
	spawn_wave()

func spawn_wave() -> void:
	var offsets := [-35.0, 0.0, 35.0]
	for y_offset in offsets:
		var blue_creep := CREEP_SCENE.instantiate()
		blue_creep.direction = 1
		blue_creep.position = Vector2(245, 324 + y_offset)
		add_child(blue_creep)

		var red_creep := CREEP_SCENE.instantiate()
		red_creep.direction = -1
		red_creep.position = Vector2(2555, 324 + y_offset)
		add_child(red_creep)

func _on_throne_destroyed(losing_team: int) -> void:
	$WaveTimer.stop()
	$CanvasLayer/EndScreen.visible = true
	if losing_team == -1:
		$CanvasLayer/EndScreen/ResultLabel.text = "ПЕРЕМОГА!"
		$CanvasLayer/EndScreen/ResultLabel.modulate = Color("#48bb78")
	else:
		$CanvasLayer/EndScreen/ResultLabel.text = "ПОРАЗКА!"
		$CanvasLayer/EndScreen/ResultLabel.modulate = Color("#f56565")

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
