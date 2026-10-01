extends RefCounted
## P2P 连接码的编解码与校验（不建立真实连接，连接流程见 tests/p2p_loopback.gd）。


func _code(t: String, extra: Dictionary = {}) -> String:
	var d: Dictionary = {"v": P2PLink.PROTOCOL, "ver": P2PLink.game_version(), "t": t, "id": 12345,
		"sdp": "v=0", "c": [["0", 0, "candidate:1 1 UDP 1 192.168.1.2 5000 typ host"]]}
	d.merge(extra, true)
	return P2PLink.encode(d)


func test_roundtrip_and_whitespace() -> String:
	var code: String = _code("offer")
	if not code.begins_with(P2PLink.CODE_PREFIX):
		return "缺少前缀"
	var d: Dictionary = P2PLink.decode(code)
	if d.get("sdp") != "v=0" or int(d.get("id", 0)) != 12345 or (d.get("c") as Array).size() != 1:
		return "往返后内容不一致: %s" % d
	var messy: String = "  " + code.substr(0, 10) + "\r\n" + code.substr(10, 7) + " " + code.substr(17) + "\n"
	if P2PLink.decode(messy) != d:
		return "聊天软件里断行、加空格后应能还原"
	return ""


func test_invalid_codes() -> String:
	for bad: String in ["", "hello", "LJ1-", "LJ1-@@@@", "LJ1-abc", "LJ0-" + _code("offer").substr(4)]:
		if not P2PLink.decode(bad).is_empty():
			return "应当解码失败: %s" % bad
	var truncated: String = _code("offer")
	truncated = truncated.substr(0, truncated.length() - 8)
	if not P2PLink.decode(truncated).is_empty():
		return "复制不完整的码应当解码失败"
	return ""


func test_validate_type_version_id() -> String:
	if not P2PLink._validate(P2PLink.decode(_code("offer")), "offer").is_empty():
		return "正常邀请码应当通过"
	if P2PLink._validate(P2PLink.decode(_code("answer")), "offer").is_empty():
		return "回应码不能当邀请码用"
	if P2PLink._validate(P2PLink.decode(_code("offer", {"ver": "0.0.0-old"})), "offer").find("版本") < 0:
		return "版本不同应提示版本"
	if P2PLink._validate(P2PLink.decode(_code("offer", {"id": 1})), "offer").is_empty():
		return "peer id 1 是房主，不能分配给好友"
	if P2PLink._validate({"t": "offer"}, "offer").is_empty():
		return "缺字段应当报错"
	return ""


func test_join_rejects_bad_code_without_peer() -> String:
	var link: P2PLink = P2PLink.join("LJ1-abcd")
	if link.error.is_empty() or link.client_peer != null:
		return "无效邀请码不应创建连接"
	return ""


func test_turn_config_parsing() -> String:
	var good: Array = P2PLink.parse_turn_config(JSON.stringify({"iceServers": [
		{"urls": ["turn:a.example:80", "turns:a.example:443?transport=tcp", "stun:a.example:3478"],
			"username": "u", "credential": "p"},
		{"urls": "turn:b.example:3478", "username": "u2", "credential": "p2"},
		{"urls": ["turn:no-auth.example:80"]},
		{"urls": ["stun:only-stun.example:3478"], "username": "u", "credential": "p"},
		"垃圾"]}))
	if good.size() != 2:
		return "应保留 2 个带账号的 TURN，实际 %d: %s" % [good.size(), good]
	if (good[0].urls as Array).size() != 2 or good[1].urls != ["turn:b.example:3478"]:
		return "urls 过滤或字符串形式处理不对: %s" % good
	if not P2PLink.parse_turn_config("{坏的").is_empty() or not P2PLink.parse_turn_config("[]").is_empty():
		return "格式错误应返回空"
	return ""


func test_ice_servers_include_override() -> String:
	P2PLink.override_turn([{"urls": ["turn:x.example:80"], "username": "u", "credential": "p"}])
	var all: Array = P2PLink.ice_servers()
	P2PLink.override_turn(null)
	if all.size() != P2PLink.STUN_SERVERS.size() + 1 or all[-1].urls != ["turn:x.example:80"]:
		return "TURN 应排在 STUN 之后: %s" % all
	return ""


func test_candidate_type() -> String:
	var cases: Dictionary = {
		"candidate:1 1 UDP 2114977791 192.168.1.2 64203 typ host": "host",
		"candidate:4 1 UDP 1678769407 27.38.173.98 13353 typ srflx raddr 0.0.0.0 rport 0": "srflx",
		"candidate:5 1 UDP 8331263 37.27.44.221 51000 typ relay raddr 27.38.173.98 rport 13353": "relay",
		"乱码": "?"}
	for c: String in cases:
		if P2PLink.candidate_type(c) != cases[c]:
			return "%s → %s，期望 %s" % [c, P2PLink.candidate_type(c), cases[c]]
	return ""
