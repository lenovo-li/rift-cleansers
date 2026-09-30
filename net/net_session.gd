class_name NetSession extends Node
## 联机会话（M2 原型，文档 06）：ENet 主机权威 Listen Server。
## 所有 RPC 都在这个固定路径的节点上（/root/GameScene/NetSession），动态生成的节点不需要 RPC 路径。
## 主机：运行完整模拟，按频率广播玩家状态（20 Hz）、敌群快照（10 Hz）、世界状态（10 Hz）和特效事件（可靠）。
## 客户端：不运行任何玩法逻辑，本地预测自己的移动，其余全部按主机数据显示。
## 局域网原型：没有鉴权和加密，只校验 RPC 发送者与槽位对应。

signal toast_received(text: String)
signal upgrade_choices_received(choices: Array, remaining: int)
signal game_over_received(reason: String, victory: bool)

enum Action { SKILL, DODGE, UPGRADE, AUTO_CAST }

const PlayerScene: PackedScene = preload("res://gameplay/actors/player_m1.tscn")
const ProjectileScript: GDScript = preload("res://gameplay/actors/enemy_projectile.gd")
const HazardScript: GDScript = preload("res://gameplay/actors/hazard_zone.gd")
const BlastScript: GDScript = preload("res://gameplay/actors/delayed_blast.gd")
const PickupScript: GDScript = preload("res://gameplay/loot/pickup.gd")
const PLAYER_INTERVAL: float = 0.05
const ENEMY_INTERVAL: float = 0.1
const WORLD_INTERVAL: float = 0.1
const ENEMY_CHUNK: int = 120  # 每包 1200 字节，低于 MTU，丢一包只影响一部分敌人
const DISCONNECT_GRACE: float = 30.0
const HELLO_RETRY: float = 1.0
## ENet 默认要 5-30 秒才判定掉线；缩短到约 3 秒，AI 托管能及时接手。
const PEER_TIMEOUT_MIN_MS: int = 1500
const PEER_TIMEOUT_MAX_MS: int = 3000

## 跨场景重载保留（重新开始时连接不断开，客户端用同一令牌回到同一槽位）。
static var _slot_by_token: Dictionary = {}  # token -> slot

var scene: Node3D = null
var local_player: CharacterBody3D = null
var session: GameSession = null
var spawner: Node3D = null
var enemy_views: EnemyViewPool = null
var players_by_slot: Dictionary = {}  # slot -> 玩家节点
var my_slot: int = 0
var welcomed: bool = false

var _peer_by_slot: Dictionary = {}     # 主机：slot -> peer id
var _slot_by_peer: Dictionary = {}     # 主机：peer id -> slot
var _disconnect_timers: Dictionary = {}  # 主机：slot -> 剩余托管秒数
var _pending_upgrades: Dictionary = {}   # 主机：slot -> 待选次数
var _offered: Dictionary = {}            # 主机：slot -> 当前三个选项
var _fx_batch: Array = []
var _timers: Dictionary = {"player": 0.0, "enemy": 0.0, "world": 0.0, "hello": 0.0, "ping": 0.0}
var _outbox: Array = []  # 模拟延迟：[到期毫秒, peer, 方法, 参数]
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pickup_views: Dictionary = {}  # 客户端：pickup id -> 节点

# 调试统计
var ping_ms: float = 0.0
var _bytes_out: int = 0
var _bytes_in: int = 0
var _rate_out: float = 0.0
var _rate_in: float = 0.0
var _rate_timer: float = 0.0
var _max_correction: float = 0.0


func is_host() -> bool:
	return NetConfig.is_host()


func is_client() -> bool:
	return NetConfig.is_client()


## 游戏场景 _ready 时调用。
func setup(p_scene: Node3D, p_local: CharacterBody3D, p_session: GameSession, p_spawner: Node3D) -> void:
	scene = p_scene
	local_player = p_local
	session = p_session
	spawner = p_spawner
	_rng.randomize()
	var mp: MultiplayerAPI = multiplayer
	var existing: MultiplayerPeer = mp.multiplayer_peer
	var connected: bool = existing is ENetMultiplayerPeer \
			and existing.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	if is_host():
		if not connected:
			var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
			var err: Error = peer.create_server(NetConfig.port, NetConfig.MAX_CLIENTS)
			if err != OK:
				push_error("[net] 无法创建主机 (端口 %d): %s" % [NetConfig.port, error_string(err)])
				return
			mp.multiplayer_peer = peer
			print("[net] hosting on port %d (lag=%dms)" % [NetConfig.port, NetConfig.lag_ms])
		mp.peer_connected.connect(func(id: int) -> void:
			print("[net] peer connected %d" % id)
			_set_peer_timeout(id))
		mp.peer_disconnected.connect(_on_peer_disconnected)
		my_slot = 0
		welcomed = true
		_register_player(0, local_player, NetConfig.player_name)
		SkillVfx.recorder = func(ev: Array) -> void: _fx_batch.append(ev)
		SfxManager.recorder = func(cat: String) -> void: _fx_batch.append(["sfx", cat])
		spawner.enemy_killed.connect(func(e: Enemy) -> void: _fx_batch.append(["dead", e.entity_id]))
	else:
		enemy_views = EnemyViewPool.new()
		enemy_views.name = "EnemyViews"
		scene.add_child(enemy_views)
		local_player.control = local_player.ControlMode.PREDICTED
		if not connected:
			var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
			var err: Error = peer.create_client(NetConfig.address, NetConfig.port)
			if err != OK:
				push_error("[net] 无法连接 %s:%d: %s" % [NetConfig.address, NetConfig.port, error_string(err)])
				return
			mp.multiplayer_peer = peer
			print("[net] connecting to %s:%d (lag=%dms)" % [NetConfig.address, NetConfig.port, NetConfig.lag_ms])
		mp.connected_to_server.connect(func() -> void: _set_peer_timeout(1))
		mp.connection_failed.connect(func() -> void: _leave("连接失败"))
		mp.server_disconnected.connect(func() -> void: _leave("与主机断开连接"))


func _set_peer_timeout(peer_id: int) -> void:
	var enet: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var pp: ENetPacketPeer = enet.get_peer(peer_id) if enet else null
	if pp != null:
		pp.set_timeout(32, PEER_TIMEOUT_MIN_MS, PEER_TIMEOUT_MAX_MS)


func _exit_tree() -> void:
	SkillVfx.recorder = Callable()
	SfxManager.recorder = Callable()


## 客户端断线：机器人测试直接退出，否则回菜单。
func _leave(reason: String) -> void:
	print("[net] %s" % reason)
	toast_received.emit(reason)
	if NetConfig.bot:
		get_tree().quit(2)
		return
	await get_tree().create_timer(2.0).timeout
	shutdown()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


## 关闭连接并回到单人模式。
func shutdown() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	NetConfig.reset()
	_slot_by_token.clear()


func _register_player(slot: int, player: CharacterBody3D, display: String) -> void:
	player.net_slot = slot
	player.display_name = display
	players_by_slot[slot] = player
	if player.has_method("refresh_color"):
		player.refresh_color()


func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	_flush_outbox()
	_update_rates(delta)
	for k: String in _timers:
		_timers[k] += delta
	if is_host():
		_host_tick(delta)
	else:
		_client_tick()


## 所有发送都走这里，便于模拟延迟和统计带宽。peer = 0 表示发给所有已就绪的客户端。
func _send(peer: int, method: StringName, args: Array) -> void:
	if NetConfig.lag_ms > 0:
		_outbox.append([Time.get_ticks_msec() + NetConfig.lag_ms, peer, method, args])
		return
	_send_now(peer, method, args)


func _send_now(peer: int, method: StringName, args: Array) -> void:
	var size: int = var_to_bytes(args).size()
	if peer == 0:
		for p: int in _slot_by_peer:
			_bytes_out += size
			callv("rpc_id", [p, method] + args)
	else:
		_bytes_out += size
		callv("rpc_id", [peer, method] + args)


func _flush_outbox() -> void:
	var now: int = Time.get_ticks_msec()
	while not _outbox.is_empty() and _outbox[0][0] <= now:
		var item: Array = _outbox.pop_front()
		if multiplayer.multiplayer_peer != null:
			_send_now(item[1], item[2], item[3])


func _count_in(args: Array) -> void:
	_bytes_in += var_to_bytes(args).size()


func _update_rates(delta: float) -> void:
	_rate_timer += delta
	if _rate_timer >= 1.0:
		_rate_out = _bytes_out / _rate_timer
		_rate_in = _bytes_in / _rate_timer
		_bytes_out = 0
		_bytes_in = 0
		_rate_timer = 0.0


func _host_tick(delta: float) -> void:
	for slot: int in _disconnect_timers.keys():
		_disconnect_timers[slot] -= delta
		if _disconnect_timers[slot] <= 0.0:
			_remove_slot(slot)
	if _slot_by_peer.is_empty():
		_fx_batch.clear()
		return
	if not _fx_batch.is_empty():
		_send(0, &"rpc_fx", [_fx_batch])
		_fx_batch = []
	if _timers.player >= PLAYER_INTERVAL:
		_timers.player = 0.0
		_send(0, &"rpc_players", [_players_state()])
	if _timers.world >= WORLD_INTERVAL:
		_timers.world = 0.0
		_send(0, &"rpc_world", [_world_state()])
	if _timers.enemy >= ENEMY_INTERVAL:
		_timers.enemy = 0.0
		var enemies: Array = get_tree().get_nodes_in_group("enemies")
		for i in range(0, enemies.size(), ENEMY_CHUNK):
			_send(0, &"rpc_enemies", [NetCodec.encode_enemies(enemies.slice(i, i + ENEMY_CHUNK))])


func _client_tick() -> void:
	if not welcomed:
		if _timers.hello >= HELLO_RETRY:
			_timers.hello = 0.0
			_send(1, &"rpc_hello", [NetConfig.reconnect_token, NetConfig.player_name, NetConfig.character_id,
					NetConfig.map_id, Talents.ranks(NetConfig.character_id)])
		return
	var p: CharacterBody3D = local_player
	if p.ai_controlled and p.bot != null:
		p.bot.think(p, get_tree().get_nodes_in_group("enemy_views"))
	var dir: Vector3 = p.move_override.normalized() if p.move_override != Vector3.ZERO else p.keyboard_direction()
	p.net_input_seq += 1
	p.record_prediction(p.net_input_seq)
	_send(1, &"rpc_input", [p.net_input_seq, dir, p.facing])
	if _timers.ping >= 1.0:
		_timers.ping = 0.0
		_send(1, &"rpc_ping", [Time.get_ticks_msec()])


## 客户端发送一次动作（技能、闪避、升级选择、自动施放开关）。
func send_action(kind: Action, value: int) -> void:
	if is_client() and welcomed:
		_send(1, &"rpc_action", [kind, value])


# ---------- 主机收到的 RPC ----------

@rpc("any_peer", "call_remote", "reliable")
func rpc_hello(token: String, display: String, char_id: String = CharacterCatalog.DEFAULT_ID,
		map_id: String = MapCatalog.DEFAULT_ID, talents: Dictionary = {}) -> void:
	if not is_host():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	if _slot_by_peer.has(peer):
		return  # 重复的 hello（客户端重试）
	if map_id != NetConfig.map_id:
		_send(peer, &"rpc_map", [NetConfig.map_id])  # 先换图，换好后客户端会再发 hello
		return
	var slot: int = int(_slot_by_token.get(token, -1))
	var reconnect: bool = slot >= 0 and players_by_slot.has(slot)
	if not reconnect:
		slot = _free_slot()
		if slot < 0:
			rpc_id(peer, &"rpc_reject", "房间已满")
			return
	_slot_by_token[token] = slot
	var stale: int = int(_peer_by_slot.get(slot, 0))
	if stale != 0 and stale != peer:
		_slot_by_peer.erase(stale)  # 旧连接还没超时就重连了：旧 peer 之后的掉线事件不再影响这个槽位
	_slot_by_peer[peer] = slot
	_peer_by_slot[slot] = peer
	var player: CharacterBody3D = players_by_slot.get(slot)
	if player == null:
		var cid: String = char_id if CharacterCatalog.is_valid(char_id) else CharacterCatalog.DEFAULT_ID
		player = _spawn_remote(slot, display, cid, Talents.sanitize(cid, talents))
		_pending_upgrades[slot] = session.get_player_level() - 1  # 中途加入：补齐已错过的升级
	else:
		player.ai_controlled = false
		player.bot = null
		player.move_override = Vector3.ZERO
		_disconnect_timers.erase(slot)
	player.display_name = display
	print("[net] %s slot=%d peer=%d %s" % [display, slot, peer, "reconnected" if reconnect else "joined"])
	_send(peer, &"rpc_welcome", [slot, _full_state(player)])
	broadcast_toast("%s %s" % [display, "重新连接" if reconnect else "加入了游戏"])
	if int(_pending_upgrades.get(slot, 0)) > 0:
		_offer_upgrade(slot)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func rpc_input(seq: int, move: Vector3, facing_dir: Vector3) -> void:
	var player: CharacterBody3D = _sender_player()
	if player == null:
		return
	_count_in([seq, move, facing_dir])
	player.apply_net_input(seq, move.limit_length(1.0), facing_dir)


@rpc("any_peer", "call_remote", "reliable")
func rpc_action(kind: int, value: int) -> void:
	var player: CharacterBody3D = _sender_player()
	if player == null:
		return
	match kind:
		Action.SKILL:
			if value >= 0 and value < player.ability_system.pool().size() and not player.is_dead:
				player.cast_skill(player.ability_system.pool()[value])
		Action.DODGE:
			if not player.is_dead:
				player.dodge()
		Action.UPGRADE:
			_on_upgrade_pick(player.net_slot, value)
		Action.AUTO_CAST:
			player.auto_cast = value != 0


@rpc("any_peer", "call_remote", "reliable")
func rpc_ping(client_ms: int) -> void:
	var peer: int = multiplayer.get_remote_sender_id()
	if _slot_by_peer.has(peer):
		_send(peer, &"rpc_pong", [client_ms])


func _sender_player() -> CharacterBody3D:
	var slot: int = int(_slot_by_peer.get(multiplayer.get_remote_sender_id(), -1))
	return players_by_slot.get(slot) if slot > 0 else null


func _free_slot() -> int:
	for slot in range(1, NetConfig.MAX_CLIENTS + 1):
		if not players_by_slot.has(slot):
			return slot
	return -1


func _spawn_remote(slot: int, display: String, char_id: String, talents: Dictionary = {}) -> CharacterBody3D:
	var p: CharacterBody3D = PlayerScene.instantiate()
	p.name = "Player_%d" % slot
	p.character_id = char_id
	p.set_talents(talents)
	p.control = p.ControlMode.REMOTE
	p.net_slot = slot
	scene.add_child(p)
	p.global_position = local_player.global_position + Vector3(2.0 * slot, 0, 2.0)
	_register_player(slot, p, display)
	scene.register_player(p)
	return p


## 掉线：AI 托管 30 秒，期间用同一令牌重连可以接管回来。
func _on_peer_disconnected(peer: int) -> void:
	var slot: int = int(_slot_by_peer.get(peer, -1))
	_slot_by_peer.erase(peer)
	if slot < 0 or int(_peer_by_slot.get(slot, 0)) != peer:
		return
	_peer_by_slot.erase(slot)
	var player: CharacterBody3D = players_by_slot.get(slot)
	if player == null:
		return
	player.ai_controlled = true
	player.bot = PlayerBot.new()
	_disconnect_timers[slot] = DISCONNECT_GRACE
	while int(_pending_upgrades.get(slot, 0)) > 0:
		_on_upgrade_pick(slot, 0)
	print("[net] %s (slot %d) disconnected, AI takeover %.0fs" % [player.display_name, slot, DISCONNECT_GRACE])
	broadcast_toast("%s 掉线，AI 托管 %d 秒" % [player.display_name, int(DISCONNECT_GRACE)])


func _remove_slot(slot: int) -> void:
	_disconnect_timers.erase(slot)
	var player: CharacterBody3D = players_by_slot.get(slot)
	players_by_slot.erase(slot)
	for t: String in _slot_by_token.keys():
		if _slot_by_token[t] == slot:
			_slot_by_token.erase(t)
	if player != null:
		print("[net] slot %d removed after grace period" % slot)
		broadcast_toast("%s 已离开" % player.display_name)
		player.queue_free()


# ---------- 主机：升级、提示、结算 ----------

## 共享等级升级：远程玩家各自选择（AI 托管时自动选第一项）。
func queue_upgrade(slot: int) -> void:
	var player: CharacterBody3D = players_by_slot.get(slot)
	if player == null:
		return
	if player.ai_controlled:
		UpgradeSystem.apply(UpgradeSystem.roll_choices(player.ability_system, player.stats, _rng)[0],
				player.ability_system, player.stats)
		return
	_pending_upgrades[slot] = int(_pending_upgrades.get(slot, 0)) + 1
	if not _offered.has(slot):
		_offer_upgrade(slot)


func _offer_upgrade(slot: int) -> void:
	var player: CharacterBody3D = players_by_slot.get(slot)
	if player == null or not _peer_by_slot.has(slot):
		return
	var choices: Array[Dictionary] = UpgradeSystem.roll_choices(player.ability_system, player.stats, _rng)
	_offered[slot] = choices
	_send(_peer_by_slot[slot], &"rpc_upgrade_choices", [choices, int(_pending_upgrades.get(slot, 1))])


func _on_upgrade_pick(slot: int, index: int) -> void:
	var player: CharacterBody3D = players_by_slot.get(slot)
	if player == null or int(_pending_upgrades.get(slot, 0)) <= 0:
		return
	var choices: Array = _offered.get(slot, UpgradeSystem.roll_choices(player.ability_system, player.stats, _rng))
	_offered.erase(slot)
	var choice: Dictionary = choices[clampi(index, 0, choices.size() - 1)]
	UpgradeSystem.apply(choice, player.ability_system, player.stats)
	_pending_upgrades[slot] = int(_pending_upgrades[slot]) - 1
	print("[net] slot %d upgrade: %s" % [slot, choice.title])
	if int(_pending_upgrades[slot]) > 0:
		_offer_upgrade(slot)


func toast_to(slot: int, text: String) -> void:
	if slot == my_slot:
		toast_received.emit(text)
	elif is_host() and _peer_by_slot.has(slot):
		_send(_peer_by_slot[slot], &"rpc_toast", [text])


func broadcast_toast(text: String) -> void:
	toast_received.emit(text)
	if is_host():
		_send(0, &"rpc_toast", [text])


func broadcast_game_over(reason: String, victory: bool) -> void:
	if is_host():
		_flush_fx_now()
		_send(0, &"rpc_game_over", [reason, victory])


func broadcast_restart() -> void:
	if is_host():
		_send(0, &"rpc_restart", [])


func _flush_fx_now() -> void:
	if not _fx_batch.is_empty() and not _slot_by_peer.is_empty():
		_send(0, &"rpc_fx", [_fx_batch])
	_fx_batch = []


# ---------- 主机：状态打包 ----------

## [slot, 名字, 位置, 朝向角, 生命, 最大生命, 护盾, 怒气, 倒地, 救援进度, 托管, 已确认输入序号,
##  闪避冷却, 光环剩余, 技能等级[6], 技能冷却[6], 角色 id]
func _players_state() -> Array:
	var out: Array = []
	for slot: int in players_by_slot:
		var p: CharacterBody3D = players_by_slot[slot]
		var levels: PackedByteArray = PackedByteArray()
		var cds: PackedFloat32Array = PackedFloat32Array()
		for id: String in p.ability_system.pool():
			levels.append(p.ability_system.get_level(id))
			cds.append(p.ability_system.get_cooldown_remaining(id))
		out.append([slot, p.display_name, p.global_position, p.rotation.y, p.stats.health, p.stats.max_health,
			p.stats.shield, p.stats.rage, p.is_dead, p.revive_progress, p.ai_controlled, p.net_input_seq,
			p.dodge_cooldown_remaining, p.stats.aura_remaining, levels, cds, p.character_id])
	return out


## [时间, 等级, 经验, 进行中, 击杀, 敌人数, Boss信息, {slot: [装备, 被动]}]
func _world_state() -> Array:
	var loadouts: Dictionary = {}
	for slot: int in players_by_slot:
		var p: CharacterBody3D = players_by_slot[slot]
		loadouts[slot] = [p.stats.equipment.keys(), p.stats.passives.keys()]
	return [session.get_game_time(), session.get_player_level(), session.get_player_exp(), session.is_running,
		spawner.kills, spawner.get_enemy_count(), spawner.get_boss_info(), loadouts, _pickups_state()]


func _pickups_state() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group("pickups"):
		out.append([n.get_instance_id(), n.kind, n.item_id, n.global_position])
	return out


func _full_state(p: CharacterBody3D) -> Dictionary:
	return {"players": _players_state(), "world": _world_state(), "position": p.global_position}


# ---------- 客户端收到的 RPC ----------

@rpc("authority", "call_remote", "reliable")
func rpc_reject(reason: String) -> void:
	_leave("主机拒绝加入：%s" % reason)


## 主机的地图和本地不同：换成主机的地图重新载入场景（连接保留，重载后重新 hello）。
@rpc("authority", "call_remote", "reliable")
func rpc_map(map_id: String) -> void:
	if welcomed or not MapCatalog.is_valid(map_id) or map_id == NetConfig.map_id:
		return
	print("[net] host map is %s, reloading" % map_id)
	NetConfig.map_id = map_id
	get_tree().reload_current_scene.call_deferred()


@rpc("authority", "call_remote", "reliable")
func rpc_welcome(slot: int, state: Dictionary) -> void:
	_count_in([slot, state])
	my_slot = slot
	welcomed = true
	_register_player(slot, local_player, NetConfig.player_name)
	local_player.global_position = state.position
	local_player.net_target_position = state.position
	_apply_players(state.players, true)
	_apply_world(state.world)
	print("[net] welcomed as slot %d" % slot)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func rpc_players(states: Array) -> void:
	_count_in(states)
	if welcomed:
		_apply_players(states, false)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func rpc_enemies(buf: PackedByteArray) -> void:
	_bytes_in += buf.size()
	if welcomed and enemy_views != null:
		enemy_views.apply(NetCodec.decode_enemies(buf))


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func rpc_world(state: Array) -> void:
	_count_in(state)
	if welcomed:
		_apply_world(state)


@rpc("authority", "call_remote", "reliable")
func rpc_fx(events: Array) -> void:
	_count_in(events)
	for ev: Array in events:
		_replay_fx(ev)


@rpc("authority", "call_remote", "reliable")
func rpc_toast(text: String) -> void:
	toast_received.emit(text)


@rpc("authority", "call_remote", "reliable")
func rpc_upgrade_choices(choices: Array, remaining: int) -> void:
	upgrade_choices_received.emit(choices, remaining)


@rpc("authority", "call_remote", "reliable")
func rpc_game_over(reason: String, victory: bool) -> void:
	session.end_game(reason, victory)
	game_over_received.emit(reason, victory)


@rpc("authority", "call_remote", "reliable")
func rpc_restart() -> void:
	welcomed = false
	get_tree().paused = false
	get_tree().reload_current_scene()


@rpc("authority", "call_remote", "reliable")
func rpc_pong(client_ms: int) -> void:
	var rtt: float = float(Time.get_ticks_msec() - client_ms)
	ping_ms = rtt if ping_ms <= 0.0 else lerpf(ping_ms, rtt, 0.3)


# ---------- 客户端：应用状态 ----------

func _apply_players(states: Array, snap: bool) -> void:
	var seen: Dictionary = {}
	for st: Array in states:
		var slot: int = st[0]
		seen[slot] = true
		var p: CharacterBody3D = players_by_slot.get(slot)
		if p == null:
			p = _spawn_puppet(slot, st[1], st[2], st[16] if st.size() > 16 else CharacterCatalog.DEFAULT_ID)
		var is_me: bool = slot == my_slot
		p.display_name = st[1]
		if st[4] < p.stats.health - 0.5:
			p.flash_hurt()
			if is_me and not snap:
				p.hurt.emit(p.stats.health - float(st[4]))
		p.stats.health = st[4]
		p.stats.max_health = st[5]
		p.stats.shield = st[6]
		p.stats.rage = st[7]
		if st[8] and not p.is_dead:
			p.is_dead = true
		elif not st[8] and p.is_dead:
			p.is_dead = false
		p.revive_progress = st[9]
		p.stats.aura_remaining = st[13]
		_apply_skills(p, st[14], st[15])
		if is_me:
			p.server_ack(st[11], st[2])
			_max_correction = maxf(_max_correction * 0.99, p.last_prediction_error)
			p.net_target_position = st[2]
			if snap:
				p.global_position = st[2]
			if p.dodge_cooldown_remaining <= 0.0 or st[12] <= 0.0:
				p.dodge_cooldown_remaining = st[12]
		else:
			p.ai_controlled = st[10]
			p.net_target_position = st[2]
			p.net_target_rotation = st[3]
	for slot: int in players_by_slot.keys():
		if not seen.has(slot) and slot != my_slot:
			players_by_slot[slot].queue_free()
			players_by_slot.erase(slot)


func _apply_skills(p: CharacterBody3D, levels: PackedByteArray, cds: PackedFloat32Array) -> void:
	var pool: Array[String] = p.ability_system.pool()
	for i in mini(pool.size(), levels.size()):
		var id: String = pool[i]
		var lv: int = levels[i]
		if lv <= 0:
			continue
		if p.ability_system.get_skill(id) == null:
			p.ability_system.add_skill(SkillFactory.create(id))
		p.ability_system.set_level(id, lv)
		p.ability_system.set_cooldown_remaining(id, cds[i])


func _spawn_puppet(slot: int, display: String, pos: Vector3, char_id: String) -> CharacterBody3D:
	var p: CharacterBody3D = PlayerScene.instantiate()
	p.name = "Player_%d" % slot
	p.character_id = char_id
	p.control = p.ControlMode.PUPPET
	p.net_slot = slot
	scene.add_child(p)
	p.global_position = pos
	_register_player(slot, p, display)
	return p


func _apply_world(w: Array) -> void:
	session.game_time = w[0]
	session.player_level = w[1]
	session.player_exp = w[2]
	session.is_running = w[3] and session.end_reason.is_empty()
	spawner.kills = w[4]
	spawner.net_enemy_count = w[5]
	spawner.net_boss_info = w[6]
	var loadouts: Dictionary = w[7]
	for slot: Variant in loadouts:
		var p: CharacterBody3D = players_by_slot.get(int(slot))
		if p == null:
			continue
		var equip: Dictionary = {}
		for id: String in loadouts[slot][0]:
			equip[id] = true
		var passives: Dictionary = {}
		for id: String in loadouts[slot][1]:
			passives[id] = true
		p.stats.equipment = equip
		p.stats.passives = passives
	_apply_pickups(w[8])


func _apply_pickups(list: Array) -> void:
	var seen: Dictionary = {}
	for item: Array in list:
		var id: int = item[0]
		seen[id] = true
		var view: Node3D = _pickup_views.get(id)
		if view == null or not is_instance_valid(view):
			view = PickupScript.new()
			view.setup(item[1], item[2], 0.0)
			view.visual_only = true
			scene.add_child(view)
			_pickup_views[id] = view
		view.global_position = item[3]
	for id: int in _pickup_views.keys():
		if not seen.has(id):
			if is_instance_valid(_pickup_views[id]):
				_pickup_views[id].queue_free()
			_pickup_views.erase(id)


## 回放主机录下的特效/音效/生成事件（只显示，不结算）。
func _replay_fx(ev: Array) -> void:
	match ev[0]:
		"cone":
			SkillVfx.shield_bash(scene, ev[1], ev[2], ev[3], ev[4])
		"shock":
			SkillVfx.shockwave(scene, ev[1], ev[2], ev[3], ev[4])
		"burst":
			ParticleFx.burst(scene, ev[1], ev[2], ev[3], ev[4])
		"arc":
			SkillVfx.arc(scene, ev[1], ev[2], ev[3])
		"shake":
			if int(ev[2]) == my_slot or int(ev[2]) < 0:
				SkillVfx.shake_local(get_tree(), ev[1])
		"whirl":
			var caster: Node3D = players_by_slot.get(int(ev[1]))
			if caster != null:
				SkillVfx.whirlwind(scene, caster, ev[2], ev[3], ev[4])
		"zone":
			SkillVfx.ground_zone(scene, ev[1], ev[2], ev[3], ev[4], ev[5])
		"ring":
			SkillVfx.pulse_ring(scene, ev[1], ev[2], ev[3], ev[4])
		"trail":
			SkillVfx.dash_trail(scene, ev[1], ev[2], ev[3], ev[4])
		"pillar":
			SkillVfx.pillar(scene, ev[1], ev[2], ev[3], ev[4])
		"sfx":
			SfxManager.play(scene, ev[1])
		"dead":
			if enemy_views != null:
				enemy_views.remove(int(ev[1]), true)
		"proj":
			var pr: Node3D = ProjectileScript.new()
			pr.setup(null, ev[2], 0.0, ev[3] if ev.size() > 3 else Color(0.4, 1.0, 0.3))
			pr.visual_only = true
			scene.add_child(pr)
			pr.global_position = ev[1]
		"hazard":
			var hz: Node3D = HazardScript.new()
			hz.setup(ev[2], 0.0, ev[3], ev[4] if ev.size() > 4 else Color(0.6, 0.65, 0.1, 0.35))
			hz.visual_only = true
			scene.add_child(hz)
			hz.global_position = ev[1]
		"blast":
			var bl: Node3D = BlastScript.new()
			bl.setup(ev[2], 0.0, ev[3], "")
			if ev.size() > 4:
				bl.color = ev[4]
			bl.visual_only = true
			scene.add_child(bl)
			bl.global_position = ev[1]
		"telegraph":
			if enemy_views != null:
				enemy_views.show_telegraph(ev[1], ev[2], ev[3], ev[4])


## F3 调试面板文字。
func debug_text() -> String:
	var role: String = "主机" if is_host() else "客户端"
	var lines: PackedStringArray = [
		"[联机] %s  槽位 %d  延迟模拟 %dms" % [role, my_slot, NetConfig.lag_ms],
		"上行 %.1f KB/s  下行 %.1f KB/s" % [_rate_out / 1024.0, _rate_in / 1024.0],
	]
	if is_client():
		lines.append("往返 %.0f ms  预测误差 %.2f m  敌人视图 %d" % [ping_ms, _max_correction,
				enemy_views.count() if enemy_views else 0])
	for slot: int in players_by_slot:
		var p: CharacterBody3D = players_by_slot[slot]
		var extra: String = ""
		if is_host() and _disconnect_timers.has(slot):
			extra = "  掉线托管 %.0fs" % _disconnect_timers[slot]
		elif p.ai_controlled:
			extra = "  AI"
		lines.append("  #%d %s  HP %d%s%s" % [slot, p.display_name, p.stats.health, "  倒地" if p.is_dead else "", extra])
	return "\n".join(lines)


## 测试用状态摘要（host/client 对比一致性）。
func report() -> Dictionary:
	var players: Dictionary = {}
	for slot: int in players_by_slot:
		var p: CharacterBody3D = players_by_slot[slot]
		var levels: Array = []
		for id: String in p.ability_system.pool():
			levels.append(p.ability_system.get_level(id))
		players[str(slot)] = {"pos": [p.global_position.x, p.global_position.z], "hp": p.stats.health,
			"dead": p.is_dead, "skills": levels, "equip": p.stats.equipment.size(), "ai": p.ai_controlled}
	var boss: Dictionary = spawner.get_boss_info()
	return {
		"role": "host" if is_host() else "client", "slot": my_slot, "welcomed": welcomed,
		"time": session.get_game_time(), "level": session.get_player_level(), "running": session.is_running,
		"kills": spawner.kills, "enemies": spawner.get_enemy_count(),
		"enemy_views": enemy_views.count() if enemy_views else -1,
		"boss_hp": boss.get("hp", -1.0), "boss_phase": boss.get("phase", 0), "players": players,
		"ping": ping_ms, "pred_error": _max_correction, "fps": Engine.get_frames_per_second(), "kb_in": _rate_in / 1024.0, "kb_out": _rate_out / 1024.0,
	}
