class_name P2PFileSignal extends Node
## 测试用 P2P 信令：连接码通过 NetConfig.p2p_dir 目录里的文件交换，代替人工复制粘贴。
## 房主依次写 offer_N.txt 并等待 answer_N.txt；好友取编号最大、还没人回应的 offer 写回 answer。
## 只在命令行带 --p2p-dir 时由 NetSession 创建。

const RETRY_AFTER: float = 20.0  # 房主：一个邀请这么久没连上就换下一个

var _link: P2PLink = null
var _index: int = 0
var _age: float = 0.0
var _written: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(NetConfig.p2p_dir)
	if NetConfig.is_host():
		_index = _max_index("offer_")  # 重新开始（场景重载）后接着编号，不覆盖旧文件
		_next_invite()


func _process(delta: float) -> void:
	if NetConfig.is_host():
		_host_step(delta)
	else:
		_client_step(delta)


func _host_step(delta: float) -> void:
	var host_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer as WebRTCMultiplayerPeer
	if host_peer == null or _link == null:
		return
	_link.update(delta)
	_age += delta
	if not _written and not _link.code.is_empty():
		_write("offer_%d.txt" % _index, _link.code)
		_written = true
	if _written and not _link.answered:
		var answer: String = _read("answer_%d.txt" % _index)
		if not answer.is_empty():
			var err: String = _link.accept_answer(answer)
			if not err.is_empty():
				push_error("[p2p] %s" % err)
	if _link.is_connected_peer():
		print("[p2p] invite %d connected (peer %d)" % [_index, _link.peer_id])
		_next_invite()
	elif _link.has_failed() or _age > RETRY_AFTER:
		_link.cancel(host_peer)
		_next_invite()


func _next_invite() -> void:
	var host_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer as WebRTCMultiplayerPeer
	if host_peer == null:
		return
	_index += 1
	_age = 0.0
	_written = false
	_link = P2PLink.invite(host_peer)


func _client_step(delta: float) -> void:
	if _link == null:
		var n: int = _max_index("offer_")
		if n <= 0 or FileAccess.file_exists(_path("answer_%d.txt" % n)):
			return
		_link = P2PLink.join(_read("offer_%d.txt" % n))
		if not _link.error.is_empty():
			push_error("[p2p] %s" % _link.error)
			_link = null
			return
		_index = n
		multiplayer.multiplayer_peer = _link.client_peer
		print("[p2p] joining via offer %d as peer %d" % [n, _link.peer_id])
		return
	_link.update(delta)
	if not _written and not _link.code.is_empty():
		_write("answer_%d.txt" % _index, _link.code)
		_written = true
		set_process(false)


func _max_index(prefix: String) -> int:
	var best: int = 0
	for f: String in DirAccess.get_files_at(NetConfig.p2p_dir):
		if f.begins_with(prefix) and f.ends_with(".txt"):
			best = maxi(best, int(f.trim_prefix(prefix).trim_suffix(".txt")))
	return best


func _path(file_name: String) -> String:
	return NetConfig.p2p_dir.path_join(file_name)


func _read(file_name: String) -> String:
	return FileAccess.get_file_as_string(_path(file_name)) if FileAccess.file_exists(_path(file_name)) else ""


## 先写临时文件再改名，避免对方读到写了一半的内容。
func _write(file_name: String, text: String) -> void:
	var tmp: String = _path(file_name + ".tmp")
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	DirAccess.rename_absolute(tmp, _path(file_name))
