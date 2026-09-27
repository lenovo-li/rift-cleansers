extends Node3D
## M1 游戏场景控制器

@onready var _hud: Control = $UI/HUD
@onready var _player: Node3D = $PlayerM1
@onready var _session: GameSession = $GameSession
@onready var _spawner: Node3D = $EnemySpawner

var _frame_times: Array[float] = []


func _ready() -> void:
	_session.game_started.connect(_on_game_started)
	_session.game_over.connect(_on_game_over)
	_session.level_up.connect(_on_level_up)
	
	await get_tree().process_frame
	
	# 初始化SpawnDirector
	var spawn_dir: SpawnDirector = _session.get_node("SpawnDirector")
	spawn_dir.initialize(_session)
	
	_session.start_game()


func _process(_delta: float) -> void:
	update_hud()


func update_hud() -> void:
	var fps_label: Label = _hud.get_node("FPS")
	var health_label: Label = _hud.get_node("Health")
	var level_label: Label = _hud.get_node("Level")
	var time_label: Label = _hud.get_node("Time")
	var enemy_label: Label = _hud.get_node("Enemies")
	
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
	if _player:
		health_label.text = "HP: %.0f/%.0f" % [_player.get_health(), _player.get_max_health()]
	
	var level: int = _session.get_player_level()
	var exp: float = _session.get_player_exp()
	var required: float = _session.get_exp_required(level)
	level_label.text = "Lv%d | EXP: %.0f/%.0f" % [level, exp, required]
	
	var time: float = _session.get_game_time()
	var mins: int = int(time / 60.0)
	var secs: int = int(time) % 60
	time_label.text = "Time: %d:%02d / 10:00" % [mins, secs]
	
	if _spawner:
		enemy_label.text = "Enemies: %d" % _spawner.get_enemy_count()


func _on_game_started() -> void:
	print("[GameScene] Started")


func _on_game_over(reason: String) -> void:
	print("[GameScene] Game Over: %s" % reason)
	
	var game_over_label: Label = Label.new()
	game_over_label.text = "GAME OVER\n%s\nPress R to restart" % reason.to_upper()
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 32)
	game_over_label.position = Vector2(400, 250)
	game_over_label.size = Vector2(400, 200)
	_hud.add_child(game_over_label)


func _on_level_up(new_level: int) -> void:
	print("[GameScene] LEVEL UP! -> %d" % new_level)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	elif event.is_action_pressed("ui_accept") and not _session.is_running:
		get_tree().reload_current_scene()
