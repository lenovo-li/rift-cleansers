extends Node3D
## 游戏场景控制器：串起会话、刷怪、掉落、升级面板、HUD 与结算。
## 联机时（NetConfig）额外创建 NetSession：主机运行完整模拟，客户端只显示并上传输入。

## 模拟/测试用：自动选择升级第一项，不弹出暂停面板。
@export var auto_pick_upgrades: bool = false
## 结算时写入本地存档（排行榜、天赋碎片）。模拟/测试脚本关掉，避免污染玩家存档。
@export var record_runs: bool = true

const REVIVE_RADIUS: float = 2.5
const REVIVE_TIME: float = 3.0

@onready var _hud: Control = $UI/HUD
@onready var _upgrade_panel: Control = $UI/UpgradePanel
@onready var _player: CharacterBody3D = $PlayerM1
@onready var _session: GameSession = $GameSession
@onready var _director: SpawnDirector = $GameSession/SpawnDirector
@onready var _spawner: Node3D = $EnemySpawner
@onready var _loot: Node3D = $LootManager

var net: NetSession = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _game_over_panel: Control = null
var _pause_menu: PauseMenu = null
var _invite_panel: P2PPanel = null
var _music: Node = null
var _music_timer: float = 0.0
## 地图随机事件（主机 / 单人）
var events: EventDirector = null
## 成就用：Boss 登场时间（-1 = 未登场）、词缀、本地玩家是否倒下过
var _boss_spawn_time: float = -1.0
var _boss_affix: String = ""
var _local_downed: bool = false


func _ready() -> void:
	_rng.randomize()
	CrashReporter.install(get_tree())
	Settings.apply()  # 命令行直接开局时菜单没跑过，这里再应用一次
	Settings.apply_quality(self)  # 地图（子节点）已按主题复制好环境，这里再按画质开关阴影 / 泛光
	_music = (load("res://presentation/music_manager.gd") as GDScript).new()
	_music.name = "Music"
	add_child(_music)
	if not NetConfig.is_client():
		events = EventDirector.new()
		events.name = "EventDirector"
		add_child(events)
		events.initialize(NetConfig.map_id, _session, _loot, _spawner)
		events.event_triggered.connect(func(_kind: int, text: String) -> void: _broadcast_toast(text))
	_session.game_over.connect(_on_game_over)
	_session.level_up.connect(_on_level_up)
	_spawner.boss_spawned.connect(_on_boss_spawned)
	_spawner.boss_defeated.connect(func(boss_name: String) -> void: _session.end_game("击败了%s" % boss_name, true))
	_upgrade_panel.roll_choices = func() -> Array[Dictionary]:
		return UpgradeSystem.roll_choices(_player.ability_system, _player.stats, _rng)
	_upgrade_panel.chosen.connect(_on_upgrade_chosen)
	_hud.player = _player
	_hud.session = _session
	_hud.spawner = _spawner
	Reactions.on_reaction = _on_reaction
	if NetConfig.bot:
		_player.ai_controlled = true
		_player.bot = PlayerBot.new()
		auto_pick_upgrades = true
		record_runs = false
	register_player(_player)
	_player.died.connect(func(_reason: String) -> void: _local_downed = true)
	Achievements.on_unlocked = func(_id: String, title: String) -> void:
		_hud.show_toast("成就解锁：%s" % title, 3.0)
	SkillVfx.reset_counters()
	SkillVfx.warmup(self, _player.global_position)  # 预编译特效着色器，避免第一次施放卡顿
	_player.hurt.connect(func(amount: float) -> void:
		DamageNumbers.spawn(self, _player.global_position, amount, DamageNumbers.Kind.PLAYER)
		_hud.flash_hurt(amount))
	if NetConfig.is_online():
		_setup_network()
		var reporter: Node = preload("res://net/net_test_reporter.gd").new()
		reporter.name = "NetTestReporter"
		add_child(reporter)

	await get_tree().process_frame
	if NetConfig.is_client():
		return  # 时间、等级、刷怪都来自主机
	_session.exp_bonus = Talents.bonus(_player.talent_ranks, _player.character_id, "wisdom")
	_director.initialize(_session)
	_director.player_count_provider = func() -> int: return PlayerQuery.all(get_tree()).size()
	_session.player_count_provider = _director.player_count_provider
	_session.start_game()
	var keys: PackedStringArray = []
	var pool: Array[String] = _player.ability_system.pool()
	for i in pool.size():
		if _player.ability_system.get_skill(pool[i]) != null:
			keys.append("%s %s" % [_hud.key_label(i), SkillFactory.display_name(pool[i])])
	var move: String = "".join([Settings.key_name(Settings.key_of("move_up")), Settings.key_name(Settings.key_of("move_left")),
			Settings.key_name(Settings.key_of("move_down")), Settings.key_name(Settings.key_of("move_right"))])
	if Settings.pad_connected():
		_hud.show_toast("左摇杆 移动  %s  A 闪避  Back 自动施放  Start 菜单" % "  ".join(keys), 5.0)
	else:
		_hud.show_toast("%s 移动  %s  %s 闪避  T 自动施放  %s 菜单  F3 联机调试" % [move, "  ".join(keys),
				Settings.key_name(Settings.key_of("dash")), Settings.key_name(Settings.key_of("pause"))], 5.0)
	# P2P 房主刚开房（还没有好友）：直接弹出邀请面板；之后可以在菜单里继续邀请
	if NetConfig.is_host() and NetConfig.p2p and NetConfig.p2p_dir.is_empty() and not NetConfig.bot \
			and net != null and net.players_by_slot.size() <= 1:
		_open_invite_panel()


func _setup_network() -> void:
	net = NetSession.new()
	net.name = "NetSession"
	net.process_mode = Node.PROCESS_MODE_ALWAYS  # 结算暂停时仍要收发
	add_child(net)
	net.setup(self, _player, _session, _spawner)
	net.toast_received.connect(func(text: String) -> void: _hud.show_toast(text, 3.0))
	net.upgrade_choices_received.connect(_on_remote_upgrade_choices)
	_player.dodge_requested.connect(func() -> void: net.send_action(NetSession.Action.DODGE, 0))
	_upgrade_panel.pause_game = false
	_hud.net = net


func _exit_tree() -> void:
	Reactions.on_reaction = Callable()
	Achievements.on_unlocked = Callable()
	Enemy.clear_caches()
	SfxManager.reset_voices()
	HitStop.reset()
	if is_inside_tree():
		get_tree().paused = false


## 玩家加入场景时调用（本地玩家、主机上的远程玩家）。
func register_player(p: CharacterBody3D) -> void:
	p.died.connect(func(_reason: String) -> void: _on_player_down(p))
	p.equipment_added.connect(func(id: String) -> void:
		_toast_to(p.net_slot, "获得装备：%s — %s" % [ItemCatalog.equipment_name(id), ItemCatalog.equipment_desc(id)]))


## 每秒按敌人数量和 Boss 是否在场切换音乐（客户端的数量和 Boss 信息来自主机快照，同样可用）。
func _process(delta: float) -> void:
	_music_timer -= delta
	if _music_timer <= 0.0 and _session.is_running:
		_music_timer = 1.0
		_music.update_state(_spawner.get_enemy_count(), not _spawner.get_boss_info().is_empty())


func _physics_process(delta: float) -> void:
	if NetConfig.is_client() or not _session.is_running:
		return
	_update_revives(delta)


## 倒地的玩家：有存活队友站在 2.5 米内 3 秒即可救起。
func _update_revives(delta: float) -> void:
	for p: Node in get_tree().get_nodes_in_group("players"):
		if not p.is_dead:
			continue
		var helper: bool = not PlayerQuery.alive_in_radius(get_tree(), (p as Node3D).global_position, REVIVE_RADIUS).is_empty()
		p.revive_progress = clampf(p.revive_progress + (delta if helper else -delta * 0.5) / REVIVE_TIME, 0.0, 1.0)
		if p.revive_progress >= 1.0:
			p.revive()
			_broadcast_toast("%s 被救起了" % p.display_name)


func _on_player_down(p: CharacterBody3D) -> void:
	if NetConfig.is_client():
		return
	if PlayerQuery.alive(get_tree()).is_empty():
		_session.end_game("全员倒下（%s 被 %s 击倒）" % [p.display_name, p.last_damage_source] \
				if PlayerQuery.all(get_tree()).size() > 1 else "被 %s 击倒" % p.last_damage_source, false)
	else:
		_broadcast_toast("%s 倒下了！靠近 %d 秒救起" % [p.display_name, int(REVIVE_TIME)])


func _toast_to(slot: int, text: String) -> void:
	if net != null:
		net.toast_to(slot, text)
	elif slot == 0:
		_hud.show_toast(text, 3.5)


func _broadcast_toast(text: String) -> void:
	if net != null:
		net.broadcast_toast(text)
	else:
		_hud.show_toast(text, 3.0)


## 共享等级：每个玩家各选一次。主机本地玩家用面板，远程玩家由 NetSession 发给对应客户端。
func _on_level_up(_new_level: int) -> void:
	if NetConfig.is_client():
		return
	for p: Node3D in PlayerQuery.all(get_tree()):
		SkillVfx.burst(self, "star", p.global_position + Vector3(0, 1, 0), 1.0)
	_hud.flash_level_up()
	if net != null:
		for slot: int in net.players_by_slot:
			if slot != 0:
				net.queue_upgrade(slot)
	if auto_pick_upgrades:
		_apply_upgrade(UpgradeSystem.roll_choices(_player.ability_system, _player.stats, _rng)[0])
	else:
		_upgrade_panel.request()


## 客户端：主机发来的三个选项。
func _on_remote_upgrade_choices(choices: Array, remaining: int) -> void:
	if auto_pick_upgrades:
		net.send_action(NetSession.Action.UPGRADE, 0)
	else:
		_upgrade_panel.show_remote(choices, remaining)


func _on_upgrade_chosen(choice: Dictionary, index: int) -> void:
	if NetConfig.is_client():
		net.send_action(NetSession.Action.UPGRADE, index)
	else:
		_apply_upgrade(choice)


func _apply_upgrade(choice: Dictionary) -> void:
	if not UpgradeSystem.apply(choice, _player.ability_system, _player.stats):
		return
	print("[GameScene] upgrade: %s" % choice.title)
	if choice.type == "skill_up":
		var skill: Skill = _player.ability_system.get_skill(choice.id)
		if skill.level in skill.get_tier_thresholds():
			_hud.show_toast("%s 进化！第 %d 段" % [skill.display_name, skill.get_tier_thresholds().find(skill.level) + 1])
			SkillVfx.burst(self, "star", _player.global_position + Vector3(0, 1.5, 0), 1.6, Color(0.5, 0.85, 1.0))
			SfxManager.play(self, "evolve")


func _on_boss_spawned(boss: Boss) -> void:
	_boss_spawn_time = _session.get_game_time()
	_boss_affix = boss.affix
	_broadcast_toast("%s 降临！" % boss.get_display_name())
	boss.phase_changed.connect(func(phase: int) -> void:
		SkillVfx.shockwave(self, boss.global_position, 12.0, Color(0.9, 0.1, 0.25, 1.0), 0.7)
		SfxManager.play(self, "slam")
		HitStop.trigger(get_tree(), 0.08)
		_broadcast_toast("%s 进入第 %d 阶段：%s" % [boss.get_display_name(), phase, Boss.phase_hint(boss.variant, phase)]))


func _on_reaction(reaction: String, pos: Vector3) -> void:
	if reaction == "ignite":
		SkillVfx.shockwave(self, pos, Reactions.IGNITE_RADIUS, Color(1.0, 0.45, 0.1, 1.0), 0.35)
		SkillVfx.burst(self, "fire", pos + Vector3(0, 0.8, 0), 1.2)
		SfxManager.play(self, "explode")
		HitStop.trigger(get_tree(), 0.04)
	else:
		SkillVfx.burst(self, "shard", pos + Vector3(0, 1, 0), 1.0)
		SfxManager.play(self, "shatter")


func _on_game_over(reason: String, victory: bool) -> void:
	_music.stop()
	print("[GameScene] Game Over: %s (victory=%s, level=%d, kills=%d, time=%.0fs)" % [
		reason, victory, _session.get_player_level(), _spawner.kills, _session.get_game_time()])
	if net != null:
		net.broadcast_game_over(reason, victory)
	if _upgrade_panel.is_open():
		_upgrade_panel.close()
	_close_pause_menu()
	get_tree().paused = true
	var record: Dictionary = {}
	if record_runs:
		record = SaveData.record_run(_player.character_id, NetConfig.map_id, victory, _session.get_game_time(),
				_session.get_player_level(), _spawner.kills, _achievement_context())
	var can_restart: bool = not NetConfig.is_client()
	_game_over_panel = GameOverPanel.build(victory, reason, _session, _spawner.kills, can_restart, record)
	_game_over_panel.restart_requested.connect(_restart)
	_game_over_panel.quit_requested.connect(_quit_to_menu)
	$UI.add_child(_game_over_panel)


## 成就判断用的本局数据。技能段位和装备由主机结算，客户端填 -1（相关成就本局不判断）。
func _achievement_context() -> Dictionary:
	var tiers: int = -1
	var gear: int = -1
	if not NetConfig.is_client():
		tiers = 0
		for id: String in _player.ability_system.pool():
			var skill: Skill = _player.ability_system.get_skill(id)
			if skill != null and skill.get_tier() >= 4:
				tiers += 1
		gear = _player.stats.equipment.size()
	return {"boss_affix": _boss_affix, "players": maxi(1, PlayerQuery.all(get_tree()).size()),
		"boss_fight_time": _session.get_game_time() - _boss_spawn_time if _boss_spawn_time >= 0.0 else -1.0,
		"max_tier_skills": tiers, "equipment": gear, "downed": _local_downed}


func _restart() -> void:
	if net != null:
		net.broadcast_restart()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit_to_menu() -> void:
	if net != null:
		net.shutdown()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if NetConfig.is_client():
		_client_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_T:
				_player.auto_cast = not _player.auto_cast
				if net != null:
					net.send_action(NetSession.Action.AUTO_CAST, int(_player.auto_cast))
			KEY_F3:
				_hud.toggle_debug()
	if event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_BACK:
		_player.auto_cast = not _player.auto_cast  # 手柄 Back = T（自动施放）
		_hud.show_toast("自动施放：%s" % ("开" if _player.auto_cast else "关"), 1.5)
		if net != null:
			net.send_action(NetSession.Action.AUTO_CAST, int(_player.auto_cast))
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_open_pause_menu()


## Esc：暂停菜单（继续 / 设置 / 回主菜单）。结算和选升级时不弹。
func _open_pause_menu() -> void:
	if _pause_menu != null or _invite_panel != null or _game_over_panel != null or _upgrade_panel.is_open():
		return
	var solo: bool = not NetConfig.is_online()
	_pause_menu = PauseMenu.build(solo)
	_pause_menu.show_invite = NetConfig.is_host() and NetConfig.p2p
	_pause_menu.resume_requested.connect(_close_pause_menu)
	_pause_menu.quit_requested.connect(_quit_to_menu)
	_pause_menu.invite_requested.connect(func() -> void:
		_close_pause_menu()
		_open_invite_panel())
	$UI.add_child(_pause_menu)
	if solo:
		get_tree().paused = true


## P2P 房主：邀请面板（打开时暂停游戏，好友连上后关闭继续）。
func _open_invite_panel() -> void:
	if _invite_panel != null or _game_over_panel != null:
		return
	_invite_panel = P2PPanel.build(true)
	_invite_panel.closed.connect(func() -> void: _invite_panel = null)
	$UI.add_child(_invite_panel)
	if net != null and net.players_by_slot.size() > 1:
		net.broadcast_toast("房主正在邀请好友，游戏暂停中")


func _close_pause_menu() -> void:
	if _pause_menu == null:
		return
	_pause_menu.queue_free()
	_pause_menu = null
	if not NetConfig.is_online():
		get_tree().paused = false


## 客户端：技能键交给主机结算；闪避本地预测（dodge_requested 信号负责上传）。
func _client_input(event: InputEvent) -> void:
	if _player.is_dead:
		return
	for i in _player.SKILL_ACTIONS.size():
		if event.is_action_pressed(_player.SKILL_ACTIONS[i]):
			net.send_action(NetSession.Action.SKILL, i)
	if event.is_action_pressed("dash"):
		_player.dodge()
