class_name Boss extends Enemy
## 地图 Boss（每张地图一个，见 MapCatalog.boss），共用三阶段：1（100%-60%）→ 2（60%-30%）→ 3（30%-0% 狂暴）。
## 各 Boss 的技能组合不同（variant = def.enemy_id）：
## - 腐化骑士：近战 + 召唤；2 阶段冲锋（1 秒红色箭头预警）；3 阶段攻速 +50%，每 5 秒召唤 1 只精英
## - 霜冻巫妖：保持距离，扇形冰弹齐射；2 阶段冰霜新星（脚下预警圈）；3 阶段冰雨（每名玩家脚下落冰）
## - 沙之巨像：近战，定期震地；2 阶段钻地突袭（目标脚下预警后从那里冒出）；3 阶段沙暴（减速区）
## - 腐木树人：根须突刺（朝目标一串预警圈）；2 阶段毒孢子区；3 阶段缓慢回血（不会回到 2 阶段）
## 另有随机词缀（affix）改变打法：狂暴 / 坚韧 / 召唤 / 爆裂，由 EnemySpawner 生成时掷骰。

signal phase_changed(phase: int)
signal summon_requested(enemy_id: String, count: int, elite_mod: String, center: Vector3)

const SUMMON_INTERVAL: float = 12.0
const SUMMON_WAVES: int = 4
const SUMMON_SIZE: int = 5
const CHARGE_INTERVAL: float = 6.0
const CHARGE_WINDUP: float = 1.0
const CHARGE_SPEED: float = 26.0
const ELITE_INTERVAL: float = 5.0
const BlastSceneScript: GDScript = preload("res://gameplay/actors/delayed_blast.gd")
const ZoneScript: GDScript = preload("res://gameplay/actors/hazard_zone.gd")
const AFFIXES: Array[String] = ["", "berserk", "fortified", "summoner", "volatile"]
const AFFIX_NAMES: Dictionary = {"berserk": "狂暴", "fortified": "坚韧", "summoner": "召唤", "volatile": "爆裂"}
## 各 Boss 召唤的小怪（奇数波、偶数波）
const SUMMONS: Dictionary = {
	"corrupted_knight": ["zombie", "skeleton"], "frost_lich": ["skeleton", "skeleton"],
	"sand_colossus": ["zombie", "bloater"], "rotwood_treant": ["ghoul", "necromancer"],
}
const PHASE_HINTS: Dictionary = {
	"corrupted_knight": ["", "冲锋！注意红色预警", "狂暴！"],
	"frost_lich": ["", "冰霜新星！远离它的脚下", "冰雨降临！不要停下"],
	"sand_colossus": ["", "钻地突袭！看脚下的预警圈", "沙暴！避开减速区"],
	"rotwood_treant": ["", "毒孢子蔓延！", "开始再生！尽快击杀"],
}

var phase: int = 1
## 生成前由 EnemySpawner 设置
var affix: String = ""
var variant: String = "corrupted_knight"
var _summon_timer: float = 4.0
var _waves_done: int = 0
var _charge_timer: float = CHARGE_INTERVAL
var _charge_state: int = 0  # 0 无 1 预警 2 冲锋
var _charge_time: float = 0.0
var _charge_dir: Vector3 = Vector3.ZERO
var _charge_hit: bool = false
var _elite_timer: float = ELITE_INTERVAL
var _telegraph: MeshInstance3D = null
## 通用技能计时器：a = 主技能，b = 2 阶段技能，c = 3 阶段技能 / 爆裂词缀
var _timer_a: float = 3.0
var _timer_b: float = 5.0
var _timer_c: float = 4.0
var _timer_affix: float = 10.0
var _burrow_time: float = 0.0
var _burrow_pos: Vector3 = Vector3.ZERO


## 血量比例 -> 阶段。
static func phase_for_ratio(ratio: float) -> int:
	if ratio > 0.6:
		return 1
	if ratio > 0.3:
		return 2
	return 3


static func phase_hint(boss_id: String, p: int) -> String:
	var hints: Array = PHASE_HINTS.get(boss_id, PHASE_HINTS.corrupted_knight)
	return hints[clampi(p - 1, 0, hints.size() - 1)]


func _ready() -> void:
	if affix == "fortified":
		health_scale *= 1.3
	super._ready()
	variant = def.enemy_id
	knockback_resist = 1.0 if affix == "fortified" else 0.9
	add_to_group("boss")


func get_display_name() -> String:
	var n: String = def.display_name if def != null else "Boss"
	return "%s·%s" % [AFFIX_NAMES[affix], n] if AFFIX_NAMES.has(affix) else n


func health_ratio() -> float:
	return current_health / max_health


func move_speed() -> float:
	return super.move_speed() * (1.3 if affix == "berserk" else 1.0)


func _behavior_velocity(delta: float, dir: Vector3, dist: float) -> Vector3:
	var new_phase: int = phase_for_ratio(health_ratio())
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)
		if affix == "volatile":
			_rain_on_players(2, 2.5, 1.2, 35.0, Color(1.0, 0.4, 0.1, 0.45), "爆裂坠石")
	if affix == "berserk":
		attack_timer -= delta * 0.3
	if affix == "volatile":
		_timer_affix -= delta
		if _timer_affix <= 0.0:
			_timer_affix = 10.0
			_rain_on_players(1, 2.5, 1.2, 35.0, Color(1.0, 0.4, 0.1, 0.45), "爆裂坠石")
	_update_summons(delta)
	if _burrow_time > 0.0:
		return _burrow(delta)
	match variant:
		"frost_lich": return _lich(delta, dir, dist)
		"sand_colossus": return _colossus(delta, dir, dist)
		"rotwood_treant": return _treant(delta, dir, dist)
	return _knight(delta, dir, dist)


func _update_summons(delta: float) -> void:
	var waves: int = SUMMON_WAVES + (2 if affix == "summoner" else 0)
	var size: int = SUMMON_SIZE + (2 if affix == "summoner" else 0)
	if _waves_done >= waves:
		return
	_summon_timer -= delta
	if _summon_timer <= 0.0:
		_summon_timer = SUMMON_INTERVAL * (0.75 if affix == "summoner" else 1.0)
		_waves_done += 1
		var pair: Array = SUMMONS.get(variant, SUMMONS.corrupted_knight)
		summon_requested.emit(pair[0] if _waves_done % 2 == 1 else pair[1], size, "", global_position)


func _chase(dir: Vector3, dist: float) -> Vector3:
	return dir * move_speed() if dist > def.attack_range * def.body_scale * 0.8 else Vector3.ZERO


# ---------- 腐化骑士 ----------

func _knight(delta: float, dir: Vector3, dist: float) -> Vector3:
	if phase == 3:
		attack_timer -= delta * 0.5  # 攻速 +50%
		_elite_timer -= delta
		if _elite_timer <= 0.0:
			_elite_timer = ELITE_INTERVAL
			summon_requested.emit("skeleton", 1, SpawnDirector.ELITE_MODS.pick_random(), global_position)
	if phase >= 2:
		var v: Variant = _charge(delta, dir)
		if v != null:
			return v
	return _chase(dir, dist)


## 冲锋：预警 1 秒（地面红色箭头指向冲锋方向）→ 高速直线冲撞。返回 null 表示不在冲锋中。
func _charge(delta: float, dir: Vector3) -> Variant:
	match _charge_state:
		0:
			_charge_timer -= delta
			if _charge_timer > 0.0:
				return null
			_charge_state = 1
			_charge_time = CHARGE_WINDUP
			_charge_dir = dir
			_show_telegraph(true)
			return Vector3.ZERO
		1:
			_charge_time -= delta
			if _charge_time > 0.0:
				return Vector3.ZERO
			_charge_state = 2
			_charge_time = def.special_range / CHARGE_SPEED
			_charge_hit = false
			_show_telegraph(false)
			return _charge_dir * CHARGE_SPEED
		_:
			_charge_time -= delta
			if not _charge_hit:
				for p: Node3D in PlayerQuery.alive_in_radius(get_tree(), global_position, 2.5):
					_charge_hit = true
					p.take_damage(def.special_value, self)
			if _charge_time <= 0.0:
				_charge_state = 0
				_charge_timer = CHARGE_INTERVAL * (0.7 if phase == 3 else 1.0)
			return _charge_dir * CHARGE_SPEED


# ---------- 霜冻巫妖 ----------

func _lich(delta: float, dir: Vector3, dist: float) -> Vector3:
	_timer_a -= delta
	if _timer_a <= 0.0:
		_timer_a = 3.5 if phase < 3 else 2.5
		var n: int = 3 if phase == 1 else 5
		for i in n:
			_shoot_colored(dir.rotated(Vector3.UP, deg_to_rad((i - (n - 1) / 2.0) * 14.0)), 18.0, Color(0.5, 0.85, 1.0))
	if phase >= 2:
		_timer_b -= delta
		if _timer_b <= 0.0:
			_timer_b = 7.0
			_blast(global_position, 6.0, 1.2, def.special_value, Color(0.5, 0.85, 1.0, 0.45), "%s的冰霜新星" % def.display_name)
	if phase >= 3:
		_timer_c -= delta
		if _timer_c <= 0.0:
			_timer_c = 6.0
			_rain_on_players(3, 2.5, 1.3, 35.0, Color(0.6, 0.9, 1.0, 0.45), "%s的冰雨" % def.display_name)
	# 保持 9 米左右的距离：太近后撤，太远靠近
	if dist < 7.0:
		return -dir * move_speed() * 0.8
	return dir * move_speed() if dist > 11.0 else Vector3.ZERO


func _shoot_colored(dir: Vector3, damage: float, color: Color) -> void:
	var p: Node3D = ProjectileScript.new()
	p.setup(self, dir, damage, color)
	effects_parent.add_child(p)
	p.global_position = global_position + Vector3(0, 1.5, 0) + dir * 1.5
	SkillVfx.record(["proj", p.global_position, dir, color])


# ---------- 沙之巨像 ----------

func _colossus(delta: float, dir: Vector3, dist: float) -> Vector3:
	_timer_a -= delta
	if _timer_a <= 0.0:
		_timer_a = 6.0 if phase < 3 else 4.5
		_blast(global_position, def.special_range, 1.0, 60.0, Color(0.95, 0.65, 0.25, 0.45), "%s的震地" % def.display_name)
	if phase >= 2:
		_timer_b -= delta
		if _timer_b <= 0.0 and target_player != null:
			_timer_b = 9.0
			_burrow_pos = target_player.global_position
			_burrow_time = 1.5
			_blast(_burrow_pos, 4.0, 1.5, def.special_value, Color(0.9, 0.55, 0.2, 0.5), "%s的钻地突袭" % def.display_name)
			return Vector3.ZERO
	if phase >= 3:
		_timer_c -= delta
		if _timer_c <= 0.0:
			_timer_c = 8.0
			_zones_on_players(2, 3.5, 0.4, 10.0, 6.0, Color(0.85, 0.7, 0.4, 0.35), "沙暴")
	return _chase(dir, dist)


## 钻地：原地停 1.5 秒（预警圈在目标脚下），然后从那里冒出来。
func _burrow(delta: float) -> Vector3:
	_burrow_time -= delta
	if _burrow_time <= 0.0:
		global_position = MapBase.current.find_free(_burrow_pos, 1.5) if MapBase.current else _burrow_pos
		SkillVfx.shockwave(effects_parent, global_position, 4.0, Color(0.95, 0.7, 0.3, 1.0), 0.4)
	return Vector3.ZERO


# ---------- 腐木树人 ----------

func _treant(delta: float, dir: Vector3, dist: float) -> Vector3:
	_timer_a -= delta
	if _timer_a <= 0.0:
		_timer_a = 6.0 if phase < 3 else 4.0
		for i in 6:
			var pos: Vector3 = global_position + dir * (2.5 + i * 2.4)
			_blast(pos, 1.6, 0.9 + i * 0.12, 40.0, Color(0.45, 0.8, 0.3, 0.45), "%s的根须" % def.display_name)
	if phase >= 2:
		_timer_b -= delta
		if _timer_b <= 0.0:
			_timer_b = 8.0
			_zones_on_players(3, 3.0, 0.3, 12.0, 6.0, Color(0.5, 0.8, 0.2, 0.35), "毒孢子")
	if phase >= 3:
		# 再生：每秒 0.6% 最大生命，但不会回到 30% 以上（不回退阶段）
		current_health = minf(current_health + max_health * 0.006 * delta, max_health * 0.3)
	return _chase(dir, dist)


# ---------- 公共：预警圈 / 危险区 ----------

func _blast(pos: Vector3, radius: float, fuse: float, damage: float, color: Color, source: String) -> void:
	var b: Node3D = BlastSceneScript.new()
	b.setup(radius, damage, fuse, source)
	b.color = color
	effects_parent.add_child(b)
	b.global_position = Vector3(pos.x, 0.0, pos.z)
	SkillVfx.record(["blast", b.global_position, radius, fuse, color])


## 每名存活玩家附近 count 个预警圈（第一个正落在脚下）。
func _rain_on_players(count: int, radius: float, fuse: float, damage: float, color: Color, source: String) -> void:
	for p: Node3D in PlayerQuery.alive(get_tree()):
		for i in count:
			var off: Vector3 = Vector3.ZERO if i == 0 else Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			_blast(p.global_position + off, radius, fuse + i * 0.2, damage, color, source)


func _zones_on_players(count: int, radius: float, slow: float, dps: float, duration: float, color: Color, source: String) -> void:
	for p: Node3D in PlayerQuery.alive(get_tree()):
		for i in count:
			var a: float = randf() * TAU
			var z: Node3D = ZoneScript.new()
			z.setup(radius, slow, duration, color)
			z.dps = dps
			z.source_name = source
			effects_parent.add_child(z)
			z.global_position = p.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 6.0)
			SkillVfx.record(["hazard", z.global_position, radius, duration, color])


func _show_telegraph(visible_now: bool) -> void:
	if _telegraph == null:
		_telegraph = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(2.0, 0.05, def.special_range)
		_telegraph.mesh = box
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.1, 0.1, 0.45)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_telegraph.material_override = mat
		_telegraph.top_level = true
		add_child(_telegraph)
	_telegraph.visible = visible_now
	if visible_now:
		var center: Vector3 = global_position + _charge_dir * def.special_range * 0.5
		_telegraph.global_transform = Transform3D(Basis.looking_at(_charge_dir, Vector3.UP), Vector3(center.x, 0.05, center.z))
		SkillVfx.record(["telegraph", center, _charge_dir, def.special_range, CHARGE_WINDUP])


## 冲锋预警中（或正在冲锋）时返回 {origin, dir, length}，否则空字典（机器人横移躲避用）。
func charge_warning() -> Dictionary:
	if _charge_state == 0:
		return {}
	return {"origin": global_position, "dir": _charge_dir, "length": def.special_range}


## Boss 不会被击退打断冲锋/钻地。
func apply_knockback(impulse: Vector3) -> void:
	if _charge_state == 0 and _burrow_time <= 0.0:
		super.apply_knockback(impulse)


func die() -> void:
	if _telegraph != null:
		_telegraph.visible = false
	super.die()
