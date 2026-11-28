---
id: T84
title: 局内风格样张（G4）：一个战区按目标画风在引擎里做出来
owner: codex
status: done
branch: codex/t84-style-frame
worktree: ../亡魂王子-t84
images: [/Users/cyy/Projects/亡魂王子/art/style/battle_mock.png, /Users/cyy/Projects/亡魂王子/art/units/chibi_lineup.png]
allowed: [attempts/single_battle/style_frame/, tools/blender/style_frame/]
forbidden: [scripts/, proto/, shaders/, data/, docs/, tasks/, art/, assets/sprites/k2_*, project.godot]
verify: test -f attempts/single_battle/style_frame/README.md
retry_limit: 3
max_minutes: 300
escalate_if: [需要改 allowed 以外的文件, 目标画风在当前渲染方案下做不到]
---

## 目标
用户已批准基础单局 v1（`docs/single-battle-v1.md`）。动工前先做**局内风格样张**：在 Godot 里把**一个战区**做成目标画风，给用户判断局内美术方向。这一张是给人看的样张，不需要玩法逻辑，只需要一个可以播放的静态场面加少量动作。

## 先读
- `docs/single-battle-v1.md` 第 4 节（美术范围）
- `docs/art-style.md` 第 4 节（局内：墨线外轮廓、两档平涂、阵营边光、3–4 块色、暗调地形、冥火最亮）
- `docs/art-direction.md`（小兵 2.3 头身）
- `docs/badnorth-art-spec.md`（现有的天光体积、地形着色器，能复用的就复用）
- 附图：附图 1 是局内风格的目标（构图和气质参考，镜头按我们的固定视角来），附图 2 是兵种的 Q 版形象

## 要做（全部放在 `attempts/single_battle/style_frame/`）
1. **一个战区**：灰潮外岛海岸登陆点。包括：
   - 海岸、礁石、浅滩、木码头
   - 一段石墙和一座城门、一座塔、两三间民房
   - 一条大路、一段高地
   地形和建筑用简单的 3D 模块（Blender 或 Godot 里建都可以），做成手绘平涂加墨线轮廓的质感，暗调。
2. **固定视角**：一个手工设定的战区机位，正交，俯角约 30°，参照 `proto/siege/camera/map_camera.json` 的做法。
3. **小兵（临时精灵即可）**：7 个兵种各放几名，摆成交战场面。
   - 亡灵：普通骷髅、暗影刺客、缝合巨人、巫妖。
   - 守军：盾兵、弓兵、骑兵。
   - 可以用现有盾兵精灵改色，或者用程序生成的剪影。
   - 必须体现：墨线外轮廓、两档平涂、阵营边光（亡灵青绿，守军暖金）。
   - 巨人明显更大。
   - 每个兵种在 48 像素高度下能分清。
4. **光照**：夜晚到黎明可以调，滑杆或参数 `--time=0..1`。冥火是夜里最亮的颜色，黎明时天边变白。
5. **特效**（简单版）：冥火弹和眩晕、巨人砸城门的尘土、骷髅骨堆、刺客潜行的半透明。
6. **截图参数** `--capture`：输出 `shots/t84/` 下的夜晚、午夜、黎明前、破晓四张。沙箱里截不了图就写明，Lead 来拍。
7. `README.md`：运行方式和参数说明。

## 交付
报告 `reports/agents/T84.md`，开头用 YAML 摘要；列出用到的技术、和目标画风的差距。用户看了样张以后，再决定精灵管线和地形套件怎么做。
