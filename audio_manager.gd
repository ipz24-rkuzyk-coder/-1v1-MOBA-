
extends Node

# Mini-MOBA 1v1
# Battle Audio System V3
# Унікальні звуки для героїв, кріпів, веж і катапульт

const SAMPLE_RATE: int = 24000
const AUDIO_DISTANCE: float = 850.0
const PLAYER_COUNT: int = 20
const MASTER_VOLUME_DB: float = -3.0

const SOUND_TYPES: Array[String] = [
	"player_attack",
	"bot_attack",
	"creep_blue",
	"creep_red",
	"tower_attack",
	"throne_attack",
	"catapult_attack",
	"player_crit",
	"bot_crit",
	"q_blue",
	"q_red",
	"e_blue",
	"e_red",
	"r_blue",
	"r_red",
	"coin",
	"shop",
	"level",
	"throne_break"
]

var sound_bank: Dictionary = {}
var audio_players: Array[AudioStreamPlayer] = []

var next_player: int = 0

var current_main: Node2D = null

var known_projectiles: Dictionary = {}
var creep_states: Dictionary = {}
var structure_states: Dictionary = {}
var hero_states: Dictionary = {}
var last_played: Dictionary = {}

var match_finished: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Створюємо три варіанти кожного звуку
	for kind in SOUND_TYPES:
		var variants: Array[AudioStreamWAV] = []

		for variant in range(3):
			variants.append(
				_generate_sound(kind, variant)
			)

		sound_bank[kind] = variants

	# Пул звукових програвачів
	for i in range(PLAYER_COUNT):
		var audio := AudioStreamPlayer.new()

		audio.name = "BattleSFX_%02d" % i
		audio.process_mode = Node.PROCESS_MODE_ALWAYS
		audio.volume_db = -12.0

		add_child(audio)
		audio_players.append(audio)

	print("Battle Audio V3: звуки завантажено")


func _process(_delta: float) -> void:
	var main: Node2D = (
		get_tree().get_first_node_in_group("main")
		as Node2D
	)

	if not is_instance_valid(main):
		current_main = null
		return

	# Новий матч
	if main != current_main:
		current_main = main

		known_projectiles.clear()
		creep_states.clear()
		structure_states.clear()
		hero_states.clear()
		last_played.clear()

		match_finished = false

	# Фінальний звук
	if main.get("is_match_over") == true:
		if not match_finished:
			match_finished = true
			_play_sound("throne_break")
		return

	if get_tree().paused:
		return

	_check_projectiles(main)
	_check_creeps()
	_check_structures()
	_check_heroes()


# ==========================================
# ПОСТРІЛИ ГЕРОЇВ ТА КАТАПУЛЬТ
# ==========================================

func _check_projectiles(main: Node2D) -> void:
	var current: Dictionary = {}

	for child in main.get_children():
		if not (child is Area2D):
			continue

		if child.is_queued_for_deletion():
			continue

		var script: Script = child.get_script() as Script

		if script == null:
			continue

		if script.resource_path != "res://projectile.gd":
			continue

		var id: int = child.get_instance_id()
		current[id] = true

		if known_projectiles.has(id):
			continue

		if not _is_near_player(child.global_position):
			continue

		var attacker = child.get("owner_unit")

		# Катапульта має окремий звук
		if is_instance_valid(attacker):
			if attacker.is_in_group("catapults"):
				_play_sound("catapult_attack")
				continue

		var team: int = int(child.get("team"))

		# Здібність Q
		if child.get("is_skill") == true:
			if team == 1:
				_play_sound("q_blue")
			else:
				_play_sound("q_red")
			continue

		# Критична атака
		if child.get("is_crit") == true:
			if team == 1:
				_play_sound("player_crit")
			else:
				_play_sound("bot_crit")
			continue

		# Звичайна автоатака
		if team == 1:
			_play_sound("player_attack")
		else:
			_play_sound("bot_attack")

	known_projectiles = current


# ==========================================
# ЗВУКИ ЗВИЧАЙНИХ КРІПІВ
# ==========================================

func _check_creeps() -> void:
	var current: Dictionary = {}

	for creep in get_tree().get_nodes_in_group("creeps"):
		if not is_instance_valid(creep):
			continue

		if creep.is_queued_for_deletion():
			continue

		# Катапульти вже мають звук снаряда
		if creep.is_in_group("catapults"):
			continue

		var cooldown_value = creep.get("cooldown_timer")

		if cooldown_value == null:
			continue

		var id: int = creep.get_instance_id()
		var cooldown: float = float(cooldown_value)

		var previous: float = float(
			creep_states.get(id, -1.0)
		)

		# Після атаки таймер кріпа збільшується
		if previous >= 0.0:
			if cooldown > previous + 0.12:
				if _is_near_player(creep.global_position):
					var team: int = int(
						creep.get("direction")
					)

					if team == 1:
						_play_sound("creep_blue")
					else:
						_play_sound("creep_red")

		current[id] = cooldown

	creep_states = current


# ==========================================
# ЗВУКИ ВЕЖ І ТРОНІВ
# ==========================================

func _check_structures() -> void:
	var current: Dictionary = {}

	for structure in get_tree().get_nodes_in_group(
		"structures"
	):
		if not is_instance_valid(structure):
			continue

		if structure.is_queued_for_deletion():
			continue

		if float(structure.get("hp")) <= 0.0:
			continue

		var beam_value = structure.get("beam_timer")

		if beam_value == null:
			continue

		var id: int = structure.get_instance_id()
		var beam: float = float(beam_value)

		var previous: float = float(
			structure_states.get(id, -1.0)
		)

		# Новий постріл — таймер променя зріс
		if previous >= 0.0:
			if beam > previous + 0.025:
				if _is_near_player(
					structure.global_position
				):
					if structure.get("is_throne") == true:
						_play_sound("throne_attack")
					else:
						_play_sound("tower_attack")

		current[id] = beam

	structure_states = current


# ==========================================
# ЗДІБНОСТІ, ЗОЛОТО ТА РІВНІ
# ==========================================

func _check_heroes() -> void:
	var current: Dictionary = {}

	for hero in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(hero):
			continue

		if hero.is_queued_for_deletion():
			continue

		var id: int = hero.get_instance_id()
		var team: int = int(hero.get("direction"))

		var gold: int = int(hero.get("gold"))
		var level: int = int(hero.get("level"))

		var e_cd: float = float(hero.get("e_cd"))
		var r_cd: float = float(hero.get("r_cd"))

		var state: Dictionary = {
			"gold": gold,
			"level": level,
			"e": e_cd,
			"r": r_cd
		}

		var previous: Dictionary = hero_states.get(
			id, {}
		)

		if not previous.is_empty():
			var near: bool = _is_near_player(
				hero.global_position
			)

			# Блінк E
			if e_cd > float(previous["e"]) + 0.75:
				if near:
					if team == 1:
						_play_sound("e_blue")
					else:
						_play_sound("e_red")

			# Орбітальний удар R
			if r_cd > float(previous["r"]) + 0.75:
				if near:
					if team == 1:
						_play_sound("r_blue")
					else:
						_play_sound("r_red")

			# Події головного героя
			if team == 1:
				var gold_change: int = (
					gold - int(previous["gold"])
				)

				if gold_change >= 20:
					_play_sound("coin")

				elif gold_change <= -20:
					_play_sound("shop")

				if level > int(previous["level"]):
					_play_sound("level")

		current[id] = state

	hero_states = current


# ==========================================
# ВІДСТАНЬ ДО ГЕРОЯ
# ==========================================

func _is_near_player(pos: Vector2) -> bool:
	for hero in get_tree().get_nodes_in_group(
		"heroes"
	):
		if not is_instance_valid(hero):
			continue

		if int(hero.get("direction")) != 1:
			continue

		return (
			hero.global_position.distance_to(pos)
			<= AUDIO_DISTANCE
		)

	return false


# ==========================================
# ВІДТВОРЕННЯ ЗВУКУ
# ==========================================

func _play_sound(kind: String) -> void:
	if not sound_bank.has(kind):
		return

	var now: int = Time.get_ticks_msec()

	var previous: int = int(
		last_played.get(kind, -100000)
	)

	# Не дозволяємо десяткам атак
	# накладатися одночасно
	var cooldown_ms: int = 85

	match kind:
		"creep_blue", "creep_red":
			cooldown_ms = 145

		"player_attack", "bot_attack":
			cooldown_ms = 100

		"tower_attack", "throne_attack":
			cooldown_ms = 180

		"catapult_attack":
			cooldown_ms = 200

		"coin":
			cooldown_ms = 120

		"level":
			cooldown_ms = 450

	if now - previous < cooldown_ms:
		return

	last_played[kind] = now

	var variants: Array = sound_bank[kind]

	var variant_index: int = randi_range(
		0, variants.size() - 1
	)

	var selected: AudioStreamPlayer = null

	for audio in audio_players:
		if not audio.playing:
			selected = audio
			break

	if selected == null:
		selected = audio_players[next_player]
		next_player = (
			next_player + 1
		) % audio_players.size()

		selected.stop()

	selected.stream = variants[variant_index]

	# Додаткова природна зміна висоти
	selected.pitch_scale = randf_range(0.96, 1.04)

	var volume: float = -11.0

	match kind:
		"creep_blue", "creep_red":
			volume = -18.0

		"player_attack":
			volume = -10.0

		"bot_attack":
			volume = -11.0

		"player_crit", "bot_crit":
			volume = -7.0

		"tower_attack":
			volume = -9.0

		"throne_attack":
			volume = -7.0

		"catapult_attack":
			volume = -8.0

		"q_blue", "q_red":
			volume = -7.0

		"e_blue", "e_red":
			volume = -10.0

		"r_blue", "r_red":
			volume = -6.0

		"coin":
			volume = -15.0

		"shop":
			volume = -12.0

		"level":
			volume = -8.0

		"throne_break":
			volume = -5.0

	selected.volume_db = (
		volume + MASTER_VOLUME_DB
	)

	selected.play()


# ==========================================
# НАЛАШТУВАННЯ ТЕМБРІВ
# ==========================================

func _get_profile(kind: String) -> Dictionary:
	var p: Dictionary = {
		"duration": 0.25,
		"start": 300.0,
		"end": 100.0,
		"body": 0.7,
		"bass": 0.5,
		"noise": 0.3,
		"metal": 0.15,
		"click": 0.35,
		"drive": 2.0,
		"decay": 2.0,
		"echo": 0.0
	}

	match kind:
		# Синій герой — швидка енергетична зброя
		"player_attack":
			p["duration"] = 0.18
			p["start"] = 620.0
			p["end"] = 180.0
			p["body"] = 0.85
			p["bass"] = 0.30
			p["noise"] = 0.18
			p["metal"] = 0.32
			p["click"] = 0.65

		# Бот — темніший і грубіший постріл
		"bot_attack":
			p["duration"] = 0.25
			p["start"] = 310.0
			p["end"] = 70.0
			p["bass"] = 0.95
			p["noise"] = 0.48
			p["metal"] = 0.20
			p["drive"] = 3.1

		# Сині кріпи — легкий удар
		"creep_blue":
			p["duration"] = 0.12
			p["start"] = 420.0
			p["end"] = 210.0
			p["body"] = 0.28
			p["bass"] = 0.18
			p["noise"] = 0.36
			p["metal"] = 0.65
			p["click"] = 0.80

		# Червоні кріпи — важчий удар
		"creep_red":
			p["duration"] = 0.17
			p["start"] = 240.0
			p["end"] = 95.0
			p["body"] = 0.35
			p["bass"] = 0.65
			p["noise"] = 0.55
			p["metal"] = 0.22
			p["click"] = 0.75

		# Вежі — потужний магічний промінь
		"tower_attack":
			p["duration"] = 0.42
			p["start"] = 180.0
			p["end"] = 65.0
			p["body"] = 0.90
			p["bass"] = 1.15
			p["noise"] = 0.50
			p["metal"] = 0.42
			p["drive"] = 3.3
			p["echo"] = 0.13

		# Трони — глибокий розряд
		"throne_attack":
			p["duration"] = 0.58
			p["start"] = 145.0
			p["end"] = 42.0
			p["body"] = 1.0
			p["bass"] = 1.3
			p["noise"] = 0.45
			p["metal"] = 0.32
			p["echo"] = 0.23

		# Катапульта — механічний постріл
		"catapult_attack":
			p["duration"] = 0.55
			p["start"] = 130.0
			p["end"] = 42.0
			p["body"] = 0.55
			p["bass"] = 1.20
			p["noise"] = 0.85
			p["metal"] = 0.62
			p["click"] = 1.0
			p["drive"] = 3.6

		# Крити
		"player_crit":
			p["duration"] = 0.40
			p["start"] = 750.0
			p["end"] = 125.0
			p["bass"] = 0.85
			p["metal"] = 0.85
			p["click"] = 1.0
			p["echo"] = 0.14

		"bot_crit":
			p["duration"] = 0.48
			p["start"] = 270.0
			p["end"] = 45.0
			p["bass"] = 1.25
			p["noise"] = 0.70
			p["metal"] = 0.55
			p["click"] = 1.0

		# Плазмові залпи
		"q_blue":
			p["duration"] = 0.50
			p["start"] = 230.0
			p["end"] = 1100.0
			p["body"] = 1.10
			p["noise"] = 0.32
			p["metal"] = 0.58
			p["echo"] = 0.19

		"q_red":
			p["duration"] = 0.57
			p["start"] = 175.0
			p["end"] = 600.0
			p["bass"] = 0.85
			p["noise"] = 0.58
			p["drive"] = 3.2
			p["echo"] = 0.20

		# Блінки
		"e_blue":
			p["duration"] = 0.37
			p["start"] = 950.0
			p["end"] = 105.0
			p["noise"] = 0.52
			p["echo"] = 0.27

		"e_red":
			p["duration"] = 0.46
			p["start"] = 540.0
			p["end"] = 48.0
			p["bass"] = 0.95
			p["noise"] = 0.64
			p["echo"] = 0.24

		# Ультимативні здібності
		"r_blue":
			p["duration"] = 1.20
			p["start"] = 220.0
			p["end"] = 40.0
			p["body"] = 1.0
			p["bass"] = 1.4
			p["noise"] = 0.85
			p["drive"] = 3.5
			p["echo"] = 0.28

		"r_red":
			p["duration"] = 1.35
			p["start"] = 125.0
			p["end"] = 27.0
			p["body"] = 1.1
			p["bass"] = 1.55
			p["noise"] = 0.95
			p["drive"] = 3.8
			p["echo"] = 0.32

		# Економіка
		"coin":
			p["duration"] = 0.30
			p["start"] = 900.0
			p["end"] = 540.0
			p["bass"] = 0.05
			p["noise"] = 0.02
			p["metal"] = 0.75
			p["drive"] = 1.2

		"shop":
			p["duration"] = 0.35
			p["start"] = 420.0
			p["end"] = 690.0
			p["bass"] = 0.20
			p["noise"] = 0.05
			p["metal"] = 0.55

		"level":
			p["duration"] = 0.85
			p["start"] = 196.0
			p["end"] = 293.66
			p["noise"] = 0.04
			p["metal"] = 0.42
			p["decay"] = 0.9
			p["echo"] = 0.22

		"throne_break":
			p["duration"] = 1.85
			p["start"] = 110.0
			p["end"] = 24.0
			p["body"] = 1.1
			p["bass"] = 1.65
			p["noise"] = 1.0
			p["metal"] = 0.65
			p["click"] = 1.0
			p["drive"] = 3.8
			p["decay"] = 1.2
			p["echo"] = 0.32

	return p


# ==========================================
# СИНТЕЗ ЗВУКУ
# ==========================================

func _generate_sound(
	kind: String,
	variant: int
) -> AudioStreamWAV:

	var p: Dictionary = _get_profile(kind)

	var duration: float = float(p["duration"])
	var count: int = int(duration * SAMPLE_RATE)

	# Варіація висоти та тембру
	var pitch_factor: float = [
		0.91, 1.0, 1.09
	][variant]

	var start_freq: float = (
		float(p["start"]) * pitch_factor
	)

	var end_freq: float = (
		float(p["end"]) * pitch_factor
	)

	var samples := PackedFloat32Array()
	samples.resize(count)

	var phase: float = 0.0
	var bass_phase: float = 0.0
	var metal_phase: float = 0.0

	var filtered_noise: float = 0.0

	var rate: float = float(SAMPLE_RATE)

	var echo_delay: int = int(
		0.105 * rate
	)

	# Генерація аудіосемплів
	for i in range(count):
		var t: float = float(i) / rate
		var progress: float = float(i) / float(count)

		var freq: float = lerpf(
			start_freq,
			end_freq,
			pow(progress, 0.75)
		)

		if kind == "level":
			if progress < 0.33:
				freq = 196.0
			elif progress < 0.66:
				freq = 246.94
			else:
				freq = 293.66

			freq *= pitch_factor

		phase += TAU * freq / rate

		bass_phase += (
			TAU * lerpf(85.0, 35.0, progress) / rate
		)

		metal_phase += (
			TAU * freq * 2.43 / rate
		)

		var envelope: float = pow(
			maxf(0.0, 1.0 - progress),
			float(p["decay"])
		)

		var attack: float = minf(
			1.0, t * 900.0
		)

		# Основне тіло звуку
		var tonal: float = (
			sin(phase) * 0.75
			+ sin(phase * 1.71) * 0.20
			+ sin(phase * 3.2) * 0.11
		)

		var body: float = (
			tonal * float(p["body"])
			* envelope * attack * 0.42
		)

		# Низькочастотний удар
		var bass: float = (
			sin(bass_phase)
			* float(p["bass"])
			* exp(-t * 8.0)
			* 0.6
		)

		# Металевий резонанс
		var metallic: float = (
			sin(metal_phase)
			* float(p["metal"])
			* pow(1.0 - progress, 2.5)
			* 0.30
		)

		# Шумова складова
		var white_noise: float = randf_range(
			-1.0, 1.0
		)

		filtered_noise = lerpf(
			filtered_noise,
			white_noise,
			0.20
		)

		var noise: float = (
			(white_noise - filtered_noise)
			* float(p["noise"])
			* exp(-t * 7.0)
			* 0.38
		)

		# Короткий удар на початку звуку
		var click: float = (
			white_noise
			* float(p["click"])
			* exp(-t * 90.0)
			* 0.42
		)

		var raw_value: float = (
			body + bass + metallic + noise + click
		)

		# Насичення звуку
		var drive: float = float(p["drive"])

		var shaped: float = (
			atan(raw_value * drive) / atan(drive)
		)

		var value: float = shaped * 0.72

		# Відлуння
		if i >= echo_delay:
			value += (
				samples[i - echo_delay]
				* float(p["echo"])
			)

		# Плавне завершення
		value *= clampf(
			(duration - t) / 0.04,
			0.0, 1.0
		)

		samples[i] = clampf(
			value, -0.95, 0.95
		)

	# Перетворення на PCM 16-bit
	var data := PackedByteArray()
	data.resize(count * 2)

	for i in range(count):
		var sample: int = int(
			samples[i] * 32767.0
		)

		var encoded: int = sample & 0xFFFF

		data[i * 2] = encoded & 0xFF
		data[i * 2 + 1] = (
			encoded >> 8
		) & 0xFF

	var stream := AudioStreamWAV.new()

	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data

	return stream
