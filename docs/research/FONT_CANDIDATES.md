# T56 · 字体候选与嵌入许可

核对日期：2026-11-25。以下都选择可随商业游戏分发的 SIL Open Font License 1.1（OFL）版本；授权事实与选型建议分开列出。表中“可嵌入”指遵守对应许可证、随包附版权和许可全文后，将字库作为游戏资源打包分发，不仅指生成图片。

## 中文标题：宋体 / 楷体系

| 候选 | 字重数量 | 游戏嵌入 | 授权条款原文 | 项目与字重依据 | 建议与边界 |
| --- | --- | --- | --- | --- | --- |
| 思源宋体 Source Han Serif CN | 7：ExtraLight / Light / Regular / Medium / SemiBold / Bold / Heavy；另有可变版 | 可以，OFL 1.1 | [Adobe LICENSE.txt](https://github.com/adobe-fonts/source-han-serif/blob/master/LICENSE.txt) | [官方发行与七字重说明](https://github.com/adobe-fonts/source-han-serif/tree/release) | 【议】首选基准。大标题有笔锋，正式、稳定；原型使用 Regular 子集。简体选 CN/SC，避免误拿日文字形。 |
| 霞鹜文楷 LXGW WenKai | 3：Light / Regular / Medium | 可以，OFL 1.1 | [作者 OFL.txt](https://github.com/lxgw/LxgwWenKai/blob/main/OFL.txt) | [作者说明](https://github.com/lxgw/LxgwWenKai)：仿宋与楷体笔意，三字重 | 【议】适合角色名、短句和更有人情味的标题。原型使用轻便版 Regular 子集，缺字覆盖不能等同完整版。 |
| 芫荽 Iansui | 1：Regular | 可以，OFL 1.1；作者明确允许商用和随软件捆绑销售 | [作者 OFL.txt](https://github.com/ButTaiwan/iansui/blob/main/OFL.txt) | [作者说明及授权解释](https://github.com/ButTaiwan/iansui)、[官方 Regular 元数据](https://github.com/google/fonts/blob/main/ofl/iansui/METADATA.pb) | 【议】繁体中文版本的楷体系候选。按台湾标准调整，覆盖并非完整 Big5；不宜直接作为简体游戏的全量字库。 |

## 中文正文：黑体

| 候选 | 字重数量 | 游戏嵌入 | 授权条款原文 | 项目与字重依据 | 建议与边界 |
| --- | --- | --- | --- | --- | --- |
| 思源黑体 Source Han Sans CN | 7：ExtraLight / Light / Normal / Regular / Medium / Bold / Heavy；另有可变版 | 可以，OFL 1.1 | [Adobe LICENSE.txt](https://github.com/adobe-fonts/source-han-sans/blob/master/LICENSE.txt) | [官方发行及七字重](https://github.com/adobe-fonts/source-han-sans/tree/release) | 【议】正文首选基准，Regular/Normal 可读性好。原型使用已在本机缓存的轻量衍生版，已改 family 名为 T56 Sans；不是完整官方字库。 |
| 更纱黑体 Sarasa Gothic SC / UI SC | 5：ExtraLight / Light / Regular / SemiBold / Bold；各有 Italic，共 10 样式 | 可以，OFL 1.1 | [作者 LICENSE](https://github.com/be5invis/Sarasa-Gothic/blob/master/LICENSE) | [构建配置 styleOrder](https://github.com/be5invis/Sarasa-Gothic/blob/master/config.json)、[家族说明](https://github.com/be5invis/Sarasa-Gothic) | 【议】适合数字、快捷键较多的界面。正文优先 Gothic/UI，Mono/Term 的等宽拉丁是另一个用途，不默认混用。 |

## 拉丁标签：窄体衬线大写

| 候选 | 字重数量 | 游戏嵌入 | 授权条款原文 | 窄体与字重依据 | 建议与边界 |
| --- | --- | --- | --- | --- | --- |
| Roboto Serif，`wdth=75` | 可变 `wght=100–900`，9 个常用标称字重；正体/斜体各一可变字库 | 可以，OFL 1.1 | [OFL.txt](https://github.com/google/fonts/blob/main/ofl/robotoserif/OFL.txt) | [官方元数据](https://github.com/google/fonts/blob/main/ofl/robotoserif/METADATA.pb)：宽度轴 50–150，字重轴 100–900 | 【议】可控性最强。建议 500–600 字重，宽度 75，字距略放开；使用字体宽度轴，不把位图横向压缩。 |
| Instrument Serif | 1：Regular 400；正体/Italic 共 2 样式 | 可以，OFL 1.1 | [OFL.txt](https://github.com/google/fonts/blob/main/ofl/instrumentserif/OFL.txt) | [官方说明：condensed display](https://github.com/google/fonts/blob/main/ofl/instrumentserif/DESCRIPTION.en_us.html)、[元数据](https://github.com/google/fonts/blob/main/ofl/instrumentserif/METADATA.pb) | 【议】适合结局名等大号短标题，笔画反差明显；小字号不作正文。没有可变宽度轴，属于原生窄体设计。 |

## OFL 的具体分发条件

各表格直接链接该字体的许可全文。OFL 明确允许将字体与软件捆绑、嵌入并随软件销售；需要保留版权声明和许可全文，不能把字体单独出售。修改版字体仍遵循 OFL；如果版权声明指定了 Reserved Font Name，修改字体的 family 名称需要避开保留名。游戏自身代码和内容不因此被要求改为 OFL。依据：[OFL 官方全文](https://openfontlicense.org/open-font-license-official-text/)及各候选原始许可。

霞鹜文楷当前许可另附“仅为 Web 交付而子集化或转格式”可保留原名的额外许可。游戏嵌入不据此套用 Web 例外；原型的文楷子集已经使用 **Veil Manuscript** 内部名称，保留作者与 Klee 的版权声明，继续遵循 OFL 基本条款。[作者原文](https://github.com/lxgw/LxgwWenKai/blob/main/OFL.txt)

## 原型内可比较的两套组合

按 F 在完全相同的画面、时间点切换，字号只用 18 / 24 / 46 px；一屏只有两种字库，不额外叠加拉丁候选。

| 组合 | 标题与名牌 | 正文 | 用途 |
| --- | --- | --- | --- |
| A（默认） | 思源宋体 CN Regular 的 Veil Antiqua 子集 | 思源黑体衍生 T56 Sans | 【议】基准：较正式的标题与安静的正文 |
| B | 霞鹜文楷轻便版 v1.530 Regular 的 Veil Manuscript 子集 | 同 A | 【议】对照笔意与角色感，重点看名牌和短标题 |

三份字库均复制到 `proto/ui_motion/fonts/` 并附许可，完全离线可运行。标题的历史子集在本机已有缓存；本文没有将它们称为原始全量官方发行包。正文子集的家族/完整名/PostScript 名已统一改为 **T56 Sans**，保留原版权和 OFL，重算 sfnt 表校验及总校验。来源、修改范围与 SHA-256 见 [NOTICE.md](../../proto/ui_motion/fonts/NOTICE.md)。

**验证事实**：Godot 已成功加载 Veil Antiqua、Veil Manuscript、T56 Sans，关键用字自检通过。尚未在沙箱中完成窗口截图和实际字形视觉比较，因此没有把 A/B 之一定为最终字体。全量剧情、繁简版本和生僻人名在生产选型时应换用完整字库或按项目字表重新生成子集，并检查每个实际用字。
