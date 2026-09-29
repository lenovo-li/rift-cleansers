extends Node3D
## M1 游戏场景控制器：串起会话、刷怪、掉落、升级面板、HUD 与结算。

## 模拟/测试用：自动选择升级第一项，不弹出暂停面板。
@export var auto_pick_upgrades: bool = false

@onready var _hud: Control = $UI/HUD
@onready var _upgrade_panel: Control = $UI/UpgradePanel
@onready var _player: CharacterBody3D = $PlayerM1
@onready var _session: GameSession = $GameSession
@onready var _director: SpawnDirector = $GameSession/SpawnDirector
@onready var _spawner: Node3D = $EnemySpawner
@onready var _loot: Node3D = $LootManager

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _game_over_panel: Control = null


func _ready() -> void:
	_rng.randomize()
	_session.game_over.connect(_on_game_over)
	_session.level_up.connect(_on_level_up)
	_player.died.connect(func(reason: String) -> void: _session.end_game(reason, false))
	_player.equipment_added.connect(func(id: String) -> void:
		_hud.show_toast("获得装备：%s — %s" % [ItemCatalog.equipment_name(id), ItemCatalog.equipment_desc(id)], 3.5))
	_spawner.boss_spawned.connect(_on_boss_spawned)
	_spawner.boss_defeated.connect(func() -> void: _session.end_game("击败了腐化骑士", true))
	_upgrade_panel.roll_choices = func() -> Array[Dictionary]:
		return UpgradeSystem.roll_choices(_player.ability_system, _player.stats, _rng)
	_upgrade_panel.chosen.connect(_apply_upgrade)
	_hud.player = _player
	_hud.session = _session
	_hud.spawner = _spawner
	Reactions.on_reaction = _on_reaction

	await get_tree().process_frame
	_director.initialize(_session)
	_session.start_game()
	_hud.show_toast("WASD 移动  空格 盾击  E 嘲讽  Shift 闪避  T 自动施放", 5.0)


func _exit_tree() -> void:
	Reactions.on_reaction = Callable()
	Enemy.clear_caches()
	if is_inside_tree():
		get_tree().paused = false


func _on_level_up(_new_level: int) -> void:
	if auto_pick_upgrades:
		_apply_upgrade(UpgradeSystem.roll_choices(_player.ability_system, _player.stats, _rng)[0])
	else:
		_upgrade_panel.request()


func _apply_upgrade(choice: Dictionary) -> void:
	if not UpgradeSystem.apply(choice, _player.ability_system, _player.stats):
		return
	print("[GameScene] upgrade: %s" % choice.title)
	if choice.type == "skill_up":
		var skill: Skill = _player.ability_system.get_skill(choice.id)
		if skill.level in skill.get_tier_thresholds():
			_hud.show_toast("%s 进化！第 %d 段" % [skill.display_name, skill.get_tier_thresholds().find(skill.level) + 1])


func _on_boss_spawned(boss: Boss) -> void:
	_hud.show_toast("腐化骑士 降临！", 3.0)
	boss.phase_changed.connect(func(phase: int) -> void:
		_hud.show_toast("腐化骑士 进入第 %d 阶段%s" % [phase, "：冲锋！注意红色预警" if phase == 2 else "：狂暴！"], 3.0))


func _on_reaction(reaction: String, pos: Vector3) -> void:
	if reaction == "ignite":
		SkillVfx.pulse_ring(self, pos, Reactions.IGNITE_RADIUS, Color(1.0, 0.4, 0.05, 0.55), 0.3)
	else:
		SkillVfx.pulse_ring(self, pos, 1.2, Color(0.6, 0.9, 1.0, 0.6), 0.2)


func _on_game_over(reason: String, victory: bool) -> void:
	print("[GameScene] Game Over: %s (victory=%s, level=%d, kills=%d, time=%.0fs)" % [
		reason, victory, _session.get_player_level(), _spawner.kills, _session.get_game_time()])
	if _upgrade_panel.is_open():
		_upgrade_panel.visible = false
	get_tree().paused = true
	_game_over_panel = GameOverPanel.build(victory, reason, _session, _spawner.kills)
	$UI.add_child(_game_over_panel)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_T:
				_player.auto_cast = not _player.auto_cast
			KEY_ESCAPE:
				get_tree().quit()
