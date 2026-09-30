class_name P2PPanel extends Control
## P2P 联机浮层：房主在游戏内邀请好友（邀请码 → 回应码），好友在主菜单加入（邀请码 → 回应码 → 进入游戏）。
## 连接码通过微信/QQ 之类发送。打不通（双方都是对称 NAT）时提示改用 Tailscale 之类的虚拟局域网。
## 房主打开时暂停游戏，等好友连上后关掉继续。PROCESS_MODE_ALWAYS：暂停中照样收发。

signal joined   ## 好友：已连上房主，可以进入游戏
signal closed

const HOST_CONNECT_TIMEOUT: float = 25.0
const JOIN_CONNECT_TIMEOUT: float = 60.0

var is_host: bool = true
var _link: P2PLink = null
var _out: TextEdit
var _copy_btn: Button
var _in: TextEdit
var _confirm_btn: Button
var _status: Label
var _wait: float = -1.0  # 等待连接的秒数，< 0 表示还没开始等
var _done: bool = false
var _was_paused: bool = false
var _note: String = ""  # 房主：生成新邀请码时保留在状态栏前面的上一条提示


static func build(p_is_host: bool) -> P2PPanel:
	var p: P2PPanel = P2PPanel.new()
	p.is_host = p_is_host
	return p


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -380
	box.offset_right = 380
	box.offset_top = -330
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title: Label = Label.new()
	title.text = "邀请好友（P2P）" if is_host else "加入好友的房间（P2P）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	if is_host:
		_hint(box, "① 复制邀请码发给好友")
		_out = _code_box(box, false)
		_copy_btn = _row_button(box, "复制邀请码", _copy)
		_hint(box, "② 把好友发回来的回应码粘贴到这里")
		_in = _code_box(box, true)
		_confirm_btn = _row_button(box, "粘贴并连接", _on_confirm)
	else:
		_hint(box, "① 把房主发来的邀请码粘贴到这里")
		_in = _code_box(box, true)
		_confirm_btn = _row_button(box, "粘贴并生成回应码", _on_confirm)
		_hint(box, "② 复制回应码发回给房主，等待连接")
		_out = _code_box(box, false)
		_copy_btn = _row_button(box, "复制回应码", _copy)
	_copy_btn.disabled = true
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(_status)
	_row_button(box, "完成" if is_host else "返回", _close)
	if is_host:
		_was_paused = get_tree().paused
		get_tree().paused = true
		_new_invite()
	else:
		_set_status("连接码包含你的 IP 地址，只发给信任的人")


func _process(delta: float) -> void:
	if _link == null or _done:
		return
	_link.update(delta)
	if _out.text.is_empty() and not _link.code.is_empty():
		_out.text = _link.code
		_copy_btn.disabled = false
		var msg: String = "邀请码已生成，复制发给好友" if is_host else "回应码已生成，复制发回给房主，然后等待连接…"
		_set_status(msg if _note.is_empty() else "%s\n%s" % [_note, msg])
		_note = ""
		if not is_host:
			_wait = 0.0
	if _link.is_connected_peer() and (is_host or multiplayer.multiplayer_peer.get_connection_status() \
			== MultiplayerPeer.CONNECTION_CONNECTED):
		_on_connected()
		return
	if _wait >= 0.0:
		_wait += delta
		var limit: float = HOST_CONNECT_TIMEOUT if is_host else JOIN_CONNECT_TIMEOUT
		if _link.has_failed() or _wait > limit:
			_wait = -1.0
			_note = "连接失败：双方网络可能无法直连（例如都在运营商 NAT 后面）。\n" + \
					"可以重试一次，或者改用 Tailscale / ZeroTier 等虚拟局域网，再用「局域网」方式联机"
			_set_status(_note)
			if is_host:
				_new_invite()  # 新邀请码生成后提示会接在 _note 后面


func _on_confirm() -> void:
	var text: String = _in.text.strip_edges()
	if text.is_empty():
		text = DisplayServer.clipboard_get().strip_edges()
		_in.text = text
	if is_host:
		var err: String = _link.accept_answer(text) if _link != null else "邀请码还没生成"
		if not err.is_empty():
			_set_status(err)
			return
		_wait = 0.0
		_confirm_btn.disabled = true
		_set_status("正在连接…")
		return
	var link: P2PLink = P2PLink.join(text)
	if not link.error.is_empty():
		_set_status(link.error)
		return
	_drop_client_peer()
	_link = link
	multiplayer.multiplayer_peer = link.client_peer
	_out.text = ""
	_copy_btn.disabled = true
	_set_status("正在生成回应码…")


func _on_connected() -> void:
	if is_host:
		var n: int = (multiplayer.multiplayer_peer as WebRTCMultiplayerPeer).get_peers().size()
		_note = "好友已连上（当前 %d 位好友）。点「完成」继续游戏，或者把新邀请码发给下一位" % n
		_set_status(_note)
		_new_invite()
		return
	_done = true
	_set_status("已连上房主，进入游戏…")
	joined.emit()


## 房主：生成一个新的邀请（旧的没连上的作废）。
func _new_invite() -> void:
	var host_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer as WebRTCMultiplayerPeer
	if host_peer == null:
		_set_status("当前不是 P2P 房间")
		return
	if _link != null:
		_link.cancel(host_peer)
	_link = P2PLink.invite(host_peer)
	_out.text = ""
	_in.text = ""
	_copy_btn.disabled = true
	_confirm_btn.disabled = false
	_wait = -1.0


func _copy() -> void:
	DisplayServer.clipboard_set(_out.text)
	_set_status("已复制到剪贴板" + ("，发给好友后等他发回回应码" if is_host else "，发给房主后等待连接…"))


func _close() -> void:
	if is_host:
		if _link != null:
			_link.cancel(multiplayer.multiplayer_peer as WebRTCMultiplayerPeer)
		get_tree().paused = _was_paused
	elif not _done:
		_drop_client_peer()
	closed.emit()
	queue_free()


## 好友：放弃之前没连上的客户端连接。
func _drop_client_peer() -> void:
	if multiplayer.multiplayer_peer is WebRTCMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_link = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _hint(parent: Node, text: String) -> void:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	parent.add_child(l)


func _code_box(parent: Node, editable: bool) -> TextEdit:
	var t: TextEdit = TextEdit.new()
	t.custom_minimum_size = Vector2(0, 96)
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.editable = editable
	t.placeholder_text = "在这里粘贴（Ctrl+V），或者直接点下面的按钮从剪贴板读取" if editable else "生成中…"
	t.add_theme_font_size_override("font_size", 12)
	parent.add_child(t)
	return t


func _row_button(parent: Node, text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _set_status(text: String) -> void:
	_status.text = text
