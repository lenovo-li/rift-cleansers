class_name PlayerRig extends RefCounted
## 可动角色：把 <model>_rig.glb 的分组网格（body / head / arm_l / arm_r / leg_l / leg_r）挂在玩家的 "Mesh" 节点下，
## 每帧按跑动相位摆腿、摆臂，并叠加动作姿势（挥砍、盾击、施法、举手、旋转、砸地）。
## 头和手臂是躯干的子节点，躯干前倾 / 扭腰时一起动；腿挂在根节点上，保持落地。
## 纯表现：各端按自己看到的位移和收到的 pose 事件计算，不走网络同步。
## 约定：Godot 里角色前方 -Z，+X 是角色左侧（arm_l 持盾 / 副手），arm_r 持武器。

## 动作 -> 默认时长（秒）
const ACTIONS: Dictionary = {
	"swing": 0.32, "swing_l": 0.32, "bash": 0.35, "cast": 0.35, "raise": 0.5, "spin": 1.0, "slam": 0.55, "roar": 0.5,
}

var parts: Dictionary = {}  # 分组名 -> MeshInstance3D
var has_legs: bool = false
var _rest: Dictionary = {}  # 分组名 -> 静止时的局部位置
var _action: String = ""
var _action_t: float = 0.0
var _action_len: float = 1.0


## 在 root（玩家的 "Mesh" 节点）下按拆件建出各部分。rig 为 ModelLibrary.rig() 的结果。
## materials(mesh) 返回该网格每个表面的材质数组。
func build(root: MeshInstance3D, rig: Dictionary, materials: Callable) -> void:
	var body_joint: Vector3 = rig["body"][1] if rig.has("body") else Vector3.ZERO
	for key: String in ["body", "leg_l", "leg_r", "head", "arm_l", "arm_r"]:
		if not rig.has(key):
			continue
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = key
		mi.mesh = rig[key][0]
		var mats: Array = materials.call(mi.mesh)
		for i in mats.size():
			mi.set_surface_override_material(i, mats[i])
		var joint: Vector3 = rig[key][1]
		var holder: Node3D = root
		if key in ["head", "arm_l", "arm_r"] and parts.has("body"):
			holder = parts["body"]
			joint -= body_joint
		holder.add_child(mi)
		mi.position = joint
		parts[key] = mi
		_rest[key] = joint
	has_legs = parts.has("leg_l") and parts.has("leg_r")


func play(action: String, duration: float = -1.0) -> void:
	_action = action
	_action_len = maxf(0.05, duration if duration > 0.0 else float(ACTIONS.get(action, 0.4)))
	_action_t = 0.0


func is_playing() -> bool:
	return not _action.is_empty()


## 每帧：phase 跑动相位，run 0-1 跑动强度，punch 受击 0-1，down 倒地 0-1。
func update(delta: float, phase: float, run: float, punch: float, down: float) -> void:
	if parts.is_empty():
		return
	var swing: float = sin(phase) * run
	# 基础：走跑时手脚交替摆动；静止时手臂自然下垂轻晃
	var leg: float = swing * 0.75
	var arm_l: Vector3 = Vector3(-swing * 0.55, 0, 0)
	var arm_r: Vector3 = Vector3(swing * 0.55, 0, 0)
	var body: Vector3 = Vector3(0, sin(phase) * 0.08 * run, 0)  # 跑动时扭腰
	var head: Vector3 = Vector3(0, -body.y * 0.8, 0)
	# 受击：上身后仰、手臂张开
	if punch > 0.0:
		body.x += punch * 0.35
		head.x += punch * 0.25
		arm_l.z += punch * 0.5
		arm_r.z -= punch * 0.5
	# 倒地（根节点已侧躺）：手臂摊开、腿微屈
	if down > 0.0:
		arm_l.z += down * 1.1
		arm_r.z -= down * 0.9
		leg = lerpf(leg, 0.3, down)
	if not _action.is_empty():
		_action_t += delta
		var t: float = clampf(_action_t / _action_len, 0.0, 1.0)
		_apply_action(t, arm_l, arm_r, body, head)
		if _action_t >= _action_len:
			_action = ""
	else:
		_pose("arm_l", arm_l)
		_pose("arm_r", arm_r)
		_pose("body", body)
		_pose("head", head)
	if has_legs:
		_pose("leg_l", Vector3(leg, 0, 0))
		_pose("leg_r", Vector3(-leg, 0, 0))


## 动作姿势叠加到基础姿势上。t 为动作进度 0-1；各动作末尾自然回到基础姿势。
func _apply_action(t: float, arm_l: Vector3, arm_r: Vector3, body: Vector3, head: Vector3) -> void:
	var back: float = 1.0 - smoothstep(0.7, 1.0, t)  # 收招权重
	match _action:
		"swing", "swing_l":
			# 举到身后上方 → 向前劈下 → 收回；同时扭腰
			var a: float
			if t < 0.25:
				a = lerpf(0.0, -2.3, _ease_out(t / 0.25))
			elif t < 0.55:
				a = lerpf(-2.3, 1.3, _ease_in((t - 0.25) / 0.3))
			else:
				a = lerpf(1.3, 0.0, _ease_out((t - 0.55) / 0.45))
			var twist: float = (-0.35 if t < 0.25 else 0.45) * back
			if _action == "swing":
				arm_r = Vector3(a, 0, -0.15)
				body.y += twist
			else:
				arm_l = Vector3(a, 0, 0.15)
				body.y -= twist
			body.x -= 0.15 * sin(t * PI)
		"bash":
			# 盾（左臂）猛推向前，身体前冲
			var k: float = sin(minf(t / 0.35, 1.0) * PI * 0.5) * back
			arm_l = Vector3(1.4 * k, 0, 0.1)
			arm_r.x = lerpf(arm_r.x, -0.4, k)
			body.x -= 0.3 * k
			body.y -= 0.25 * k
		"cast":
			# 持武器的手臂前指，副手张开
			var k: float = _ease_out(minf(t / 0.3, 1.0)) * back
			arm_r = Vector3(lerpf(arm_r.x, 1.5, k), 0, -0.1 * k)
			arm_l = Vector3(lerpf(arm_l.x, 0.6, k), 0, 0.45 * k)
			body.x -= 0.1 * k
		"raise", "roar":
			# 双手高举（新星、祝福、嘲讽）
			var k: float = _ease_out(minf(t / 0.35, 1.0)) * back
			arm_l = Vector3(lerpf(arm_l.x, 2.6, k), 0, 0.35 * k)
			arm_r = Vector3(lerpf(arm_r.x, 2.6, k), 0, -0.35 * k)
			body.x += 0.18 * k
			head.x += 0.3 * k
		"slam":
			# 双手举过头顶 → 砸向地面，身体下蹲前压
			var a: float
			if t < 0.35:
				a = lerpf(0.0, 2.8, _ease_out(t / 0.35))
			elif t < 0.55:
				a = lerpf(2.8, 0.9, _ease_in((t - 0.35) / 0.2))
			else:
				a = lerpf(0.9, 0.0, _ease_out((t - 0.55) / 0.45))
			arm_l = Vector3(a, 0, 0.2)
			arm_r = Vector3(a, 0, -0.2)
			body.x -= (0.45 if t > 0.35 else -0.1) * sin(minf(t, 0.8) / 0.8 * PI)
		"spin":
			# 旋风：身体持续自转、双臂平展
			var k: float = minf(t / 0.1, 1.0) * back
			body.y += t * _action_len * 9.0
			arm_l = Vector3(0.3, 0, 1.3 * k)
			arm_r = Vector3(0.3, 0, -1.3 * k)
			head.y -= body.y  # 头朝前，只转身体
	_pose("arm_l", arm_l)
	_pose("arm_r", arm_r)
	_pose("body", body)
	_pose("head", head)


func _pose(key: String, rot: Vector3) -> void:
	var mi: MeshInstance3D = parts.get(key)
	if mi != null:
		mi.rotation = rot


static func _ease_out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


static func _ease_in(x: float) -> float:
	return x * x
