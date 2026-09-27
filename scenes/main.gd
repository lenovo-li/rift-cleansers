extends Node3D
## 主场景入口。M0 阶段只负责显示启动信息，后续由 GameBootstrap 接管。

@onready var _info_label: Label = $UI/InfoLabel


func _ready() -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version"))
	_info_label.text = "裂界清扫者 v%s | Godot %s" % [version, Engine.get_version_info()["string"]]
	print("[main] boot ok, version=%s" % version)
