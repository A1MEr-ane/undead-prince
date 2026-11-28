# 灰潮外岛 · 海岸登陆点

《亡者归航》基础单局 v1 的局内风格样张。固定战区里，亡灵从外岛码头登岸，在路上撞见盾兵和骑兵。巨人在砸城门，刺客贴右侧高地绕行，弓兵守住崖边和塔顶。

在仓库根目录运行。建议使用 16:9 窗口，1280 × 720 是本样张的小兵阅读尺寸。

```sh
godot --path . --rendering-method gl_compatibility attempts/single_battle/style_frame/main.tscn
```

时段滑杆从夜晚拖到破晓。按 **H** 隐藏或恢复控件。战区内的演出循环播放。

| 参数 | 用途 |
|---|---|
| `--time=0..1` | 设置初始时段。0 夜晚，0.27 午夜，0.70 黎明前，1 破晓。 |
| `--capture` | 按上述四个时段拍同一演出瞬间，隐藏控件，写入四张 PNG 后退出。需要图形会话。 |

```sh
godot --path . --rendering-method gl_compatibility attempts/single_battle/style_frame/main.tscn -- --time=0.70
godot --path . --rendering-method gl_compatibility --resolution 1280x720 attempts/single_battle/style_frame/main.tscn -- --capture
```

截图路径为 `shots/t84/{01-night,02-midnight,03-before-dawn,04-daybreak}.png`。拍照时会按四档时段覆盖 `--time`。演出中冥火弹先命中后眩晕，巨人扬尘和碎石独立循环。

`coast.gd` 里的网格模块负责海岸、码头、道路、高地和建筑。地形暖冷随时段染色，笔触在世界坐标中采样。临时兵种与特效绘在 `silhouettes.svg`，运行时切成图块，按固定机位摆放。普通步兵以 720 像素画高下约 48 像素的人物高度为目标，骑兵与巨人更大。
