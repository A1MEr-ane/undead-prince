# Claude → Codex production handoff / 美术与开发交接

Read `shared/CANON-COMPACT.md` and `shared/ART-PRODUCTION-QUEUE.json` first. Load only the source files needed for the current task, not the archive or other character boards. / 先读精简基准与任务JSON；只加载当前任务需要的资料，不加载旧稿或其他人物板。

Claude owns art direction, task dependencies and approval decisions; Codex executes isolated image tasks, map UI implementation, and file handling. Reuse subscription capacity according to actual quality and throughput. No claim that the handoff has run anything remotely. / Claude负责美术方向、任务依赖与审批；Codex执行隔离生图、地图UI与文件处理。按实际质量和吞吐使用订阅额度；本交接未实际调用外部模型。

1. Start with the missing undead Matilda, Oswin, Pip; run independent one-subject jobs. In parallel review the existing Edmund, Eleanor, Ferryman and Bernard concept references. / 先补玛蒂尔达、奥斯温、皮普，独立单角色任务；并行检查现有王子、女王、渡魂人与伯纳德概念。
2. Finish royal parents and councillors. Produce one independent hero and one matching front/side/back sheet per visual variant, with props separately. / 完成王室父母与议员；每个视觉版本独立主立绘、正侧背三视图、道具另列。
3. Review seven regional kits, then block out priority sites. Map art can proceed in parallel, but preserve 39 node IDs, 75 edges and current-state logic. / 审核七地区模块，优先灰盒关键地点；地图可并行，但保留39节点、75边及状态逻辑。
4. Render story scenes and endings only after dependent character and environment art is approved. Family and story illustrations can intentionally contain multiple people; modelling sheets cannot. / 相关人物及环境获批后再生成叙事插画及结局图；家庭和故事插画允许多人，建模图不允许。
5. Record `pending`, `in_review`, `accepted`, `rejected` in a separate result register. Store each output under its stable task ID and retain the input reference hash, model/tool and rejection reason. Never edit core lore from an image's incidental text. / 独立记录任务状态与输入哈希、工具及退回理由；按任务ID存文件，不从生成图的偶然文字修改世界观。
6. Hand approved model references to the Blender pipeline. Compare rendered model orthographic views against the approved reference, not merely the generated sheet labels. / 验收后移交Blender；对比模型正交渲染与获批参考，不只检查图内标签。

Do not mark a task complete solely because an image exists. Character decisions can run concurrently but must share the approved style and heraldry. / 不因图像存在就标记完成；人物任务可并行，但统一获批风格及纹章。
