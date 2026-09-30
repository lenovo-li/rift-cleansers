extends SceneTree
## P2P（WebRTC）本机回环测试：同一进程里房主和好友走一遍 邀请码 → 回应码 → 连接，
## 然后在每个通道（可靠 + RPC 用的 1-3）上互发数据包。
## 用法: godot --headless --path . --script res://tests/p2p_loopback.gd
## 同时打印候选里有没有公网地址（srflx），用来判断 STUN 是否可用。

var host: WebRTCMultiplayerPeer
var client: WebRTCMultiplayerPeer
var invite: P2PLink
var joiner: P2PLink
var t: float = 0.0
var stage: String = "offer"
var got: Dictionary = {}  # 通道 -> 是否收到
var fails: PackedStringArray = []


func _init() -> void:
	host = P2PLink.create_host_peer()
	invite = P2PLink.invite(host)


func _process(delta: float) -> bool:
	t += delta
	host.poll()
	if client != null:
		client.poll()
	invite.update(delta)
	if joiner != null:
		joiner.update(delta)
	match stage:
		"offer":
			if not invite.code.is_empty():
				print("邀请码 %d 字符，srflx=%s" % [invite.code.length(), _has_srflx(invite.code)])
				_check_bad_codes()
				joiner = P2PLink.join(invite.code)
				if not joiner.error.is_empty():
					return _finish("join 失败：" + joiner.error)
				client = joiner.client_peer
				stage = "answer"
		"answer":
			if not joiner.code.is_empty():
				print("回应码 %d 字符" % joiner.code.length())
				var err: String = invite.accept_answer(joiner.code)
				if not err.is_empty():
					return _finish("accept 失败：" + err)
				stage = "connect"
		"connect":
			if client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and host.has_peer(joiner.peer_id) \
					and invite.is_connected_peer():
				print("连接建立，用时 %.2fs" % t)
				for ch in 4:
					client.set_transfer_channel(ch)
					client.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE if ch == 0 \
							else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
					client.set_target_peer(1)
					client.put_packet(PackedByteArray([ch, 42]))
				stage = "data"
		"data":
			while host.get_available_packet_count() > 0:
				var ch: int = host.get_packet_channel()
				var from: int = host.get_packet_peer()
				var pkt: PackedByteArray = host.get_packet()
				got[pkt[0]] = pkt.size() == 2 and pkt[1] == 42 and from == joiner.peer_id
				if ch != pkt[0]:
					fails.append("通道 %d 的包从通道 %d 收到" % [pkt[0], ch])
			if got.size() == 4:
				for ch: int in got:
					if not got[ch]:
						fails.append("通道 %d 内容不对" % ch)
				return _finish("")
	if t > 20.0:
		return _finish("超时（阶段 %s）" % stage)
	return false


func _check_bad_codes() -> void:
	if not P2PLink.decode("垃圾").is_empty() or not P2PLink.decode("LJ1-!!!").is_empty():
		fails.append("无效连接码应该解码为空")
	if P2PLink.join("LJ1-abc").error.is_empty():
		fails.append("无效邀请码应该报错")
	var wrapped: String = invite.code.substr(0, 50) + "\n  " + invite.code.substr(50)
	if P2PLink.decode(wrapped).is_empty():
		fails.append("带换行空格的连接码应能解码")
	if invite.accept_answer(invite.code).is_empty():
		fails.append("把邀请码当回应码应该报错")


func _has_srflx(code: String) -> bool:
	for c: Array in P2PLink.decode(code).get("c", []):
		if " srflx " in str(c[2]):
			return true
	return false


func _finish(err: String) -> bool:
	if not err.is_empty():
		fails.append(err)
	for f in fails:
		printerr("FAIL ", f)
	print("结果: ", "PASS" if fails.is_empty() else "FAIL")
	host.close()
	if client != null:
		client.close()
	quit(0 if fails.is_empty() else 1)
	return true
