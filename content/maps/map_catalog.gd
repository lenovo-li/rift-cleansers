class_name MapCatalog extends RefCounted
## 可选地图：布局（MapLayouts）、零件 glb、碰撞盒、环境/地面主题、光源、粒子、环境危险和 Boss。
## 地面主题是 ash_ground.gdshader 的参数（石板色、灰烬色、裂缝发光色）。

const DEFAULT_ID: String = "ashen_city"

const MAPS: Dictionary = {
	"ashen_city": {
		"name": "灰烬王城",
		"desc": "焦土废墟，火盆与残墙。危险：余烬坠落（红圈预警后爆炸）。",
		"boss": "corrupted_knight",
		"enemies": {
			"early": {"zombie": 0.75, "skeleton": 0.15, "ember_guard": 0.1},
			"mid": {"zombie": 0.3, "skeleton": 0.25, "ember_guard": 0.2, "imp": 0.15, "necromancer": 0.1},
			"late": {"skeleton": 0.25, "ember_guard": 0.2, "necromancer": 0.15, "imp": 0.15, "zombie": 0.15, "ghoul": 0.1},
		},
		"events": [
			{"kind": 0, "time": 120.0, "offset": Vector3(8, 0, 8), "params": {"exp": 50, "heal": 30}},
			{"kind": 1, "time": 240.0, "offset": Vector3.ZERO, "params": {"count": 3}},
			{"kind": 2, "time": 360.0, "offset": Vector3(-8, 0, -8), "params": {"upgrade_reroll": true}},
		],
		"seed": 20260927, "layout": "ashen", "kit": "ashen_city",
		"colliders": {
			"wall": Vector3(6.0, 2.6, 0.8), "wall_broken": Vector3(3.2, 1.6, 0.8), "pillar": Vector3(1.1, 3.7, 1.1),
			"pillar_broken": Vector3(1.1, 1.5, 1.1), "tower": Vector3(4.2, 4.4, 4.2), "brazier": Vector3(0.9, 1.1, 0.9),
			"statue": Vector3(2.6, 4.2, 2.6), "rubble": Vector3(1.8, 0.8, 1.6),
		},
		"env": {"background": Color(0.09, 0.06, 0.06), "ambient": Color(0.62, 0.52, 0.48), "ambient_energy": 0.55,
			"fog": Color(0.3, 0.2, 0.17), "fog_density": 0.004, "sun": Color(1, 0.86, 0.72), "sun_energy": 1.1},
		"ground": {"stone_color": Color(0.36, 0.34, 0.31), "ash_color": Color(0.18, 0.16, 0.15),
			"ember_color": Color(0.55, 0.22, 0.08), "grout_strength": 1.0},
		"decor": {"kit": "decor", "counts": {"pebbles": 700, "grass": 900, "bones": 160, "crack": 260}, "big": {"crack": 3.0}},
		"lights": {"piece": "brazier", "color": Color(1.0, 0.55, 0.25), "energy": 2.2, "height": 1.6},
		"particles": {"color": Color(1.0, 0.6, 0.2, 0.7), "gravity": Vector3(0, 0.15, 0)},
		"hazard": {"kind": "blast", "name": "坠落的余烬", "first": 120.0, "interval": 16.0, "radius": 2.2,
			"damage": 30.0, "fuse": 1.2, "color": Color(1.0, 0.35, 0.1, 0.45)},
	},
	"frost_wastes": {
		"name": "霜冻冰原",
		"desc": "冰刺与雪松林，冰晶发出冷光。危险：寒霜地带（减速并持续冻伤）。",
		"boss": "frost_lich",
		"enemies": {
			"early": {"zombie": 0.5, "skeleton": 0.25, "frost_wraith": 0.15, "bloater": 0.1},
			"mid": {"skeleton": 0.3, "frost_wraith": 0.25, "zombie": 0.2, "bloater": 0.15, "necromancer": 0.1},
			"late": {"frost_wraith": 0.25, "skeleton": 0.2, "bloater": 0.2, "necromancer": 0.15, "imp": 0.1, "zombie": 0.1},
		},
		"events": [
			{"kind": 2, "time": 150.0, "offset": Vector3(10, 0, 10), "params": {"upgrade_reroll": true}},
			{"kind": 0, "time": 270.0, "offset": Vector3(-10, 0, 10), "params": {"exp": 60, "heal": 40}},
			{"kind": 1, "time": 400.0, "offset": Vector3.ZERO, "params": {"count": 4}},
		],
		"seed": 20261001, "layout": "frost", "kit": "frost_wastes",
		"colliders": {
			"ice_spire": Vector3(1.6, 3.6, 1.6), "pine": Vector3(1.4, 4.5, 1.4), "ice_rock": Vector3(2.0, 1.3, 1.8),
			"frozen_wall": Vector3(6.0, 2.4, 0.9), "crystal": Vector3(0.8, 1.6, 0.8), "totem": Vector3(2.0, 4.4, 2.0),
		},
		"env": {"background": Color(0.12, 0.15, 0.2), "ambient": Color(0.62, 0.72, 0.85), "ambient_energy": 0.5,
			"fog": Color(0.6, 0.7, 0.8), "fog_density": 0.006, "sun": Color(0.85, 0.92, 1.0), "sun_energy": 0.95},
		"ground": {"stone_color": Color(0.62, 0.68, 0.76), "ash_color": Color(0.45, 0.54, 0.64),
			"ember_color": Color(0.2, 0.55, 0.8), "grout_strength": 0.12},
		"decor": {"kit": "frost_wastes", "counts": {"d_snow": 700, "d_shard": 400, "d_pebble": 300}, "big": {"d_snow": 2.5}},
		"lights": {"piece": "crystal", "color": Color(0.5, 0.85, 1.0), "energy": 2.0, "height": 1.4},
		"particles": {"color": Color(0.95, 0.97, 1.0, 0.8), "gravity": Vector3(0.1, -0.4, 0.05), "direction": Vector3(0, -1, 0),
			"height": 10.0, "amount": 220},
		"hazard": {"kind": "zone", "name": "寒霜地带", "first": 90.0, "interval": 14.0, "radius": 3.2,
			"damage": 8.0, "slow": 0.45, "duration": 6.0, "color": Color(0.55, 0.85, 1.0, 0.35)},
	},
	"sand_ruins": {
		"name": "沙海遗迹",
		"desc": "烈日下的砂岩柱廊与台地。危险：流沙塌陷（预警后爆发，伤害高）。",
		"boss": "sand_colossus",
		"enemies": {
			"early": {"skeleton": 0.45, "sand_scarab": 0.3, "imp": 0.15, "zombie": 0.1},
			"mid": {"skeleton": 0.3, "sand_scarab": 0.25, "imp": 0.2, "necromancer": 0.15, "ghoul": 0.1},
			"late": {"sand_scarab": 0.25, "necromancer": 0.2, "skeleton": 0.2, "ghoul": 0.18, "imp": 0.12, "bloater": 0.05},
		},
		"events": [
			{"kind": 1, "time": 180.0, "offset": Vector3.ZERO, "params": {"count": 5}},
			{"kind": 0, "time": 300.0, "offset": Vector3(12, 0, 0), "params": {"exp": 70, "heal": 35}},
			{"kind": 2, "time": 450.0, "offset": Vector3(0, 0, -12), "params": {"upgrade_reroll": true}},
		],
		"seed": 20261002, "layout": "desert", "kit": "sand_ruins",
		"colliders": {
			"sand_wall": Vector3(6.0, 2.8, 0.8), "obelisk": Vector3(2.2, 6.6, 2.2), "sand_pillar": Vector3(1.0, 3.6, 1.0),
			"cactus": Vector3(0.8, 2.2, 0.8), "mesa_rock": Vector3(3.0, 2.0, 2.6), "urn": Vector3(0.8, 1.0, 0.8),
		},
		"env": {"background": Color(0.25, 0.18, 0.12), "ambient": Color(0.85, 0.72, 0.55), "ambient_energy": 0.65,
			"fog": Color(0.75, 0.6, 0.42), "fog_density": 0.005, "sun": Color(1.0, 0.9, 0.7), "sun_energy": 1.5},
		"ground": {"stone_color": Color(0.78, 0.64, 0.42), "ash_color": Color(0.66, 0.52, 0.33),
			"ember_color": Color(0.7, 0.35, 0.1), "grout_strength": 0.2},
		"decor": {"kit": "sand_ruins", "counts": {"d_ripple": 600, "d_bush": 350, "d_skull": 80}, "big": {"d_ripple": 1.4}},
		"lights": {"piece": "urn", "color": Color(1.0, 0.65, 0.3), "energy": 1.8, "height": 1.3},
		"particles": {"color": Color(0.9, 0.75, 0.5, 0.5), "gravity": Vector3(0.6, 0.02, 0.2), "direction": Vector3(1, 0, 0.3)},
		"hazard": {"kind": "blast", "name": "流沙塌陷", "first": 100.0, "interval": 13.0, "radius": 3.0,
			"damage": 40.0, "fuse": 1.4, "color": Color(0.95, 0.7, 0.3, 0.45)},
	},
	"dark_forest": {
		"name": "幽暗森林",
		"desc": "古树遮天，发光巨菇指路，林间通道狭窄。危险：毒孢子云（减速并持续中毒）。",
		"boss": "rotwood_treant",
		"enemies": {
			"early": {"zombie": 0.45, "spore_shambler": 0.25, "bloater": 0.2, "imp": 0.1},
			"mid": {"spore_shambler": 0.3, "bloater": 0.25, "ghoul": 0.2, "zombie": 0.15, "skeleton": 0.1},
			"late": {"spore_shambler": 0.25, "ghoul": 0.25, "bloater": 0.2, "necromancer": 0.15, "imp": 0.1, "skeleton": 0.05},
		},
		"events": [
			{"kind": 0, "time": 100.0, "offset": Vector3(-10, 0, 10), "params": {"exp": 55, "heal": 35}},
			{"kind": 1, "time": 220.0, "offset": Vector3.ZERO, "params": {"count": 4}},
			{"kind": 2, "time": 380.0, "offset": Vector3(10, 0, -10), "params": {"upgrade_reroll": true}},
		],
		"seed": 20261003, "layout": "forest", "kit": "dark_forest",
		"colliders": {
			"oak": Vector3(1.2, 4.5, 1.2), "dark_pine": Vector3(1.0, 5.0, 1.0), "log": Vector3(4.0, 0.9, 0.9),
			"mossy_rock": Vector3(1.9, 1.4, 1.8), "glowshroom": Vector3(0.6, 2.2, 0.6), "standing_stone": Vector3(1.2, 3.2, 0.8),
		},
		"env": {"background": Color(0.04, 0.07, 0.05), "ambient": Color(0.42, 0.55, 0.45), "ambient_energy": 0.5,
			"fog": Color(0.12, 0.2, 0.15), "fog_density": 0.009, "sun": Color(0.75, 0.9, 0.7), "sun_energy": 0.8},
		"ground": {"stone_color": Color(0.24, 0.3, 0.18), "ash_color": Color(0.16, 0.2, 0.12),
			"ember_color": Color(0.3, 0.8, 0.5), "grout_strength": 0.08},
		"decor": {"kit": "dark_forest", "counts": {"d_fern": 900, "d_mushroom": 300, "d_leaves": 700}},
		"lights": {"piece": "glowshroom", "color": Color(0.5, 1.0, 0.7), "energy": 2.0, "height": 2.0},
		"particles": {"color": Color(0.7, 1.0, 0.5, 0.8), "gravity": Vector3(0, 0.05, 0), "amount": 90},
		"hazard": {"kind": "zone", "name": "毒孢子云", "first": 90.0, "interval": 15.0, "radius": 3.0,
			"damage": 12.0, "slow": 0.3, "duration": 5.0, "color": Color(0.5, 0.8, 0.2, 0.35)},
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
