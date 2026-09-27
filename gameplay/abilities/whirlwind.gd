class_name Whirlwind extends Skill
## 旋风斩：持续旋转攻击周围敌人，可移动施法

const BASE_DAMAGE: float = 15.0  # 每0.2秒伤害
const BASE_RADIUS: float = 4.0
const DURATION: float = 3.0
const TICK_INTERVAL: float = 0.2


func _init() -> void:
	skill_id = "whirlwind"
	display_name = "旋风斩"
	max_level = 10


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	var cd: float = 8.0
	if level >= 5:
		cd *= 0.8
	return cd


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var damage: float = BASE_DAMAGE * _damage_mult(tier)
	var radius: float = BASE_RADIUS * _radius_mult(tier)
	var duration: float = DURATION * _duration_mult(tier)
	
	# 旋风斩创建一个持续伤害区域（圆形，跟随施法者）
	var zone: WhirlwindZone = WhirlwindZone.new(ctx.origin, radius, damage / TICK_INTERVAL, duration, tier)
	ctx.new_zones.append(zone)
	
	return {
		"hits": 0,  # 初始命中为0，实际伤害由zone.tick计算
		"damage": 0.0,
		"tier": tier,
		"duration": duration
	}


func _damage_mult(tier: int) -> float:
	match tier:
		1: return 1.0
		3: return 1.3
		5: return 1.6
		8: return 2.0
		_: return 1.0


func _radius_mult(tier: int) -> float:
	return 1.3 if tier >= 5 else 1.0


func _duration_mult(tier: int) -> float:
	return 1.5 if tier >= 8 else 1.0


## 旋风斩专用持续伤害区域
class WhirlwindZone extends GroundZone:
	var tier: int = 1
	var last_hit_time: Dictionary = {}  # entity_id -> last_hit_time
	
	func _init(center: Vector3, p_radius: float, dps: float, p_duration: float, p_tier: int) -> void:
		super._init(center, center, p_radius, dps, p_duration)
		tier = p_tier
	
	## 重写contains：圆形范围而非线段
	func contains(p: Vector3) -> bool:
		var offset: Vector3 = p - a  # a是中心点
		offset.y = 0.0
		return offset.length() <= half_width  # half_width实际是radius
	
	## 重写tick：每个敌人间隔TICK_INTERVAL才能再次受伤
	func tick(delta: float, targets: Array) -> int:
		if is_expired():
			return 0
		remaining -= delta
		_tick_timer += delta
		
		var hits: int = 0
		while _tick_timer >= TICK_INTERVAL:
			_tick_timer -= TICK_INTERVAL
			var current_time: float = remaining  # 用剩余时间作为时间戳
			
			for t: Variant in targets:
				if not (is_instance_valid(t) and t.is_alive):
					continue
				
				if not contains(t.global_position):
					continue
				
				# 检查是否可以再次命中
				var entity_id: int = t.entity_id if t.has("entity_id") else t.get_instance_id()
				var last_time: float = last_hit_time.get(entity_id, -999.0)
				
				if current_time - last_time >= TICK_INTERVAL - 0.01:  # 允许0.01秒误差
					t.take_damage(damage_per_tick)
					last_hit_time[entity_id] = current_time
					hits += 1
					
					# Tier3+: 减速
					if tier >= 3 and t.has_method("apply_slow"):
						t.apply_slow(0.5, 1.0)  # 50%减速，持续1秒
		
		return hits
