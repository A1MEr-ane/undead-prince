# T80 行为场景测试 B01–B12

这些测试只搭场景、读状态、下断言，不修改 `proto/siege/*.gd` 的行为代码。每个场景是一个独立脚本，默认使用正式地图和参数，按场景需要摆单位、开门/破墙、开关 phase_b。

## 运行

```sh
# 全部 12 个场景；逐条打印 PASS / FAIL 和原因；默认退出码 0
tools/verify/proto_behavior.sh --all

# 单个场景
tools/verify/proto_behavior.sh --scenario=B01

# 多个场景
tools/verify/proto_behavior.sh --scenario=B02,B03,B12

# 有 FAIL 时返回 1，便于 CI / Codex 自测
tools/verify/proto_behavior.sh --all --strict

# 开窗口回放（一次一个场景；需要桌面会话）
tools/verify/proto_behavior.sh --scenario=B01 --watch
tools/verify/proto_behavior.sh --scenario=B04 --watch --speed=8
```

直接调用 Godot 等价于：

```sh
godot --headless --path . --script res://proto/siege/tests/behavior_runner.gd -- --scenario=B01
godot --path . --script res://proto/siege/tests/behavior_runner.gd -- --scenario=B01 --watch
```

`--watch` 复用 `proto/siege/siege_view.gd` 的镜头、HUD、墙门和单位表现；模拟仍由测试脚本驱动，不启动正式场景的自动策略。

## 场景

| 编号 | 文件 | 场景 |
|---|---|---|
| B01 | `scenarios/b01_no_standing.gd` | 1 亡魂 vs 1 盾兵，开阔地 |
| B02 | `scenarios/b02_gate_crowd.gd` | 10 亡魂挤过城门，侧路可达 |
| B03 | `scenarios/b03_closed_wall.gd` | 城门关闭、墙未破 |
| B04 | `scenarios/b04_giant_breach.gd` | 巨人破 `wall_west` 后通行 |
| B05 | `scenarios/b05_assassin_highland.gd` | 刺客走崖壁杀高地弓兵 |
| B06 | `scenarios/b06_dispatch_ratio.gd` | 2 / 8 名亡魂佯攻，比较派兵数 |
| B07 | `scenarios/b07_mission_lock.gd` | 威胁搬离/搬回，检查任务锁定 |
| B08 | `scenarios/b08_archer_melee.gd` | 弓兵被贴身 |
| B09 | `scenarios/b09_rally.gd` | 集结转向与指令结束恢复 |
| B10 | `scenarios/b10_retreat_route.gd` | 攻占主堡后的撤退与城门 |
| B11 | `scenarios/b11_cave_permission.gd` | 山洞权限、容量排队 |
| B12 | `scenarios/b12_clash_parry.gd` | 拼刀进度差、招架、正面无招架 |

## 测试夹具

- `behavior_scenario.gd` 只调用 `siege.gd` 已有的 `spawn()`、`terrain.change()`、`director.tick()` 等入口；没有为测试新增原型 API。
- B01/B08 提高单位 HP，B05/B06/B07 也调整了少量实例 HP 或伤害，目的是让要观察的行为持续到采样窗口，不改变正式参数文件。
- B12 直接构造 `brain.modify_attack()` 的调用，验证规格第 7 节的拼刀/招架条件；这是目前没有单独战斗事件接口时最直接的读状态方式。
