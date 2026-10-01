class_name CharacterStats extends RefCounted
## 铁卫的战斗属性：生命、护盾、怒气、格挡，以及被动模块和装备带来的规则修改。
## 纯逻辑：由玩家节点持有并每帧 tick；便于单元测试和日后主机权威结算。

const BLOCK_CHANCE: float = 0.15
const RAGE_MAX: float = 100.0
const RAGE_PER_HIT_TAKEN: float = 8.0
const RAGE_PER_HIT_DEALT: float = 1.5
const RAGE_DECAY: float = 3.0  # 每秒
const REVENGE_DURATION: float = 5.0
const SPIKED_SHIELD_DAMAGE: float = 60.0
const LEECH_RATIO: float = 0.15
const BASE_DODGE_COOLDOWN: float = 3.0
const MAX_SHIELD: float = 200.0
const HEALTH_REGEN: float = 4.0  # 每秒
const SHIELD_CORE_INTERVAL: float = 4.0
const SHIELD_CORE_AMOUNT: float = 25.0

## 格挡率（天赋「堡垒」会提高）
var block_chance: float = BLOCK_CHANCE
var max_health: float = 1000.0
var health: float = 1000.0
var shield: float = 0.0
var rage: float = 0.0
var passives: Dictionary = {}   # passive_id -> true
var equipment: Dictionary = {}  # equipment_id -> true
var revenge_remaining: float = 0.0
var aura_remaining: float = 0.0
var aura_reflect: float = 0.0
var aura_reduction: float = 0.0
## 祝福（牧师）：限时伤害与攻速加成。
var blessing_remaining: float = 0.0
var blessing_bonus: float = 0.0
## 天赋：伤害倍率、每秒回复加成（开局由 Talents.apply 写入）。
var talent_damage_mult: float = 1.0
var regen_bonus: float = 0.0
## 装备：护盾核心计时、回光返照是否已用掉
var shield_core_timer: float = 0.0
var second_wind_used: bool = false


## 回光返照：若本次伤害会致死且还没用过，保住 1 点生命并回复 30%。返回是否触发。
func try_second_wind() -> bool:
	if health > 0.0 or second_wind_used or not has_equipment("second_wind"):
		return false
	second_wind_used = true
	health = max_health * 0.3
	return true


func _init(p_max_health: float = 1000.0) -> void:
	max_health = p_max_health
	health = p_max_health


func has_passive(id: String) -> bool:
	return passives.has(id)


func has_equipment(id: String) -> bool:
	return equipment.has(id)


func add_passive(id: String) -> void:
	passives[id] = true


func add_equipment(id: String) -> void:
	equipment[id] = true


func is_alive() -> bool:
	return health > 0.0


func health_ratio() -> float:
	return health / max_health


## 输出伤害倍率：狂怒强化（怒气>80 +30%）、狂战头盔（生命<50% +40%），乘算。
func damage_multiplier() -> float:
	var mult: float = talent_damage_mult
	if blessing_remaining > 0.0:
		mult *= 1.0 + blessing_bonus
	if has_passive("rage_damage") and rage > 80.0:
		mult *= 1.3
	if has_equipment("berserker_helm") and health_ratio() < 0.5:
		mult *= 1.4
	if has_equipment("war_drum"):
		mult *= 1.15
	if has_equipment("glass_cannon"):
		mult *= 1.3
	if has_equipment("arcane_tome"):
		mult *= 1.2
	return mult


## 自动攻击间隔倍率：复仇（受击后 5 秒攻速 +20%）、祝福（攻速 +bonus）。
func attack_interval_multiplier() -> float:
	var speed: float = 1.2 if has_passive("revenge") and revenge_remaining > 0.0 else 1.0
	if blessing_remaining > 0.0:
		speed *= 1.0 + blessing_bonus
	if has_equipment("swift_gloves"):
		speed *= 1.25  # 间隔 -20% = 速度 ×1.25
	return 1.0 / speed


func set_blessing(duration: float, bonus: float) -> void:
	blessing_remaining = maxf(blessing_remaining, duration)
	blessing_bonus = maxf(blessing_bonus, bonus)


## 聚怪（嘲讽）范围倍率：集结 +30%。
func taunt_radius_multiplier() -> float:
	return 1.3 if has_passive("rally") else 1.0


## 受到伤害倍率：铁皮 -10%。
func damage_taken_multiplier() -> float:
	var mult: float = 1.0
	if has_equipment("iron_skin"):
		mult *= 0.9
	if has_equipment("fortress_plate"):
		mult *= 1.0 - 0.02 * floorf(rage / 10.0)
	return mult


## 闪避冷却：肾上腺注射 -30%。
func dodge_cooldown() -> float:
	return BASE_DODGE_COOLDOWN * (0.7 if has_equipment("adrenaline_injector") else 1.0)


func set_aura(duration: float, reflect: float, reduction: float) -> void:
	aura_remaining = duration
	aura_reflect = reflect
	aura_reduction = reduction


func add_shield(amount: float) -> void:
	shield = minf(MAX_SHIELD, shield + amount)


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)


## 结算一次受到的伤害。block_roll 取 [0,1)，小于格挡率则格挡（便于测试时注入）。
## 返回 {taken, blocked, reflect}：reflect 为应反弹给攻击者的伤害。
func receive_damage(amount: float, block_roll: float) -> Dictionary:
	var result: Dictionary = {"taken": 0.0, "blocked": false, "reflect": 0.0}
	if not is_alive():
		return result
	amount *= damage_taken_multiplier()
	if block_roll < block_chance:
		result.blocked = true
		if has_passive("block_recovery"):
			add_shield(10.0)
		if has_equipment("spiked_shield"):
			result.reflect += SPIKED_SHIELD_DAMAGE
		if has_equipment("vital_bulwark"):
			heal(max_health * 0.03)
		rage = minf(RAGE_MAX, rage + RAGE_PER_HIT_TAKEN)
		revenge_remaining = REVENGE_DURATION
		return result
	var incoming: float = amount
	if aura_remaining > 0.0:
		result.reflect += amount * aura_reflect
		incoming *= 1.0 - aura_reduction
	if has_equipment("thorn_mail"):
		result.reflect += amount * 0.25
	var absorbed: float = minf(shield, incoming)
	shield -= absorbed
	incoming -= absorbed
	health = maxf(0.0, health - incoming)
	result.taken = incoming
	rage = minf(RAGE_MAX, rage + RAGE_PER_HIT_TAKEN)
	revenge_remaining = REVENGE_DURATION
	return result


## 造成伤害后的回调（命中数、总伤害）：积累怒气（狂怒印记 +50%）；汲取手套吸血 15%。返回治疗量。
func on_damage_dealt(hits: int, total_damage: float, melee: bool) -> float:
	var rage_gain: float = hits * RAGE_PER_HIT_DEALT
	if has_equipment("rage_sigil"):
		rage_gain *= 1.5
	rage = minf(RAGE_MAX, rage + rage_gain)
	if melee and has_equipment("leech_gauntlet") and total_damage > 0.0:
		var amount: float = total_damage * LEECH_RATIO
		var before: float = health
		heal(amount)
		return health - before
	return 0.0


## 击杀回调：战意徽章获得怒气。
func on_kill() -> void:
	if has_equipment("battle_badge"):
		rage = minf(RAGE_MAX, rage + 15.0)


func tick(delta: float) -> void:
	if is_alive():
		heal((HEALTH_REGEN + regen_bonus) * delta)
		if has_equipment("regen_ring"):
			heal(6.0 * delta)
		if has_equipment("shield_core"):
			shield_core_timer -= delta
			if shield_core_timer <= 0.0:
				shield_core_timer = SHIELD_CORE_INTERVAL
				add_shield(SHIELD_CORE_AMOUNT)
	rage = maxf(0.0, rage - RAGE_DECAY * delta)
	revenge_remaining = maxf(0.0, revenge_remaining - delta)
	aura_remaining = maxf(0.0, aura_remaining - delta)
	blessing_remaining = maxf(0.0, blessing_remaining - delta)
	if blessing_remaining <= 0.0:
		blessing_bonus = 0.0
