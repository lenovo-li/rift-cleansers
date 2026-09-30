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
