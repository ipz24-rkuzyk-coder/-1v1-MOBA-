extends Node2D

const CREEP_SCENE = preload("res://creep.tscn")

func _ready() -> void:
	$WaveTimer.timeout.connect(spawn_wave)
	spawn_wave() # Перша хвиля виходить одразу на старті матчу

func spawn_wave() -> void:
	var offsets := [-35.0, 0.0, 35.0]
	for y_offset in offsets:
		# Синій крип гравця (виходить перед синім Троном і йде вправо)
		var blue_creep := CREEP_SCENE.instantiate()
		blue_creep.direction = 1
		blue_creep.position = Vector2(245, 324 + y_offset)
		add_child(blue_creep)

		# Червоний крип бота (виходить перед червоним Троном і йде вліво)
		var red_creep := CREEP_SCENE.instantiate()
		red_creep.direction = -1
		red_creep.position = Vector2(2555, 324 + y_offset)
		add_child(red_creep)
