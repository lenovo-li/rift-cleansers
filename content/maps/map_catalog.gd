class_name MapCatalog extends RefCounted
## 可选地图。每张地图决定场景布局脚本、地面/光照主题和 Boss。

const DEFAULT_ID: String = "ashen_city"

const MAPS: Dictionary = {
	"ashen_city": {
		"name": "灰烬王城",
		"desc": "焦土废墟，火盆与残墙。",
		"boss": "corrupted_knight",
	},
}


static func get_def(id: String) -> Dictionary:
	return MAPS.get(id, MAPS[DEFAULT_ID])


static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in MAPS:
		out.append(id)
	return out


static func is_valid(id: String) -> bool:
	return MAPS.has(id)
