class_name P2PLink extends RefCounted
## P2P 联机（WebRTC）的一条连接和它的信令。没有信令服务器：双方靠复制粘贴「连接码」交换 SDP 与 ICE 候选。
## 流程：房主 invite() 生成邀请码 → 好友 join(邀请码) 生成回应码 → 房主 accept_answer(回应码) → 连上。
## 连上后和 ENet 一样走 NetSession 的 RPC（房主 peer id 为 1）。WebRTC 自带 DTLS 加密，
## 只有拿到这次邀请码的人能连上；连接码里包含双方的内网/公网 IP，只发给信任的人。
## 连接本身由 WebRTCMultiplayerPeer 在每帧 poll 时驱动，这里只需要调用 update() 等候选收集完。
##
## 失败时会保存日志到 user://p2p_logs/，玩家可把日志文件发给开发者排查问题。

signal code_ready(code: String)

const CODE_PREFIX: String = "LJ1-"
const PROTOCOL: int = 1
## 公共 STUN（只用来探测自己的公网地址，不转发游戏数据）。国内可用的放前面，不通的会被跳过。
const STUN_SERVERS: Array = [
	{"urls": ["stun:stun.miwifi.com:3478"]},
	{"urls": ["stun:stun.chat.bilibili.com:3478"]},
	{"urls": ["stun:stun.cloudflare.com:3478"]},
	{"urls": ["stun:stun.l.google.com:19302"]},
]
## TURN 中转（双方都无法直连时转发数据）需要账号，不进仓库。按顺序找第一个存在的文件：
## exe 同目录（打包后可直接改）→ res://（打包时一起带上，被 .gitignore 忽略）。
## 格式：{"iceServers": [{"urls": ["turn:host:port"], "username": "...", "credential": "..."}]}
const TURN_CONFIG_FILE: String = "ice_servers.json"
## 候选收集最多等这么久（有 STUN 不通时收集状态可能迟迟不完成，已拿到的候选通常足够）。
## TURN 分配要多一次往返，所以有 TURN 时等久一点。
const GATHER_TIMEOUT: float = 4.0
const GATHER_TIMEOUT_TURN: float = 6.0

## 测试用：只交换中转候选，强制数据走 TURN（验证中转可用）。
static var relay_only: bool = false
static var _turn_cache: Array = []
static var _turn_loaded: bool = false

const LOG_DIR: String = "user://p2p_logs"
const MAX_LOGS: int = 20

var peer_id: int = 0
var conn: WebRTCPeerConnection = null
## join() 创建的客户端 MultiplayerPeer，调用方赋给 multiplayer.multiplayer_peer。
var client_peer: WebRTCMultiplayerPeer = null
## 非空表示连接码无效（join / accept_answer 的错误信息）。
var error: String = ""
var code: String = ""
var answered: bool = false
var _is_offer: bool = false
var _sdp: String = ""
var _cands: Array = []
var _elapsed: float = 0.0
var _log_lines: PackedStringArray = []
var _log_start: float = 0.0


## RPC 用到的通道 1-3（unreliable_ordered），两端配置必须一致。
static func channels() -> Array:
	return [MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED]


static func create_host_peer() -> WebRTCMultiplayerPeer:
	var mp: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
	mp.create_server(channels())
	return mp


## 房主：为一位好友创建连接并开始生成邀请码（稍后 code_ready）。
static func invite(host_peer: WebRTCMultiplayerPeer) -> P2PLink:
	var link: P2PLink = P2PLink.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	link.peer_id = rng.randi_range(2, 0x7fffffff)
	link._is_offer = true
	link._start_log(true)
	link._init_conn()
	host_peer.add_peer(link.conn, link.peer_id)
	link.conn.create_offer()
	return link


## 好友：用邀请码创建客户端连接并开始生成回应码。失败时 error 非空。
static func join(offer_code: String) -> P2PLink:
	var link: P2PLink = P2PLink.new()
	link._start_log(false)
	var d: Dictionary = decode(offer_code)
	link.error = _validate(d, "offer")
	if not link.error.is_empty():
		link._log_event("邀请码验证失败: %s" % link.error)
		return link
	link.peer_id = int(d.id)
	link._log_event("解析邀请码成功，分配 peer_id=%d" % link.peer_id)
	link._log_remote_candidates(d.c)
	link.client_peer = WebRTCMultiplayerPeer.new()
	link.client_peer.create_client(link.peer_id, channels())
	link._init_conn()
	link.client_peer.add_peer(link.conn, 1)
	link.conn.set_remote_description("offer", d.sdp)  # 会自动生成 answer（session_description_created）
	link._add_candidates(d.c)
	return link


## 房主：填入好友的回应码。返回错误信息，空字符串表示成功（之后等待连接建立）。
func accept_answer(answer_code: String) -> String:
	var d: Dictionary = decode(answer_code)
	var err: String = _validate(d, "answer")
	if err.is_empty() and int(d.id) != peer_id:
		err = "这个回应码不是对应当前邀请码的"
	if not err.is_empty():
		_log_event("回应码验证失败: %s" % err)
		return err
	_log_event("回应码验证通过，开始连接")
	_log_remote_candidates(d.c)
	conn.set_remote_description("answer", d.sdp)
	_add_candidates(d.c)
	answered = true
	return ""


## 每帧调用：候选收集完（或超时）后生成连接码并发出 code_ready。
func update(delta: float) -> void:
	if conn == null or not code.is_empty() or _sdp.is_empty():
		return
	_elapsed += delta
	var limit: float = GATHER_TIMEOUT_TURN if not turn_servers().is_empty() else GATHER_TIMEOUT
	if conn.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE or _elapsed >= limit:
		_log_local_candidates()
		code = encode({"v": PROTOCOL, "ver": game_version(), "t": "offer" if _is_offer else "answer",
			"id": peer_id, "sdp": _sdp, "c": _cands})
		code_ready.emit(code)


func is_connected_peer() -> bool:
	return conn != null and conn.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED


func has_failed() -> bool:
	return conn != null and conn.get_connection_state() in [WebRTCPeerConnection.STATE_FAILED,
		WebRTCPeerConnection.STATE_CLOSED]


## 房主取消一个还没连上的邀请。
func cancel(host_peer: WebRTCMultiplayerPeer) -> void:
	if host_peer != null and host_peer.has_peer(peer_id) and not is_connected_peer():
		host_peer.remove_peer(peer_id)


func _init_conn() -> void:
	conn = WebRTCPeerConnection.new()
	conn.initialize({"iceServers": ice_servers()})
	conn.session_description_created.connect(func(type: String, sdp: String) -> void:
		conn.set_local_description(type, sdp)
		_sdp = sdp)
	conn.ice_candidate_created.connect(func(media: String, index: int, cand: String) -> void:
		if relay_only and candidate_type(cand) != "relay":
			return
		_cands.append([media, index, cand]))


## 本机这次收集到的候选类型统计，例如 {"host": 2, "srflx": 1, "relay": 1}。
func candidate_stats() -> Dictionary:
	var out: Dictionary = {}
	for c: Array in _cands:
		var t: String = candidate_type(str(c[2]))
		out[t] = int(out.get(t, 0)) + 1
	return out


## "candidate:... typ relay raddr ..." → "relay"
static func candidate_type(cand: String) -> String:
	var parts: PackedStringArray = cand.split(" ")
	var i: int = parts.find("typ")
	return parts[i + 1] if i >= 0 and i + 1 < parts.size() else "?"


static func ice_servers() -> Array:
	return STUN_SERVERS + turn_servers()


## 读 TURN 配置（只读一次）。文件不存在 = 不用 TURN；格式不对会打印警告并忽略。
static func turn_servers() -> Array:
	if _turn_loaded:
		return _turn_cache
	_turn_loaded = true
	for path: String in [OS.get_executable_path().get_base_dir().path_join(TURN_CONFIG_FILE),
			"res://" + TURN_CONFIG_FILE]:
		if not FileAccess.file_exists(path):
			continue
		_turn_cache = parse_turn_config(FileAccess.get_file_as_string(path))
		print("[p2p] TURN config %s: %d server(s)" % [path, _turn_cache.size()])
		break
	return _turn_cache


## 只保留 urls 是 turn:/turns: 且带账号密码的条目。
static func parse_turn_config(text: String) -> Array:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		push_warning("[p2p] %s 格式错误，忽略 TURN" % TURN_CONFIG_FILE)
		return []
	var out: Array = []
	for s: Variant in (json.data as Dictionary).get("iceServers", []):
		if not s is Dictionary:
			continue
		var urls: Array = []
		for u: Variant in (s.get("urls", []) if s.get("urls") is Array else [s.get("urls", "")]):
			if str(u).begins_with("turn:") or str(u).begins_with("turns:"):
				urls.append(str(u))
		if urls.is_empty() or str(s.get("username", "")).is_empty() or str(s.get("credential", "")).is_empty():
			continue
		out.append({"urls": urls, "username": str(s.username), "credential": str(s.credential)})
	return out


## 测试用：替换 TURN 配置（null = 恢复为从文件读取）。
static func override_turn(servers: Variant) -> void:
	_turn_loaded = servers != null
	_turn_cache = servers if servers is Array else []


func _add_candidates(list: Array) -> void:
	for c: Variant in list:
		if c is Array and c.size() == 3:
			conn.add_ice_candidate(str(c[0]), int(c[1]), str(c[2]))


static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## 连接码 = 前缀 + base64(deflate(JSON))。
static func encode(d: Dictionary) -> String:
	var raw: PackedByteArray = JSON.stringify(d).to_utf8_buffer()
	return CODE_PREFIX + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))


## 解码失败返回空字典。粘贴时混进的空白、换行会被去掉。
static func decode(text: String) -> Dictionary:
	var s: String = "".join(text.strip_edges().split("\n")).replace("\r", "").replace(" ", "")
	if not s.begins_with(CODE_PREFIX):
		return {}
	var body: String = s.substr(CODE_PREFIX.length())
	var re: RegEx = RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	if body.length() % 4 != 0 or re.search(body) == null:
		return {}  # 不是合法 base64（被截断或混入了其他字符）
	var packed: PackedByteArray = Marshalls.base64_to_raw(body)
	if packed.is_empty():
		return {}
	var raw: PackedByteArray = packed.decompress_dynamic(65536, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


## 检查解码结果，返回错误信息（空字符串表示可用）。
static func _validate(d: Dictionary, want_type: String) -> String:
	if d.is_empty() or not (d.get("sdp") is String and d.get("c") is Array and d.has("id") and d.has("t")):
		return "连接码无效，请检查是否复制完整"
	if int(d.get("v", 0)) != PROTOCOL or str(d.get("ver", "")) != game_version():
		return "双方游戏版本不同（对方 %s，本机 %s），请使用同一个版本" % [d.get("ver", "?"), game_version()]
	if str(d.t) != want_type:
		return "这是邀请码，请发给好友" if want_type == "answer" else "这是回应码，请发给房主"
	var id: int = int(d.id)
	if id < 2 or id > 0x7fffffff:
		return "连接码无效"
	return ""


## 日志相关函数

func _start_log(is_host: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_log_start = Time.get_ticks_msec() / 1000.0
	_log_lines.append("=== P2P 连接日志 ===")
	_log_lines.append("角色: %s" % ("房主" if is_host else "客户端"))
	_log_lines.append("游戏版本: %s" % game_version())
	_log_lines.append("时间: %s" % Time.get_datetime_string_from_system())
	_log_lines.append("操作系统: %s" % OS.get_name())
	var turn: Array = turn_servers()
	if turn.is_empty():
		_log_lines.append("TURN 中转: 未配置（对称 NAT 可能无法连接）")
	else:
		_log_lines.append("TURN 中转: 已配置 %d 个服务器" % turn.size())


func _log_event(msg: String) -> void:
	if _log_lines.is_empty():
		return
	_log_lines.append("[%.2fs] %s" % [(Time.get_ticks_msec() / 1000.0 - _log_start), msg])


func _log_remote_candidates(cands: Array) -> void:
	var stats: Dictionary = {}
	for c: Variant in cands:
		if c is Array and c.size() == 3:
			var t: String = candidate_type(str(c[2]))
			stats[t] = int(stats.get(t, 0)) + 1
	_log_event("对方候选: %s" % _format_candidates(stats))


func _log_local_candidates() -> void:
	var stats: Dictionary = candidate_stats()
	_log_event("本地候选: %s" % _format_candidates(stats))
	if stats.get("srflx", 0) == 0 and stats.get("relay", 0) == 0:
		_log_event("⚠️ 没有公网候选和中转候选，只能内网连接")
	elif stats.get("relay", 0) == 0 and not turn_servers().is_empty():
		_log_event("⚠️ TURN 已配置但没有中转候选，可能是 TURN 服务器不可用")


static func _format_candidates(stats: Dictionary) -> String:
	var parts: PackedStringArray = []
	for type: String in ["host", "srflx", "relay"]:
		var n: int = stats.get(type, 0)
		if n > 0:
			var name: String = {"host": "本地", "srflx": "公网", "relay": "中转"}[type]
			parts.append("%s×%d" % [name, n])
	return ", ".join(parts) if not parts.is_empty() else "无"


## 保存失败日志到 user://p2p_logs/，返回文件路径（空字符串表示未保存）
func save_failure_log(reason: String) -> String:
	if _log_lines.is_empty():
		return ""
	_log_event("❌ 连接失败: %s" % reason)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var role: String = "host" if _is_offer else "client"
	var path: String = "%s/p2p_%s_%s.log" % [LOG_DIR, role, stamp]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log_lines))
		f.close()
		_prune_logs()
		return ProjectSettings.globalize_path(path)
	return ""


## 连接成功时清空日志（不保存）
func clear_log() -> void:
	_log_lines.clear()


static func _prune_logs() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(LOG_DIR)
	files.sort()
	for i in maxi(0, files.size() - MAX_LOGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [LOG_DIR, files[i]]))


static func log_dir_global() -> String:
	return ProjectSettings.globalize_path(LOG_DIR)


## 生成连接方法描述（连上后显示）
func connection_method() -> String:
	var stats: Dictionary = candidate_stats()
	if stats.get("relay", 0) > 0:
		return "TURN 中转连接"
	elif stats.get("srflx", 0) > 0:
		return "直连（公网地址）"
	else:
		return "直连（局域网）"
