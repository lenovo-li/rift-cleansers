extends CharacterBody3D
## M1 玩家控制器 - 完整战斗系统版本

const SPEED: float = 8.0

@export var max_health: float = 1000.0
@export var attack_damage: float = 25.0
@export var attack_range: float = 3.5
@export var attack_interval: float = 1.0

var current_health: float = 1000.0
var entity_id: int = 0
var attack_timer: float = 0.0

# 技能系统（不依赖Node）
var ability_system: AbilitySystem = null
var shield_bash: ShieldBash = null
var whirlwind = null  # Whirlwind技能


func _ready() -> void:
	current_health = max_health
	
	# 初始化技能系统
	ability_system = AbilitySystem.new()
	shield_bash = ShieldBash.new()
	ability_system.add_skill(shield_bash)
	
	whirlwind = preload("res://gameplay/abilities/whirlwind.gd").new()
	ability_system.add_skill(whirlwind)
	
	# 连接升级事件
	var game_session: Node = get_tree().root.find_child("GameSession", true, false)
	if game_session:
		game_session.level_up.connect(_on_level_up)


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction: Vector3 = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		# 朝移动方向转身
		var target_rotation: float = atan2(direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 0.2)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()
	
	# 自动攻击
	attack_timer -= delta
	if attack_timer <= 0.0:
		auto_attack()
		attack_timer = attack_interval
	
	# 技能冷却
	if ability_system != null:
		var enemies: Array = get_tree().get_nodes_in_group("enemies")
		ability_system.tick(delta, enemies)
	
	# 技能输入
	if Input.is_action_just_pressed("ui_accept"):
		_use_shield_bash()
	
	if Input.is_action_just_pressed("skill_1"):
		_use_whirlwind()


func _use_whirlwind() -> void:
	if ability_system == null or not ability_system.can_cast("whirlwind"):
		return
	
	var ctx: SkillContext = SkillContext.new()
	ctx.caster = self
	ctx.origin = global_position
	ctx.targets = get_tree().get_nodes_in_group("enemies")
	
	var result: Dictionary = ability_system.cast("whirlwind", ctx)
	if result.is_empty():
		return
	
	var level: int = ability_system.get_level("whirlwind")
	var tier: int = result.get("tier", 1)
	print("[PlayerM1] Whirlwind Lv%d (Tier%d)! duration=%.1fs" % [level, tier, result.duration])
	
	# 视觉特效 + 音效
	SkillVfx.whirlwind(get_tree().root.get_child(0), self, 4.0 * (1.3 if tier >= 5 else 1.0), result.duration)
	var sfx_mgr: Script = preload("res://core/audio/sfx_manager.gd")
	sfx_mgr.play_whoosh(get_tree().current_scene)


func _use_shield_bash() -> void:
	if ability_system == null or not ability_system.can_cast("shield_bash"):
		return
	
	var ctx: SkillContext = SkillContext.new()
	ctx.caster = self
	ctx.origin = global_position
	# 使用玩家当前旋转计算朝向
	ctx.facing = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	ctx.targets = get_tree().get_nodes_in_group("enemies")
	
	var result: Dictionary = ability_system.cast("shield_bash", ctx)
	if result.is_empty():
		return
	
	var level: int = ability_system.get_level("shield_bash")
	var tier: int = result.get("tier", 1)
	print("[PlayerM1] Shield Bash Lv%d (Tier%d)! hits=%d, damage=%.0f, facing=%s" % [level, tier, result.hits, result.damage, ctx.facing])
	
	# 简单视觉反馈：屏幕闪烁
	if result.hits > 0:
		_flash_screen()
	
	# 视觉特效
	SkillVfx.shield_bash(get_tree().root.get_child(0), ctx.origin, ctx.facing, 3.0 * (1.5 if result.tier >= 5 else 1.0))
	
	# 音效
	var sfx_mgr: Script = preload("res://core/audio/sfx_manager.gd")
	sfx_mgr.play_whoosh(get_tree().current_scene)


## 范围脉冲：对 attack_range 内所有存活敌人造成伤害（铁卫近战范围定位的灰盒版）。
## 返回命中数量，便于测试。
func auto_attack() -> int:
	var hits: int = 0
	var range_sq: float = attack_range * attack_range
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D) or not enemy.is_alive:
			continue
		var offset: Vector3 = (enemy as Node3D).global_position - global_position
		offset.y = 0.0
		if offset.length_squared() <= range_sq:
			enemy.take_damage(attack_damage)
			hits += 1
	
	if hits > 0:
		print("[PlayerM1] Auto-attack hit %d enemies" % hits)
	
	return hits


func take_damage(amount: float, source_id: int) -> void:
	current_health -= amount
	
	if current_health <= 0.0:
		die()


func die() -> void:
	print("[PlayerM1] died")
	var game_session: Node = get_tree().root.find_child("GameSession", true, false)
	if game_session and game_session.has_method("end_game"):
		game_session.end_game("player_died")


func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)


func get_health() -> float:
	return current_health


func get_max_health() -> float:
	return max_health


## 升级选择界面尚未实现，暂时按固定映射让盾击随玩家等级成长。
func _on_level_up(new_level: int) -> void:
	if shield_bash == null:
		return
	var target: int = ShieldBash.level_for_player_level(new_level)
	if target != shield_bash.level:
		shield_bash.set_level(target)
		print("[PlayerM1] Shield Bash -> Lv%d (Tier%d)" % [shield_bash.level, shield_bash.get_tier()])


func _flash_screen() -> void:
	# 创建全屏白色闪光
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.3)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 添加到场景根UI
	var ui: CanvasLayer = get_tree().root.find_child("UI", true, false)
	if ui:
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(flash)
		
		# 0.1秒后淡出并删除
		var tween: Tween = create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.15)
		tween.tween_callback(flash.queue_free)
