extends RefCounted
## 天赋树：购买花费与上限、返还、属性应用、联机校验。

const TMP: String = "user://test_talents_tmp.json"


class FakePlayer extends RefCounted:
	var stats: CharacterStats = CharacterStats.new(1000.0)
	var ability_system: AbilitySystem = AbilitySystem.new()
	var move_speed: float = 8.0
	var crit_chance: float = 0.2
	var heal_mult: float = 1.0


func _fresh(shards: int) -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	SaveData.reset(TMP)
	SaveData.data().shards = shards


func _cleanup() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	SaveData.reset()


func test_buy_costs_and_caps() -> String:
	_fresh(100)
	var err: String = ""
	# 力量：每级 3 × 等级，5 级共 3+6+9+12+15 = 45
	for i in 5:
		if not Talents.buy("iron_guard", "might"):
			err = "第 %d 级购买失败" % (i + 1)
	if err.is_empty() and Talents.buy("iron_guard", "might"):
		err = "满级后不应再能购买"
	if err.is_empty() and SaveData.shards() != 55:
		err = "应花费 45 碎片，剩余 %d" % SaveData.shards()
	if err.is_empty() and Talents.buy("iron_guard", "lethality"):
		err = "铁卫不能点影行者的专属天赋"
	if err.is_empty() and Talents.rank_of(Talents.ranks("elementalist"), "might") != 0:
		err = "天赋按角色分开"
	_cleanup()
	return err


func test_not_enough_shards_and_refund() -> String:
	_fresh(5)
	var err: String = ""
	if not Talents.buy("cleric", "vitality") or Talents.buy("cleric", "vitality"):
		err = "5 碎片只够体魄 1 级（3），2 级要 6"
	elif Talents.refund("cleric") != 3 or SaveData.shards() != 5:
		err = "重置应返还 3 碎片"
	elif not Talents.ranks("cleric").is_empty():
		err = "重置后应清空加点"
	_cleanup()
	return err


func test_apply_modifies_stats() -> String:
	var p: FakePlayer = FakePlayer.new()
	var ranks: Dictionary = {"vitality": 5, "might": 2, "swiftness": 3, "focus": 5, "regeneration": 2, "lethality": 3}
	Talents.apply(p, "shadow_walker", ranks)
	if not is_equal_approx(p.stats.max_health, 1300.0) or not is_equal_approx(p.stats.health, 1300.0):
		return "体魄 5 级应 +30%% 生命，实际 %.0f" % p.stats.max_health
	if not is_equal_approx(p.stats.damage_multiplier(), 1.1):
		return "力量 2 级伤害 +10%%，实际 %.2f" % p.stats.damage_multiplier()
	if not is_equal_approx(p.move_speed, 8.0 * 1.12) or not is_equal_approx(p.ability_system.cooldown_mult, 0.8):
		return "迅捷 +12% 移速、专注 -20% 冷却"
	if not is_equal_approx(p.crit_chance, 0.32) or not is_equal_approx(p.stats.regen_bonus, 3.0):
		return "致命 +12% 暴击、再生 +3/秒"
	var ig: FakePlayer = FakePlayer.new()
	Talents.apply(ig, "iron_guard", {"fortress": 3})
	if not is_equal_approx(ig.stats.block_chance, CharacterStats.BLOCK_CHANCE + 0.12):
		return "堡垒 3 级格挡率 +12%"
	return ""


func test_cooldown_mult_applied_on_cast() -> String:
	var a: AbilitySystem = AbilitySystem.new()
	a.cooldown_mult = 0.8
	a.add_skill(Smite.new())
	a.cast("smite", SkillContext.new())
	if not is_equal_approx(a.get_cooldown_remaining("smite"), 3.0 * 0.8):
		return "冷却应乘天赋倍率，实际 %.2f" % a.get_cooldown_remaining("smite")
	return ""


func test_sanitize_clamps_client_values() -> String:
	var s: Dictionary = Talents.sanitize("iron_guard", {"might": 99, "lethality": 3, "bogus": 1, "focus": -2})
	if s.get("might") != 5 or s.has("lethality") or s.has("bogus") or s.get("focus") != 0:
		return "主机应把客户端的天赋按上限裁剪并丢弃无效项：%s" % s
	return ""
