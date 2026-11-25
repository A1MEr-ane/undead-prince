# 随原型分发的字体

全部字体为 SIL OFL 1.1；对应许可全文与本文件一起保留。这里复用的是本机已有的开源字体缓存，没有使用 Bad North 的字库或系统商业字体。

| 文件 | 实际内部 family | 原始来源与修改 | 许可 |
| --- | --- | --- | --- |
| `veil-antiqua.woff2` | Veil Antiqua | Adobe Source Han Serif CN Regular，历史缓存已保留 GB2312 与原缓存项目用字，转为 WOFF2 并更名；本次未改字形、字重或文件内容。[官方来源](https://github.com/adobe-fonts/source-han-serif/tree/release/SubsetOTF/CN) | `SourceHanSerif-OFL.txt` |
| `veil-manuscript.woff2` | Veil Manuscript | LXGW WenKai Lite v1.530 Regular，历史缓存已保留 GB2312 与原缓存项目用字，转为 WOFF2 并更名；本次未改文件内容。[原始版本](https://github.com/lxgw/LxgwWenKai-Lite/releases/tag/v1.530) | `WenKai-OFL.txt` |
| `t56-sans.ttf` | T56 Sans | 本机缓存的 Source Han Sans Lite for RenPy（字体内版权为 Adobe 2014–2019）。本次只改 name 表中的 family、subfamily、unique、full、PostScript 相关名称为 T56 Sans，重建 sfnt 目录校验与 `head.checkSumAdjustment`，未改 glyph、cmap 或排版表。[上游项目](https://github.com/adobe-fonts/source-han-sans) | `SourceHanSans-LICENSE.txt` |

缓存出处：前两份来自本机既有 `veil-tarot/assets/fonts/`，其 `docs/ASSET_RIGHTS.md` 记录上游、子集和更名；正文来自本机既有 `campus16/game/fonts/SourceHanSansLite.ttf` 及其附带许可。缓存的全量发行版本无法全部从二进制外部记录复原；原型只作排版校准，生产建议从链接中的官方发行重新取完整字库。

SHA-256：

```text
eac4f9de445229e73a8d03963bf518cf706b556f8d68e3998bbcec80e45d0c52  veil-antiqua.woff2
12f4dd227caee7f33f05df31f02951429510722cd69be32a8a66ddcc5e6db71e  veil-manuscript.woff2
a58649ae30e66b691a7c114696ae56fb327b22e912172ebebf42c51406b94de5  t56-sans.ttf
```

字库保留在 OFL 下；禁止单独出售。上述“思源宋体/霞鹜文楷/思源黑体”是来源说明，修改版内部名称均避开保留字体名。第三方版权和许可全文未删减。
