class_name P2PLink extends RefCounted
## P2P 联机（WebRTC）的一条连接和它的信令。没有信令服务器：双方靠复制粘贴「连接码」交换 SDP 与 ICE 候选。
## 流程：房主 invite() 生成邀请码 → 好友 join(邀请码) 生成回应码 → 房主 accept_answer(回应码) → 连上。
## 连上后和 ENet 一样走 NetSession 的 RPC（房主 peer id 为 1）。WebRTC 自带 DTLS 加密，
## 只有拿到这次邀请码的人能连上；连接码里包含双方的内网/公网 IP，只发给信任的人。
## 连接本身由 WebRTCMultiplayerPeer 在每帧 poll 时驱动，这里只需要调用 update() 等候选收集完。

signal code_ready(code: String)

const CODE_PREFIX: String = "LJ1-"
const PROTOCOL: int = 1
## 公共 STUN（只用来探测自己的公网地址，不转发游戏数据）。国内可用的放前面，不通的会被跳过。
const ICE_SERVERS: Array = [
	{"urls": ["stun:stun.miwifi.com:3478"]},
	{"urls": ["stun:stun.chat.bilibili.com:3478"]},
	{"urls": ["stun:stun.cloudflare.com:3478"]},
	{"urls": ["stun:stun.l.google.com:19302"]},
]
## 候选收集最多等这么久（有 STUN 不通时收集状态可能迟迟不完成，已拿到的候选通常足够）。
const GATHER_TIMEOUT: float = 4.0

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
	link._init_conn()
	host_peer.add_peer(link.conn, link.peer_id)
	link.conn.create_offer()
	return link


## 好友：用邀请码创建客户端连接并开始生成回应码。失败时 error 非空。
static func join(offer_code: String) -> P2PLink:
	var link: P2PLink = P2PLink.new()
	var d: Dictionary = decode(offer_code)
	link.error = _validate(d, "offer")
	if not link.error.is_empty():
		return link
	link.peer_id = int(d.id)
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
		return err
	conn.set_remote_description("answer", d.sdp)
	_add_candidates(d.c)
	answered = true
	return ""


## 每帧调用：候选收集完（或超时）后生成连接码并发出 code_ready。
func update(delta: float) -> void:
	if conn == null or not code.is_empty() or _sdp.is_empty():
		return
	_elapsed += delta
	if conn.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE or _elapsed >= GATHER_TIMEOUT:
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
	conn.initialize({"iceServers": ICE_SERVERS})
	conn.session_description_created.connect(func(type: String, sdp: String) -> void:
		conn.set_local_description(type, sdp)
		_sdp = sdp)
	conn.ice_candidate_created.connect(func(media: String, index: int, cand: String) -> void:
		_cands.append([media, index, cand]))


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
