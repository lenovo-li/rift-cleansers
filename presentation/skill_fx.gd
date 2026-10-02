class_name SkillFx extends RefCounted
## 24 个技能 + 4 种普攻的表现编排：按技能结果和段位（tier 1/3/5/8）组合 SkillVfx 的特效原语。
## 四档视觉进化的统一思路（文档 05 §5「四档视觉成长」，盾击是原型）：
##   1 段 基础形态，小而清楚；3 段 更亮 + 多一层元素（法阵、火花、第二道光）；
##   5 段 形态质变（数量翻倍、新部件、形状变化）；8 段 环境级（大冲击波、地面痕迹、颜色升级为金白/橙红）。
## 这里只放纯表现；位移、无敌、护盾、音效、震屏和顿帧仍在 PlayerM1 里。所有调用都经 SkillVfx 录制，联机客户端同样回放。

const BLUE: Color = Color(0.5, 0.8, 1.0)
const FIRE: Color = Color(1.0, 0.5, 0.15)
const EMBER: Color = Color(1.0, 0.35, 0.1)
const GOLD: Color = Color(1.0, 0.85, 0.4)
const HOLY: Color = Color(1.0, 0.92, 0.55)
const FROST: Color = Color(0.55, 0.88, 1.0)
const STORM: Color = Color(0.6, 0.68, 1.0)
const SHADOW: Color = Color(0.62, 0.32, 1.0)
const BLOOD: Color = Color(1.0, 0.15, 0.28)


## 技能 -> 身体动作（PlayerRig.ACTIONS）。持续型技能（旋风斩）按技能时长播放。
const POSES: Dictionary = {
	"shield_bash": "bash", "whirlwind": "spin", "taunt": "roar", "charge": "bash", "ground_slam": "slam",
	"reflect_aura": "raise", "earthquake": "slam", "iron_wall": "raise", "war_cry": "roar", "flame_cleave": "swing",
	"fireball": "cast", "ice_lance": "cast", "frost_nova": "raise", "chain_lightning": "cast", "meteor": "raise",
	"storm_field": "raise", "thunderstorm": "raise", "frost_barrier": "raise", "arcane_barrage": "cast", "lava_blast": "cast",
	"shadow_step": "swing", "fan_of_knives": "swing_l", "death_mark": "cast", "blade_flurry": "spin",
	"smoke_bomb": "slam", "execute": "swing", "eviscerate": "swing", "shadow_clone": "raise", "backstab": "swing", "poison_blade": "cast",
	"holy_nova": "raise", "smite": "cast", "sanctuary": "slam", "divine_shield": "raise", "blessing": "raise",
	"divine_intervention": "raise", "guardian_angel": "raise", "purify": "raise", "resurrection": "raise", "holy_wrath": "cast",
}


static func play(p: Node, caster: Node3D, id: String, r: Dictionary, origin: Vector3, facing: Vector3, tier: int) -> void:
	var action: String = POSES.get(id, "cast")
	var dur: float = float(r.get("duration", -1.0)) if action == "spin" else -1.0
	SkillVfx.pose(p, int(caster.get("net_slot")), action, dur)
	match id:
		"shield_bash", "whirlwind", "taunt", "charge", "ground_slam", "reflect_aura", \
		"earthquake", "iron_wall", "war_cry", "flame_cleave":
			_iron_guard(p, caster, id, r, origin, facing, tier)
		"fireball", "ice_lance", "frost_nova", "chain_lightning", "meteor", "storm_field", \
		"thunderstorm", "frost_barrier", "arcane_barrage", "lava_blast":
			_elementalist(p, caster, id, r, origin, tier)
		"shadow_step", "fan_of_knives", "death_mark", "blade_flurry", "smoke_bomb", "execute", \
		"eviscerate", "shadow_clone", "backstab", "poison_blade":
			_shadow_walker(p, caster, id, r, origin, tier)
		_:
			_cleric(p, caster, id, r, origin, tier)


static func _up(v: Vector3, h: float) -> Vector3:
	return v + Vector3(0, h, 0)


# ---------------- 铁卫 ----------------
static func _iron_guard(p: Node, caster: Node3D, id: String, r: Dictionary, origin: Vector3, facing: Vector3, tier: int) -> void:
	var slot: int = int(caster.get("net_slot"))
	match id:
		"shield_bash":
			var radius: float = ShieldBash.BASE_RANGE * (1.5 if tier >= 5 else 1.0)
			SkillVfx.shield_bash_tiered(p, origin, facing, radius, tier, r.get("hit_points", []), r.get("chain_links", []))
			var front: Vector3 = origin + facing * radius * 0.55
			SkillVfx.rune(p, front, radius * 0.6, Color(EMBER if tier >= 8 else BLUE, 0.7), "expand", 0.35, "pulse_sigil")
			if tier >= 8:
				SkillVfx.spike_ring(p, front, radius * 0.8, "rock", 6)
				SkillVfx.crack_decal(p, front, radius * 0.7, FIRE, 2.0)
		"whirlwind":
			SkillVfx.whirlwind(p, caster, float(r.radius), float(r.duration),
					Color(1.0, 0.6, 0.3, 0.5) if tier >= 8 else Color(0.55, 1.0, 0.7, 0.5), "whirl", tier)
			SkillVfx.rune(p, origin, float(r.radius), Color(0.55, 1.0, 0.7, 0.6), "expand", 0.4, "glow_ring")
		"taunt":
			var radius: float = float(r.radius)
			# 拉拢：法阵从外向内收缩，和敌人被拉过来的方向一致
			SkillVfx.rune(p, origin, radius, Color(1.0, 0.3, 0.2, 0.9), "implode", 0.5, "rune_circle")
			SkillVfx.shockwave(p, origin, radius, Color(1.0, 0.25, 0.2, 1.0), 0.5)
			SkillVfx.burst(p, "magic", _up(origin, 1.5), 1.0, Color(1.0, 0.35, 0.25))
			if tier >= 3:
				SkillVfx.pulse_ring(p, origin, radius * 0.9, Color(0.6, 0.8, 1.0, 0.5), 0.5)  # 减速
			if tier >= 5 and float(r.get("shield", 0.0)) > 0.0:
				SkillVfx.shield_pulse(p, origin, 2.2, BLUE, 4)
			if tier >= 8:
				SkillVfx.shockwave(p, origin, 3.0, Color(1.0, 0.6, 0.3, 1.0), 0.35)
				SkillVfx.spike_ring(p, origin, 2.6, "rock", 8)
		"charge":
			var end: Vector3 = r.end_position
			var color: Color = Color(1.0, 0.5, 0.1, 0.45) if tier >= 8 else Color(0.5, 0.8, 1.0, 0.4)
			SkillVfx.dash_trail(p, origin, end, Charge.HALF_WIDTH * 1.2, Color(color, 0.25 + 0.05 * (tier / 3)))
			SkillVfx.afterimage(p, slot, origin, end, color, 4 + tier / 2)
			SkillVfx.burst(p, "dust", end, 0.8)
			if tier >= 3:
				SkillVfx.rune(p, origin, 1.8, Color(color, 0.8), "expand", 0.3, "pulse_sigil")
			if tier >= 5:
				SkillVfx.shockwave(p, end, Charge.IMPACT_RADIUS, Color(1.0, 0.8, 0.3, 1.0), 0.35)
				SkillVfx.crack_decal(p, end, Charge.IMPACT_RADIUS * 0.7, Color(1.0, 0.7, 0.35), 1.5)
			if tier >= 8:
				for i in 4:
					SkillVfx.burst(p, "fire", _up(origin.lerp(end, (i + 0.5) / 4.0), 0.4), 0.7, FIRE)
		"ground_slam":
			var radius: float = float(r.radius)
			SkillVfx.shockwave(p, origin, radius, Color(1.0, 0.75, 0.4, 1.0), 0.45)
			SkillVfx.burst(p, "dust", origin, 1.0 + 0.1 * tier)
			SkillVfx.burst(p, "debris", _up(origin, 0.3), 1.0 + 0.1 * tier)
			SkillVfx.crack_decal(p, origin, radius * 0.8, Color(1.0, 0.7, 0.35), 1.8 + 0.2 * tier)
			if tier >= 3:
				SkillVfx.spike_ring(p, origin, radius * 0.9, "rock", 6 + tier)
			if tier >= 5:
				SkillVfx.rune(p, origin, radius, Color(1.0, 0.7, 0.35, 0.7), "expand", 0.6, "rune_circle")
			if tier >= 8:
				SkillVfx.shockwave(p, origin, radius * 1.4, Color(1.0, 0.5, 0.2, 1.0), 0.6)
				SkillVfx.spike_ring(p, origin, radius * 1.35, "rock", 14)
		"reflect_aura":
			SkillVfx.whirlwind(p, caster, ReflectAura.AURA_RADIUS, float(r.aura_duration),
					Color(1.0, 0.6, 0.3, 0.5) if tier >= 8 else Color(1.0, 0.8, 0.3, 0.5), "reflect", tier)
			SkillVfx.shield_pulse(p, origin, ReflectAura.AURA_RADIUS, GOLD, 6)
		"earthquake":
			var radius: float = float(r.radius)
			SkillVfx.shockwave(p, origin, radius, Color(0.8, 0.6, 0.3, 1.0), 0.5)
			SkillVfx.burst(p, "dust", origin, 1.5)
			SkillVfx.crack_decal(p, origin, radius * 0.9, Color(0.7, 0.5, 0.3), float(r.duration))
			if tier >= 3:
				SkillVfx.spike_ring(p, origin, radius * 0.95, "rock", 12)
			if tier >= 5:
				SkillVfx.shockwave(p, origin, radius * 1.2, Color(0.9, 0.7, 0.4, 0.8), 0.6)
			if tier >= 8:
				SkillVfx.rune(p, origin, radius, Color(1.0, 0.5, 0.2, 0.7), "expand", 0.7, "rune_circle")
				SkillVfx.spike_ring(p, origin, radius * 1.1, "rock", 18)
		"iron_wall":
			SkillVfx.shield_pulse(p, origin, 3.5, Color(0.7, 0.7, 0.8, 1.0), 8)
			SkillVfx.rune(p, origin, 2.5, Color(0.6, 0.7, 0.9, 0.8), "expand", 0.4, "rune_circle")
			if tier >= 3:
				SkillVfx.burst(p, "magic", _up(origin, 1.5), 1.2, Color(0.7, 0.8, 1.0))
			if tier >= 5:
				SkillVfx.shockwave(p, origin, 3.0, Color(0.8, 0.85, 1.0, 0.6), 0.4)
			if tier >= 8:
				SkillVfx.pulse_ring(p, origin, 3.8, Color(1.0, 0.8, 0.4, 0.7), 0.5)
		"war_cry":
			var radius: float = float(r.radius)
			SkillVfx.burst(p, "magic", _up(origin, 1.8), 1.5, Color(1.0, 0.7, 0.3))
			SkillVfx.shockwave(p, origin, radius, Color(1.0, 0.6, 0.2, 0.9), 0.45)
			SkillVfx.rune(p, origin, radius * 0.9, Color(1.0, 0.7, 0.3, 0.7), "expand", 0.5, "pulse_sigil")
			if tier >= 3:
				SkillVfx.pulse_ring(p, origin, radius * 1.1, Color(1.0, 0.5, 0.2, 0.6), 0.5)
			if tier >= 5:
				# buffed 是受增益人数；位置取场上存活玩家（与技能半径一致）
				for a: Node in caster.get_tree().get_nodes_in_group("players"):
					if a is Node3D and (a as Node3D).global_position.distance_to(origin) <= radius:
						SkillVfx.burst(p, "star", _up((a as Node3D).global_position, 1.5), 0.8, GOLD)
			if tier >= 8:
				SkillVfx.shockwave(p, origin, radius * 1.3, Color(1.0, 0.8, 0.4, 1.0), 0.6)
		"flame_cleave":
			var cone_range: float = 6.0 * (1.3 if tier >= 3 else 1.0)
			var front: Vector3 = origin + facing * cone_range * 0.6
			SkillVfx.burst(p, "fire", _up(front, 0.5), 1.0 + 0.15 * tier, FIRE)
			SkillVfx.crack_decal(p, front, cone_range * 0.7, FIRE, 3.0 + tier)
			if tier >= 3:
				SkillVfx.shockwave(p, front, cone_range * 0.8, Color(1.0, 0.5, 0.2, 0.8), 0.4)
			if tier >= 5:
				SkillVfx.rune(p, front, cone_range * 0.75, Color(EMBER, 0.7), "expand", 0.5, "rune_circle")
			if tier >= 8:
				SkillVfx.spike_ring(p, front, cone_range * 0.85, "rock", 8)
				SkillVfx.burst(p, "fire", _up(front, 0.8), 1.8, EMBER)


# ---------------- 元素术士 ----------------
static func _elementalist(p: Node, caster: Node3D, id: String, r: Dictionary, origin: Vector3, tier: int) -> void:
	var hand: Vector3 = _up(caster.global_position, 1.3)
	match id:
		"fireball":
			if tier >= 3:
				SkillVfx.rune(p, origin, 1.6, Color(FIRE, 0.8), "expand", 0.35, "rune_circle")
			for impact: Vector3 in r.get("impacts", []):
				SkillVfx.missile(p, "fire", hand, _up(impact, 0.6), FIRE, float(r.radius), tier)
		"ice_lance":
			var ends: Array = r.get("ends", [])
			if tier >= 3:
				SkillVfx.rune(p, origin, 1.5, Color(FROST, 0.8), "expand", 0.3, "rune_circle")
			for e: Vector3 in ends:
				SkillVfx.missile(p, "ice", _up(caster.global_position, 1.0), _up(e, 1.0), FROST, 1.0, tier)
				if tier >= 8:
					# 8 段：冰枪沿途留下一道冰刺
					var from: Vector3 = caster.global_position * Vector3(1, 0, 1)
					for k in 3:
						SkillVfx.spike_ring(p, from.lerp(e * Vector3(1, 0, 1), (k + 1) / 4.0), 1.0, "ice", 3)
		"frost_nova":
			var radius: float = float(r.radius)
			SkillVfx.shockwave(p, origin, radius, Color(0.5, 0.85, 1.0, 1.0), 0.45)
			SkillVfx.burst(p, "shard", _up(origin, 0.8), 1.2 + 0.1 * tier)
			SkillVfx.spike_ring(p, origin, radius, "ice", clampi(int(radius * 2.2), 8, 16) + (4 if tier >= 5 else 0))
			if tier >= 3:
				SkillVfx.rune(p, origin, radius, Color(FROST, 0.8), "expand", 0.5, "rune_circle")
			if tier >= 5:
				SkillVfx.shockwave(p, origin, radius * 1.25, Color(0.8, 0.95, 1.0, 0.8), 0.55)  # 推开
			if tier >= 8:
				SkillVfx.spike_ring(p, origin, radius * 0.5, "ice", 8)
				SkillVfx.rune(p, origin, radius * 1.3, Color(0.85, 0.95, 1.0, 0.7), "flash", 1.2, "glow_ring")
		"chain_lightning":
			var links: Array = r.get("links", [])
			for link: Array in links:
				SkillVfx.arc(p, link[0], link[1], Color(0.85, 0.85, 1.0, 1.0) if tier >= 8 else Color(0.7, 0.75, 1.0, 1.0))
				if tier >= 5:
					# 5 段不再衰减：每一跳都是双股电弧
					SkillVfx.arc(p, link[0], link[1], Color(STORM, 0.7))
			if tier >= 3 and not links.is_empty():
				SkillVfx.rune(p, caster.global_position, 1.5, Color(STORM, 0.8), "expand", 0.3, "rune_circle")
			if tier >= 8:
				for link: Array in links:
					SkillVfx.shockwave(p, link[1], 1.6, Color(0.7, 0.75, 1.0, 1.0), 0.25)
		"meteor":
			SkillVfx.meteor_fall(p, r.center, float(r.radius), float(r.delay), tier)
			SkillVfx.rune(p, origin, 1.6, Color(EMBER, 0.8), "expand", 0.4, "rune_circle")
		"storm_field":
			SkillVfx.whirlwind(p, caster, float(r.radius), float(r.duration), Color(0.55, 0.65, 1.0, 0.6), "storm", tier)
			SkillVfx.burst(p, "magic", _up(caster.global_position, 1.5), 1.2, Color(0.65, 0.7, 1.0))
		"thunderstorm":
			var radius: float = 10.0
			SkillVfx.burst(p, "magic", _up(origin, 2.0), 1.5, STORM)
			SkillVfx.rune(p, origin, radius, Color(STORM, 0.7), "expand", 0.6, "rune_circle")
			SkillVfx.shockwave(p, origin, radius, Color(0.6, 0.7, 1.0, 0.8), 0.5)
			if tier >= 3:
				SkillVfx.pulse_ring(p, origin, radius * 0.9, Color(0.7, 0.75, 1.0, 0.6), 0.5)
			if tier >= 5:
				SkillVfx.spike_ring(p, origin, radius * 0.95, "ice", 10)
			if tier >= 8:
				SkillVfx.rune(p, origin, radius * 1.2, Color(0.85, 0.9, 1.0, 0.8), "flash", 1.0, "glow_ring")
		"frost_barrier":
			var radius: float = float(r.radius)
			SkillVfx.shield_pulse(p, origin, 3.0, FROST, 8)
			SkillVfx.burst(p, "shard", _up(origin, 1.2), 1.3, FROST)
			SkillVfx.shockwave(p, origin, radius, Color(0.5, 0.85, 1.0, 0.9), 0.4)
			if tier >= 3:
				SkillVfx.spike_ring(p, origin, radius * 0.9, "ice", 8)
			if tier >= 5:
				SkillVfx.rune(p, origin, radius, Color(FROST, 0.7), "expand", 0.5, "rune_circle")
			if tier >= 8:
				SkillVfx.shockwave(p, origin, radius * 1.3, Color(0.7, 0.9, 1.0, 1.0), 0.6)
				SkillVfx.spike_ring(p, origin, radius * 1.25, "ice", 14)
		"arcane_barrage":
			var count: int = int(r.projectiles)
			var impacts: Array = r.get("impacts", [])
			var fwd: Vector3 = caster.get("facing") * Vector3(1, 0, 1)
			for i in count:
				var to: Vector3
				if i < impacts.size():
					to = _up(impacts[i], 1.0)
				else:
					# 没打到目标的飞弹沿前方扇形散开
					var ang: float = deg_to_rad(-30.0 + 60.0 * (i + 0.5) / count)
					to = _up(caster.global_position + fwd.normalized().rotated(Vector3.UP, ang) * 10.0, 1.0)
				SkillVfx.missile(p, "magic", hand, to, Color(0.7, 0.5, 1.0), 0.6, tier)
			if tier >= 3:
				SkillVfx.rune(p, origin, 1.8, Color(0.7, 0.5, 1.0, 0.7), "expand", 0.4, "pulse_sigil")
			if tier >= 8:
				SkillVfx.burst(p, "magic", hand, 1.5, Color(0.8, 0.6, 1.0))
		"lava_blast":
			var radius: float = 8.0 * (1.3 if tier >= 3 else 1.0)
			SkillVfx.burst(p, "fire", _up(origin, 1.0), 1.5 + 0.2 * tier, EMBER)
			SkillVfx.shockwave(p, origin, radius, Color(1.0, 0.4, 0.1, 1.0), 0.5)
			SkillVfx.crack_decal(p, origin, radius * 0.85, FIRE, 3.0 + tier)
			if tier >= 3:
				SkillVfx.spike_ring(p, origin, radius * 0.9, "rock", 10)
			if tier >= 5:
				SkillVfx.rune(p, origin, radius, Color(EMBER, 0.8), "expand", 0.6, "rune_circle")
			if tier >= 8:
				SkillVfx.shockwave(p, origin, radius * 1.3, Color(1.0, 0.6, 0.2, 1.0), 0.7)
				SkillVfx.burst(p, "smoke", _up(origin, 1.5), radius * 0.25, Color(0.3, 0.2, 0.15))


## 陨石落地（strike_landed）：按段位加码爆炸。
static func meteor_landed(p: Node, center: Vector3, radius: float, second_wave: bool, tier: int) -> void:
	SkillVfx.meteor_impact(p, center, radius, second_wave)
	if tier >= 3:
		SkillVfx.spike_ring(p, center, radius * 0.8, "rock", 8)
	if tier >= 5:
		SkillVfx.burst(p, "smoke", _up(center, 1.0), radius * 0.3, Color(0.25, 0.2, 0.18, 0.7))
	if tier >= 8:
		SkillVfx.rune(p, center, radius * 1.4, Color(1.0, 0.75, 0.35, 0.9), "expand", 0.7, "glow_ring")


# ---------------- 影行者 ----------------
static func _shadow_walker(p: Node, caster: Node3D, id: String, r: Dictionary, origin: Vector3, tier: int) -> void:
	var slot: int = int(caster.get("net_slot"))
	match id:
		"shadow_step":
			var path: Array = r.get("path", [])
			if path.size() < 2:
				return
			var color: Color = BLOOD if tier >= 8 else SHADOW
			SkillVfx.burst(p, "smoke", _up(path[0], 0.8), 0.8 + 0.1 * tier, Color(0.3, 0.2, 0.45, 0.7))
			for i in range(1, path.size()):
				var a: Vector3 = path[i - 1]
				var b: Vector3 = path[i]
				SkillVfx.dash_trail(p, _up(a, 0.8), _up(b, 0.8), 0.25, Color(color, 0.6))
				SkillVfx.afterimage(p, slot, a, b, color, 3 + tier / 3)
				SkillVfx.shield_bash(p, b - (b - a).normalized() * 0.5, b - a, float(r.radius) * 0.8, Color(color, 0.5))
				SkillVfx.pulse_ring(p, b, float(r.radius), Color(color, 0.35), 0.25)
				if tier >= 3:
					SkillVfx.rune(p, b, float(r.radius), Color(color, 0.8), "flash", 0.45, "rune_circle")
				if tier >= 5:
					SkillVfx.execute_slash(p, b, b - a, float(r.radius) * 0.6, color)
					SkillVfx.shockwave(p, b, float(r.radius), Color(color, 1.0), 0.3)
		"fan_of_knives":
			var from: Vector3 = _up(caster.global_position, 1.0)
			var tint: Color = Color(1.0, 0.5, 0.6) if tier >= 5 else Color(0.9, 0.9, 1.0)
			var points: Array = r.get("points", [])
			for i in mini(points.size(), 10):
				SkillVfx.missile(p, "knife", from, _up(points[i], 1.0), tint, 1.0, tier)
			# 其余刀沿扇形均匀散开飞到最远处；3 段起是 360° 环形
			var half: float = minf(float(r.half_angle), PI)
			var total: int = (16 if tier >= 8 else 12) if half >= PI else 7
			var spread: int = maxi(0, total - points.size())
			for i in spread:
				var ang: float = -half + 2.0 * half * (i + 0.5) / spread
				var d: Vector3 = (r.aim as Vector3).rotated(Vector3.UP, ang)
				SkillVfx.missile(p, "knife", from, from + d * float(r.radius), tint, 1.0, tier)
			if half >= PI:
				SkillVfx.pulse_ring(p, caster.global_position, float(r.radius), Color(0.8, 0.8, 0.95, 0.25), 0.25)
				SkillVfx.rune(p, caster.global_position, 2.0, Color(SHADOW, 0.8), "expand", 0.3, "rune_circle")
		"death_mark":
			var marked: Array = r.get("marked", [])
			for m: Vector3 in marked:
				SkillVfx.burst(p, "magic", _up(m, 2.2), 0.8, Color(0.8, 0.1, 0.3))
				SkillVfx.pulse_ring(p, m, 1.2, Color(0.85, 0.1, 0.3, 0.6), 0.5)
				SkillVfx.buff(p, "mark", m, DeathMark.DURATION, BLOOD, tier)
				if tier >= 8:
					SkillVfx.pillar(p, m, 0.35, 6.0, Color(BLOOD, 0.8))
			if tier >= 3 and not marked.is_empty():
				SkillVfx.rune(p, caster.global_position, 1.8, Color(BLOOD, 0.8), "flash", 0.5, "rune_circle")
		"blade_flurry":
			SkillVfx.whirlwind(p, caster, float(r.radius), float(r.duration),
					Color(1.0, 0.4, 0.5, 0.5) if tier >= 8 else Color(0.8, 0.75, 1.0, 0.5), "blades", tier)
		"smoke_bomb":
			var at: Vector3 = caster.global_position
			var radius: float = float(r.radius)
			SkillVfx.burst(p, "dust", at, 1.6, Color(0.3, 0.28, 0.35))
			SkillVfx.burst(p, "smoke", _up(at, 1.0), 1.8 + 0.1 * tier, Color(0.35, 0.3, 0.45, 0.8))
			if tier >= 3:
				SkillVfx.rune(p, at, radius, Color(SHADOW, 0.7), "flash", 1.0, "rune_circle")
			if tier >= 5:
				SkillVfx.rune(p, at, radius * 1.05, Color(BLOOD, 0.6), "flash", float(r.duration), "glow_ring")  # 标记范围
			if tier >= 8:
				SkillVfx.shockwave(p, at, radius, Color(0.55, 0.3, 0.9, 1.0), 0.5)
				SkillVfx.burst(p, "fire", _up(at, 0.6), 1.2, Color(0.8, 0.3, 1.0))
		"execute":
			if not r.has("center"):
				return
			var c: Vector3 = r.center
			var executed: bool = bool(r.executed)
			var color: Color = BLOOD if executed else Color(0.8, 0.3, 0.5)
			SkillVfx.execute_slash(p, c, c - caster.global_position, (2.2 if executed else 1.6) * (1.25 if tier >= 8 else 1.0), color)
			SkillVfx.shockwave(p, c, 2.0 if not executed else 3.0, Color(0.9, 0.15, 0.25, 1.0), 0.3)
			SkillVfx.burst(p, "spark", _up(c, 1.0), 1.2 if executed else 0.7)
			if tier >= 3:
				SkillVfx.rune(p, c, 1.6, Color(color, 0.8), "flash", 0.5, "rune_circle")
			if tier >= 5:
				SkillVfx.shockwave(p, c, 2.5, Color(1.0, 0.4, 0.5, 0.8), 0.35)  # 顺劈范围
			if tier >= 8 and executed:
				SkillVfx.pillar(p, c, 0.5, 8.0, Color(BLOOD, 0.9))
				SkillVfx.spike_ring(p, c, 2.2, "rock", 7)
		"eviscerate":
			if not r.has("center"):
				return
			var c: Vector3 = r.center
			var executed: bool = bool(r.get("executed", false))
			var color: Color = BLOOD if executed else Color(1.0, 0.4, 0.5)
			SkillVfx.execute_slash(p, c, c - caster.global_position, 2.0 * (1.3 if tier >= 5 else 1.0), color)
			SkillVfx.burst(p, "spark", _up(c, 1.2), 1.0 + 0.15 * tier)
			SkillVfx.shockwave(p, c, 2.5 if executed else 1.8, Color(1.0, 0.2, 0.3, 1.0), 0.35)
			if tier >= 3:
				SkillVfx.rune(p, c, 2.0, Color(color, 0.8), "flash", 0.5, "rune_circle")
			if tier >= 5:
				SkillVfx.burst(p, "fire", _up(c, 0.8), 1.2, BLOOD)
			if tier >= 8:
				SkillVfx.shockwave(p, c, 3.0, Color(1.0, 0.3, 0.4, 0.9), 0.45)  # 溅射范围
				SkillVfx.pillar(p, c, 0.4, 7.0, Color(BLOOD, 0.85))
		"shadow_clone":
			var radius: float = float(r.radius)
			SkillVfx.burst(p, "smoke", _up(origin, 1.0), 1.5, Color(0.4, 0.3, 0.6, 0.8))
			SkillVfx.rune(p, origin, radius, Color(SHADOW, 0.7), "expand", 0.5, "rune_circle")
			SkillVfx.pulse_ring(p, origin, radius * 0.9, Color(SHADOW, 0.5), 0.4)
			if tier >= 3:
				SkillVfx.shockwave(p, origin, radius, Color(0.6, 0.4, 0.9, 0.6), 0.4)
			if tier >= 5:
				SkillVfx.burst(p, "magic", _up(origin, 1.8), 1.3, SHADOW)
			if tier >= 8:
				SkillVfx.rune(p, origin, radius * 1.2, Color(0.7, 0.4, 1.0, 0.8), "flash", float(r.duration), "glow_ring")
		"backstab":
			if not r.has("center"):
				return
			var c: Vector3 = r.center
			var color: Color = BLOOD if tier >= 3 else Color(0.9, 0.5, 0.6)
			SkillVfx.execute_slash(p, c, c - caster.global_position, 1.8 * (1.2 if tier >= 5 else 1.0), color)
			SkillVfx.burst(p, "spark", _up(c, 1.0), 0.9 + 0.1 * tier)
			if tier >= 3:
				SkillVfx.shockwave(p, c, 2.0, Color(1.0, 0.3, 0.4, 1.0), 0.3)
				SkillVfx.rune(p, c, 1.5, Color(color, 0.8), "flash", 0.4, "pulse_sigil")
			if tier >= 5:
				SkillVfx.burst(p, "fire", _up(c, 0.7), 1.0, Color(1.0, 0.2, 0.3))
			if tier >= 8 and bool(r.get("killed", false)):
				SkillVfx.pillar(p, c, 0.45, 6.5, Color(BLOOD, 0.9))
		"poison_blade":
			var links: Array = r.get("links", [])
			var color: Color = Color(0.4, 1.0, 0.3) if tier < 8 else Color(0.6, 1.0, 0.2)
			for link: Array in links:
				SkillVfx.missile(p, "crystal", _up(link[0], 1.0), _up(link[1], 1.0), color, 0.7, tier)
				SkillVfx.burst(p, "magic", _up(link[1], 1.0), 0.6, color)
			if tier >= 3:
				SkillVfx.rune(p, origin, 1.5, Color(color, 0.7), "expand", 0.35, "rune_circle")
			if tier >= 8:
				for link: Array in links:
					SkillVfx.pulse_ring(p, link[1], 1.5, Color(color, 0.6), 0.4)


# ---------------- 牧师 ----------------
static func _cleric(p: Node, caster: Node3D, id: String, r: Dictionary, origin: Vector3, tier: int) -> void:
	match id:
		"holy_nova":
			var radius: float = float(r.radius)
			SkillVfx.shockwave(p, origin, radius, Color(1.0, 0.9, 0.5, 1.0), 0.4)
			SkillVfx.burst(p, "star", _up(origin, 1.0), 1.0 + 0.1 * tier, HOLY)
			SkillVfx.rune(p, origin, radius, Color(GOLD, 0.8), "expand", 0.5, "holy_sigil")
			if tier >= 5:
				SkillVfx.shockwave(p, origin, radius * 1.2, Color(1.0, 1.0, 0.8, 0.8), 0.5)  # 推开
				SkillVfx.pillar(p, origin, 0.8, 7.0, Color(HOLY, 0.7))
			if tier >= 8:
				SkillVfx.pulse_ring(p, origin, radius, Color(0.7, 0.85, 1.0, 0.5), 0.6)  # 减速
				SkillVfx.rune(p, origin, radius * 1.3, Color(1.0, 0.95, 0.7, 0.8), "flash", 0.9, "glow_ring")
		"smite":
			var radius: float = float(r.radius)
			for impact: Vector3 in r.get("impacts", []):
				SkillVfx.pillar(p, impact, 0.6 * (1.4 if tier >= 8 else 1.0), 9.0, Color(1.0, 0.92, 0.55, 0.8))
				SkillVfx.shockwave(p, impact, radius, Color(1.0, 0.85, 0.4, 1.0), 0.3)
				SkillVfx.rune(p, impact, radius, Color(GOLD, 0.8), "flash", 0.5, "holy_sigil")
				if tier >= 5:
					SkillVfx.pulse_ring(p, impact, radius * 1.1, Color(0.7, 0.85, 1.0, 0.5), 0.45)  # 减速
				if tier >= 8:
					SkillVfx.crack_decal(p, impact, radius * 0.8, HOLY, 2.0)
					SkillVfx.burst(p, "star", _up(impact, 1.5), 1.2, HOLY)
		"sanctuary":
			var radius: float = float(r.radius)
			SkillVfx.burst(p, "star", _up(origin, 0.5), 1.2, Color(1.0, 0.9, 0.45))
			# 圣域地面区域由 ground_zone(holy) 绘制；这里叠加外圈光纹和段位装饰
			SkillVfx.rune(p, origin, radius, Color(GOLD, 0.6), "flash", float(r.duration), "holy_sigil")
			if tier >= 5:
				SkillVfx.rune(p, origin, radius * 1.1, Color(0.6, 1.0, 0.6, 0.5), "flash", float(r.duration), "glow_ring")  # 回复加倍
			if tier >= 8:
				SkillVfx.pillar(p, origin, 0.9, 10.0, Color(HOLY, 0.5))
				SkillVfx.shockwave(p, origin, radius, Color(1.0, 0.9, 0.5, 0.8), 0.5)
		"divine_shield":
			for a: Vector3 in r.get("shielded", []):
				SkillVfx.pulse_ring(p, a, 1.6, Color(0.6, 0.85, 1.0, 0.55), 0.45)
				SkillVfx.burst(p, "star", _up(a, 1.4), 0.9, Color(0.6, 0.85, 1.0))
				SkillVfx.buff(p, "shield", a, 5.0, Color(0.6, 0.85, 1.0), tier)
				if tier >= 8:
					SkillVfx.burst(p, "spark", _up(a, 1.0), 0.9, Color(0.9, 0.95, 1.0))  # 清除减速
			if tier >= 3:
				SkillVfx.rune(p, origin, 3.0, Color(0.6, 0.85, 1.0, 0.7), "expand", 0.5, "pulse_sigil")
		"blessing":
			for a: Vector3 in r.get("blessed", []):
				SkillVfx.pulse_ring(p, a, 1.6, Color(GOLD, 0.55), 0.45)
				SkillVfx.burst(p, "star", _up(a, 1.4), 0.9, GOLD)
				SkillVfx.buff(p, "bless", a, float(r.duration), GOLD, tier)
				if tier >= 8:
					SkillVfx.burst(p, "star", _up(a, 0.6), 1.0, Color(0.5, 1.0, 0.6))  # 回复生命
			if tier >= 3:
				SkillVfx.rune(p, origin, 3.0, Color(GOLD, 0.7), "expand", 0.5, "holy_sigil")
		"divine_intervention":
			for a: Vector3 in r.get("healed", []):
				SkillVfx.pulse_ring(p, a, 1.6, Color(GOLD, 0.55), 0.45)
				SkillVfx.burst(p, "star", _up(a, 1.4), 0.9, GOLD)
				if tier >= 3:
					SkillVfx.pillar(p, a, 0.5, 8.0, Color(HOLY, 0.7))
			SkillVfx.shockwave(p, origin, DivineIntervention.RANGE, Color(1.0, 0.9, 0.5, 1.0), 0.6)
			SkillVfx.rune(p, origin, DivineIntervention.RANGE * 0.6, Color(GOLD, 0.8), "expand", 0.8, "holy_sigil")
			if tier >= 5 and int(r.get("revived", 0)) > 0:
				SkillVfx.pillar(p, origin, 1.6, 12.0, Color(1.0, 1.0, 0.85, 0.8))  # 复活
			if tier >= 8:
				SkillVfx.shockwave(p, origin, DivineIntervention.RANGE * 1.3, Color(1.0, 0.95, 0.7, 0.8), 0.8)
				SkillVfx.rune(p, origin, DivineIntervention.RANGE, Color(1.0, 0.95, 0.75, 0.7), "flash", 1.2, "glow_ring")
		"guardian_angel":
			var duration: float = float(r.duration)
			for a: Node in caster.get_tree().get_nodes_in_group("players"):
				if a is Node3D and not a.is_dead and (a as Node3D).global_position.distance_to(origin) <= 12.0:
					var pos: Vector3 = (a as Node3D).global_position
					SkillVfx.burst(p, "star", _up(pos, 2.0), 1.0, Color(1.0, 1.0, 0.9))
					SkillVfx.pulse_ring(p, pos, 2.0, Color(1.0, 0.95, 0.7, 0.6), 0.5)
					SkillVfx.buff(p, "shield", pos, duration, Color(1.0, 1.0, 0.85), tier)
			SkillVfx.rune(p, origin, 3.0, Color(HOLY, 0.8), "expand", 0.6, "holy_sigil")
			if tier >= 3:
				SkillVfx.pillar(p, origin, 1.0, 10.0, Color(1.0, 1.0, 0.9, 0.6))
			if tier >= 8:
				SkillVfx.shockwave(p, origin, 12.0, Color(1.0, 0.95, 0.7, 0.8), 0.6)
		"purify":
			var radius: float = float(r.radius)
			SkillVfx.burst(p, "star", _up(origin, 1.5), 1.3 + 0.1 * tier, HOLY)
			SkillVfx.shockwave(p, origin, radius, Color(1.0, 0.95, 0.7, 1.0), 0.5)
			SkillVfx.rune(p, origin, radius * 0.9, Color(GOLD, 0.8), "expand", 0.6, "holy_sigil")
			for h: Vector3 in r.get("healed", []):
				SkillVfx.burst(p, "star", _up(h, 1.2), 0.8, Color(0.5, 1.0, 0.6))
			if tier >= 5:
				SkillVfx.pulse_ring(p, origin, radius, Color(0.7, 0.9, 1.0, 0.6), 0.6)  # 减伤
			if tier >= 8:
				SkillVfx.pillar(p, origin, 1.0, 9.0, Color(HOLY, 0.8))
				SkillVfx.crack_decal(p, origin, radius * 0.6, HOLY, 2.0)
		"resurrection":
			var healed: Array = r.get("healed", [])
			for h: Vector3 in healed:
				SkillVfx.pillar(p, h, 0.8, 12.0, Color(1.0, 1.0, 0.95, 0.9))
				SkillVfx.burst(p, "star", _up(h, 2.5), 1.5, Color(1.0, 1.0, 0.9))
				SkillVfx.shockwave(p, h, 3.0, Color(1.0, 0.95, 0.8, 1.0), 0.5)
				SkillVfx.rune(p, h, 2.5, Color(HOLY, 0.9), "flash", 0.8, "holy_sigil")
			if healed.is_empty():
				# 无人倒地：全队加护盾
				for a: Node in caster.get_tree().get_nodes_in_group("players"):
					if a is Node3D and not a.is_dead:
						SkillVfx.pulse_ring(p, (a as Node3D).global_position, 1.6, Color(0.6, 0.85, 1.0, 0.55), 0.45)
						SkillVfx.burst(p, "star", _up((a as Node3D).global_position, 1.4), 0.9, Color(0.6, 0.85, 1.0))
			SkillVfx.rune(p, origin, 3.0, Color(HOLY, 0.8), "expand", 0.7, "holy_sigil")
			if tier >= 8:
				SkillVfx.pillar(p, origin, 1.4, 12.0, Color(1.0, 1.0, 0.9, 0.7))
		"holy_wrath":
			if not r.has("center"):
				return
			var c: Vector3 = r.center
			SkillVfx.pillar(p, c, 0.7 * (1.3 if tier >= 5 else 1.0), 10.0, Color(HOLY, 0.9))
			SkillVfx.burst(p, "star", _up(c, 1.5), 1.2 + 0.1 * tier, HOLY)
			SkillVfx.shockwave(p, c, 2.5, Color(1.0, 0.9, 0.5, 1.0), 0.4)
			if tier >= 3:
				SkillVfx.rune(p, c, 2.2, Color(GOLD, 0.8), "flash", 0.5, "holy_sigil")
			if tier >= 5:
				SkillVfx.shockwave(p, c, 3.5, Color(1.0, 0.95, 0.7, 0.9), 0.5)
			if tier >= 8:
				SkillVfx.crack_decal(p, c, 3.0, HOLY, 2.5)
				SkillVfx.burst(p, "fire", _up(c, 1.0), 1.5, Color(1.0, 0.95, 0.7))


# ---------------- 普攻 ----------------
## kind：pulse 铁卫盾纹脉冲；slash 影行者交叉斩；bolt 远程（bolt_fx：crystal 术士水晶 / holy 牧师圣光十字）。
static func auto_attack(p: Node, caster: Node3D, kind: String, bolt_fx: String, victims: Array, radius: float, burn: bool,
		bolt_color: Color) -> void:
	if victims.is_empty():
		return
	var at: Vector3 = caster.global_position
	var first: Vector3 = (victims[0] as Node3D).global_position
	var slot: int = int(caster.get("net_slot"))
	match kind:
		"pulse": SkillVfx.pose(p, slot, "bash", 0.3)
		"slash": SkillVfx.pose(p, slot, "swing" if randf() < 0.5 else "swing_l", 0.28)
		_: SkillVfx.pose(p, slot, "cast", 0.3)
	match kind:
		"pulse":
			SkillVfx.shield_pulse(p, at, radius, Color(1.0, 0.5, 0.2) if burn else Color(0.6, 0.8, 1.0), 6)
		"slash":
			SkillVfx.execute_slash(p, first, first - at, 1.5, Color(1.0, 0.5, 0.2) if burn else SHADOW)
		_:
			SkillVfx.missile(p, bolt_fx, _up(at, 1.3), _up(first, 1.0), FIRE if burn else Color(bolt_color, 1.0))
