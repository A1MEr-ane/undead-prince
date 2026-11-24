extends RefCounted
## 以有向图最短距离计算地点固有难度；本轮实际走了多少站不会改写深度。

var config: Dictionary = {}
var sites: Dictionary = {}
var depth: Dictionary = {}
var remaining: Dictionary = {}


func configure(chart_sites: Dictionary, edges: Array, rules: Dictionary) -> void:
	sites = chart_sites
	config = rules
	depth = _distances("bay", edges, false)
	remaining = _distances("sunhold", edges, true)


func _distances(start: String, edges: Array, reverse: bool) -> Dictionary:
	var result := {start: 0}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: String = str(queue.pop_front())
		for edge in edges:
			var source: String = str(edge[1] if reverse else edge[0])
			var target: String = str(edge[0] if reverse else edge[1])
			if source == current and not result.has(target):
				result[target] = int(result[current]) + 1
				queue.append(target)
	return result


func describe(id: String, enemy_memory: Dictionary = {}) -> Dictionary:
	var site: Dictionary = sites[id]
	var distance := int(depth.get(id, 0))
	var full_route := distance + int(remaining.get(id, 0))
	var depth_score := clampf(float(distance) / float(config.depth_full_score_at), 0, 1) * float(config.depth_max_score)
	var shortcut_score := clampf((float(config.long_route_steps) - full_route) /
		(float(config.long_route_steps) - float(config.shortest_route_steps)), 0, 1) * float(config.shortcut_max_score)
	var adjustment := float(site.get("difficulty_adjustment", 0))
	var boss: bool = site.type == "boss"
	var threshold := int(config.memory.boss_wins if boss else config.memory.normal_wins)
	var memory := int(config.memory.tier_reduction) if int(enemy_memory.get(id, 0)) >= threshold else 0
	var base := int(config.maximum_tier) if boss else roundi(depth_score + shortcut_score + adjustment)
	return {"depth_score": depth_score, "shortcut_score": shortcut_score,
		"adjustment": adjustment, "full_route_steps": full_route,
		"base_tier": clampi(base, int(config.minimum_tier), int(config.maximum_tier)),
		"memory_reduction": memory, "tier": clampi(base - memory, int(config.minimum_tier), int(config.maximum_tier))}


func tier(id: String, enemy_memory: Dictionary = {}) -> int:
	return int(describe(id, enemy_memory).tier)


func tier_data(value: int) -> Dictionary:
	return config.tiers[clampi(value, int(config.minimum_tier), int(config.maximum_tier)) - 1]


func win_chance(value: int, reward_count: int) -> float:
	return minf(float(tier_data(value).stub_win_chance) +
		maxi(reward_count, 0) * float(config.stub_reward_power.per_reward),
		float(config.stub_reward_power.maximum_win_chance))
