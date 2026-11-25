# T64 精灵管线端到端验证件（不是正式兵种）

`undead_e2e` 是 T45 批量生产前的冒烟测试：用现有 `chibi_body` 模板派生一个骷髅头、短剑、小圆盾的亡魂占位，走完
规格 → 建模 → 15 骨骼 / 11 动作 → 69 帧 UV 图集 → 部位贴图 → JSON → `validate.py` → 游戏着色器截图。

## 命令

```sh
# 完整 e2e：构建 + 单资产验收 + 固定验收集 + 窗口截图（需要桌面会话）
python3 tools/blender/e2e_pipeline.py --godot

# 只重建产物
blender -b --factory-startup --python-exit-code 1 \
  -P tools/blender/render_sprites.py -- \
  --spec assets/sprites/e2e/undead_grunt.yml --output assets/sprites/e2e --supersample 8

# 固定验收（同时检查 T06、k2_shieldman、本验证件）
blender -b --factory-startup --python-exit-code 1 -P tools/blender/validate.py

# 只截游戏内验证图（窗口会话；headless 无渲染视口，脚本会以退出码 2 明确拒绝）
godot --path . -s assets/sprites/e2e/capture.gd
```

## 产物

| 文件 | 内容 |
| --- | --- |
| `undead_e2e_uv.png` / `.json` | 512×576、64×64 格、8 列、69 帧；11 动作表 |
| `undead_e2e_parts.png` | 512×512 部位贴图；本件只有 1 个外观，其余槽位重复 |
| `undead_e2e_preview_*.png` | UV 换色预览、walk 单行、UV/明暗 |
| `undead_e2e_view_*.png` | 普通着色多视角（front/side/back/equipped） |
| `pipeline_timing.json` | 每步命令、耗时、退出码；最近一次约 49s（build 约 24s / 验收集 约 7s / Godot 约 14s，见 JSON） |
| `../../shots/t64/e2e_contact_sheet.png` | 用 `shaders/unit.gdshader` 加载图集的 14 帧接触表（shots/ 不入库） |
| `../../shots/t64/e2e_game_angle.png` | 30° 俯角、正交镜头的游戏视角三连图（shots/ 不入库） |

## 边界

- 只改 `tools/blender/`、`assets/sprites/e2e/`、`reports/agents/`、`shots/`；没有改 `scripts/`、`shaders/`、`data/`。
- 没有新增骨骼、动作、图集字段或运行时字段；盾/剑是 `Shieldman` 配方的缩比参数。
- `validate.py` 的 spec 分支增加了探针名和剑障碍物名，默认流程现在也验证本件；T06 和 k2_shieldman 仍通过。
- 骷髅的侧视眼窝是额外扁盘片，因为共享头部 UV 的正面绘制在纯侧视下几乎不可见。这是 T45 前要修的管线问题，不是
  可复用的通用方案。
