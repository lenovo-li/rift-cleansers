class_name GroundZone extends RefCounted
## 线段形持续伤害区域（例如盾击 8 级的火焰地带）。每 TICK_INTERVAL 秒结算一次。

const TICK_INTERVAL: float = 0.5

var a: Vector3
var b: Vector3
var half_width: float
var damage_per_tick: float
var remaining: float
## 可选：跟随的对象（需有 global_position）。设置后每次 tick 前把区域平移到它的位置。
var anchor: Object = null
## 可选：命中时附加减速（目标需实现 apply_slow(factor, duration)）。0 表示不减速。
var slow_factor: float = 0.0
var slow_duration: float = 0.0
## 可选：命中时附加燃烧（目标需有 status: StatusEffects）。0 表示不燃烧。
var burn_dps: float = 0.0
## 表现层用的类型标签（flame / whirl / slam / aura）。
var kind: String = ""
var _tick_timer: float = 0.0


func _init(p_a: Vector3, p_b: Vector3, p_half_width: float, dps: float, duration: float) -> void:
	a = p_a
	b = p_b
	half_width = p_half_width
	damage_per_tick = dps * TICK_INTERVAL
	remaining = duration


func is_expired() -> bool:
	return remaining <= 0.0


## 推进时间并结算伤害，返回本次命中次数。
func tick(delta: float, targets: Array) -> int:
	if is_expired():
		return 0
	if anchor != null and is_instance_valid(anchor):
		var p: Vector3 = anchor.global_position
		b = p + (b - a)
		a = p
	remaining -= delta
	_tick_timer += delta
	var hits: int = 0
	while _tick_timer >= TICK_INTERVAL:
		_tick_timer -= TICK_INTERVAL
		for t: Variant in targets:
			if is_instance_valid(t) and t.is_alive and contains(t.global_position):
				t.take_damage(damage_per_tick)
				if slow_factor > 0.0 and t.has_method("apply_slow"):
					t.apply_slow(slow_factor, slow_duration)
				if burn_dps > 0.0:
					var s: StatusEffects = Reactions.status_of(t)
					if s != null:
						s.apply_burn(burn_dps, 3.0)
				hits += 1
	return hits


func contains(p: Vector3) -> bool:
	return distance_xz_to_segment(p, a, b) <= half_width


## 点 p 到线段 ab 在 XZ 平面上的距离。
static func distance_xz_to_segment(p: Vector3, seg_a: Vector3, seg_b: Vector3) -> float:
	var ab: Vector2 = Vector2(seg_b.x - seg_a.x, seg_b.z - seg_a.z)
	var ap: Vector2 = Vector2(p.x - seg_a.x, p.z - seg_a.z)
	var len_sq: float = ab.length_squared()
	var t: float = 0.0 if len_sq < 0.000001 else clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	return (ap - ab * t).length()
