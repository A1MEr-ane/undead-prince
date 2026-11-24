# B.3 — Lives Between the Returns / 轮回之间的人生

**WORKING — Bilingual narrative and quest design / 暂定·双语人物支线与任务设计**

A.5 and B.2 remain authoritative for the world and biographies. This volume supplies twelve optional arcs (S01–S12) and the recurring Ferryman scenes that touch the canonical main arc. All new incidents and dialogue are original working fiction. No added combat map, new ending bit, or change to the Seal, the oath or the anchor. / A.5与B.2继续作为世界观和人物传记基准。本卷提供十二条人物故事及与正史主线相接的渡魂人场景。新增事件和对白为原创暂定内容。不新增战斗地图、结局变量，不改秘印、军誓或锚点规则。

## Narrative contract / 叙事规则

- A memory flag (`M_`) means Edmund has personally learned a fact; it is not another person's persistent quest progress. Store the first acquired expedition ID as well. A current-run flag (`R_`) means an action, witness, consent or object in this history only. It resets on Return. / 记忆标记代表王子亲历知识，不是其他人永久任务进度，同时记录首次获得轮次。本轮标记代表现世行动、证人、同意或物品，回溯重置。
- A beat may be offered again if its current action matters; ordinary repeat visits use a short callback, not the same full conversation. A beat explicitly marked later-run requires a higher expedition ID. Offer one substantial optional scene per stop, with a journal queue for competing events; do not delay main facts. / 本轮行动仍有意义时可再次提供，普通重访用简短呼应而非重播长对话。明确标注后续轮次的场景必须在更晚出征触发。每站最多一段主要可选场景，其余留日志排队，不延迟主线事实。
- `current_grants` are possible flags, not unconditional rewards. Record a flag only after the described action or evidence actually occurs. A petition submitted for inquiry is not a debt paid; a copied diagram is not a repaired Seal. / 本轮标记是可能结果而非无条件奖励。只有实际发生对应行动或取得证据才写入。提出调查不是还清欠债；复制图纸不是修复秘印。
- Default locus is a post-battle short scene or exploration panel. Anchor scenes happen before departure; capital beats occur at their named main scene. No mandatory extra boss fight or gate. Never require visiting mutually exclusive nodes in the same expedition. / 默认用战后短场景或探索面板。据点出征前，王都对应指定主线场景。无强制新增首领或关卡，不要求同轮访问互斥地点。
- `RETURN_OCCURRED`, `WITNESSED_E05_E08`, `TRUE_RELEASE_CONFIRMED` are aliases to existing A.5 state, not new unlock requirements. K07 and Ferryman recognition are canonical guaranteed events. A side story cannot delay them. / 三个大写状态是A.5既有状态的别名，不增加条件；K07和渡魂人知情确认是正史保底事件，支线不可推迟。
- Ending bits remain the three capital decisions. These arcs may alter testimony, administrative detail, character reactions, optional rewards and epilogue lines, never the set of endings available. Character participation is explicit in the present history. / 结局位仍是王都三次决定。支线可改变证言、行政细节、人物反应、可选奖励及尾声，不能改变结局可用组合。人物参与须在本轮明确发生。

## Reading index / 阅读索引

| ID | Story / 故事 | Earliest act / 最早阶段 | Characters / 人物 | Locations / 地点 |
|---|---|---:|---|---|
| S01 | A Boat for Two / 两人的小船 | 2 | Edmund, Eleanor, Beatrice | The King’s Orchard, Sunhold |
| S02 | The King’s Own Hand / 先王亲笔 | 2 | Aldric, Edmund, Anselm, Oswin | Old Crown Keep, The Drowned Archive, Sunhold |
| S03 | Permission to Object / 准许异议 | 1 | Bernard, Hugh, Edmund | Bellgrave Bay, The Iron Gate, Sunhold |
| S04 | A Hand for Knots / 打绳结的手 | 1 | Matilda, Garran, Oswin | Bellgrave Bay, Broken Oar Harbour |
| S05 | The Error in the Margin / 页边的错误 | 3 | Oswin, Anselm, Matilda | The Drowned Archive, Bellgrave Bay, Sunhold |
| S06 | The Missing Verse / 未唱完的歌 | 1 | Pip, Pip’s mother (name pending), Edmund | Broken Oar Harbour, Lantern Isle, Bellgrave Bay |
| S07 | A Seat in the Boat / 船上的空座 | 1 | The Ferryman, Edmund | Bellgrave Bay, Silent Shoals, Sunhold |
| S08 | The Price of a Passage / 一程船资 | 1 | Roderick, Edmund | The Last Lighthouse, Broken Oar Harbour, Sunhold |
| S09 | A Measure of Grain / 一斗麦子 | 1 | Agnes, Edmund, Eleanor | Miller’s Crossing, The Great Granary, Sunhold |
| S10 | The Names Beneath the Stone / 石碑下的名字 | 2 | Anselm, Oswin, The novice (name pending) | Hollow Graves, The Pale Abbey, Sunhold |
| S11 | The Practice Sword / 练习剑 | 1 | Hugh, Edmund, Bernard | The Iron Gate, Blackwake Yard, Sunhold |
| S12 | The Unopened Petition / 未拆的请愿书 | 2 | Walter, Eleanor, The household clerk (name pending) | Merchant Gate, Sunhold |

---

## S01 — A Boat for Two / 两人的小船

Edmund once believed that the best thing he could do for his sister was win every race before she could lose one. At twenty Eleanor is making decisions of her own, and the boat they repaired as children is still in her possession. The quest is about two siblings learning to speak as adults; it is not an identity test or a key to the throne.

埃德蒙曾以为，保护妹妹就是在她输掉比赛之前替她赢下来。如今二十岁的埃莉诺已经开始自己作决定，那艘兄妹小时候修好的木船仍在她手中。支线讲兄妹如何以成年人的方式相处，不是身份认证任务，也不是夺位钥匙。

### S01_01 · The King’s Orchard / 旧王果园

**Act / 阶段 2 · arrival_or_post_battle**

The abandoned country house contains the old channel and a sketch of the race. Edmund recalls their mother laughing when Eleanor discovered the lead weight in his keel. The memory begins in joy.

废弃的王室庄园仍有旧引水渠和一张竞舟速写。埃德蒙想起妹妹发现船底铅块时母亲的笑声。这段记忆以快乐开始。

> Edmund: She let me win the first three. Or so I have maintained ever since.
>
> 埃德蒙：前三次都是她让我的。至少从那以后，我一直这么说。

**State / 状态:** requires / 前置 `none / 无`; possible grants / 可能记录 `M_S01_RACE`.

### S01_02 · Sunhold / 永昼王城

**Act / 阶段 2 · C05A**

At the Royal Audience, he mentions the race. Eleanor produces the repaired boat, then asks him to listen to a petition rather than make her another promise. She reveals that the council intercepts her letters. No recovered childhood fact substitutes for her present agreement.

王室会面时哥哥提起竞舟。妹妹拿出修好的小船，请他听一份请愿书，而不是再作一个承诺。她告诉他议会截留了自己的信。童年记忆不能代替她当下的同意。

> Eleanor: You always did know how to get a boat moving. Staying to mend it was my part.
>
> 埃莉诺：你总有办法让船开出去。留下来把它修好的人，一直是我。

**State / 状态:** requires / 前置 `M_S01_RACE`; possible grants / 可能记录 `M_S01_WISH, R_S01_TALK`.

### S01_03 · Sunhold / 永昼王城

**Act / 阶段 2 · C05A_before_choice**

On a later expedition, Edmund can request the original petition before the crown decision. Eleanor names a practical priority: recover the right to receive letters without the chancellor. If Edmund claims the Crown she asks for a recognised office; if he renounces, she asks for independent control of her household. The scene occurs in either branch.

后续出征中，埃德蒙可在王权选择前索取请愿书原件。妹妹提出一个实际目标：恢复未经宰相筛选的通信权。哥哥若继位，她要求一个受承认的职务；若放弃主张，她要求独立掌管宫廷。两条路线均可触发。

> Edmund: What would you have me do? / Eleanor: For a start, wait until I have finished speaking.
>
> 埃德蒙：你希望我做什么？／埃莉诺：首先，等我把话说完。

**State / 状态:** requires / 前置 `M_S01_WISH`; possible grants / 可能记录 `R_S01_PETITION`. Later expedition than / 必须晚于事件轮次 `S01_02`.

**Resolution / 收束**

At the Winter Council Eleanor brings her own draft. In the true-ending farewell she places the little boat beside the crown token; she does not promise to remember erased histories. The Prince tells her about one of them if the player wishes. A late player who never visited the orchard still receives the main farewell.

冬政会议上女王带来自己的草案。真结局告别时，她把小船放在王冠信物旁，不会承诺记得被抹去的历史。玩家可让王子讲述其中一轮经历。未去过果园的玩家仍有完整主线告别。

**Illustration brief / 插画任务**

ART_S01: two children racing carved boats in a country garden, warm summer light; reuse B.2 Orchard Race.

ART_S01：乡间花园中两名孩子竞逐木船，暖色夏光；复用B.2果园竞舟。

---

## S02 — The King’s Own Hand / 先王亲笔

Aldric was not party to the murder, but his emergency exception outlived the winter it was meant to address. Edmund must reconcile the father he knew with a ruler who made a consequential choice. The discovery should feel like a historical tragedy, not a surprise villain reveal.

阿尔德里克没有参与谋杀，但他批准的紧急例外比那场寒冬持续得更久。埃德蒙必须把熟悉的父亲与作出沉重决定的君主视为同一个人。这是一场历史悲剧，不是先王突然变成反派。

### S02_01 · Old Crown Keep / 旧王堡

**Act / 阶段 2 · arrival_or_post_battle**

In the old keep, a faded relief records families crossing frozen water to seek food. The old harbour was abandoned after the Great Winter. A plaque shows the first compact as a temporary measure. This is a memory of the kingdom, not proof of the present Seal design.

旧王堡的残损浮雕描绘饥民渡过冰封水面寻粮。大寒冬后旧港被弃。纪念碑记载初始盟约是一项临时措施。这是王国历史，不能证明现行秘印结构。

> Edmund: They built a kingdom here once. They must have thought it would last.
>
> 埃德蒙：他们曾在这里建立王国。当时大概以为它会长存。

**State / 状态:** requires / 前置 `none / 无`; possible grants / 可能记录 `M_S02_WINTER`.

### S02_02 · The Drowned Archive / 沉水藏书阁

**Act / 阶段 3 · arrival_or_post_battle**

A recovered draft bears Aldric’s annotations: the exception applies to condemned souls and is to be reviewed after the thaw. The later review is absent. Oswin distinguishes the signature from the church’s later instructions.

找回的草案有阿尔德里克的批注：例外适用于获罪者灵魂，解冻后须复审。后续没有复审记录。奥斯温区分国王签署的原令与教会之后的指令。

> Oswin: The ink is his, sir. So is the promise in the margin.
>
> 奥斯温：墨迹是他的，殿下。页边的承诺也是。

**State / 状态:** requires / 前置 `M_S02_WINTER`; possible grants / 可能记录 `M_S02_EXCEPTION, R_S02_COPY`.

### S02_03 · Sunhold / 永昼王城

**Act / 阶段 3 · C05D_before_council**

Before the Winter Council, the Prince can ask for the royal register by its date and have the original read into the proceedings. If the copy has not been recovered this run, the clerks fetch their own surviving record; the main archive remains intact. The ruler can acknowledge the father’s role publicly or reserve the matter for inquiry.

冬政会议前，王子可按日期索取王室登记册，将原令读入会议记录。本轮未取得抄本时，可由宫廷文书调取现存原件；主档案不受影响。君主可公开承认先王责任，或交由后续调查。

> Eleanor: I would rather know what he signed. I am tired of being told what he meant.
>
> 埃莉诺：我宁愿知道他签了什么。我已经听够别人替他解释本意。

**State / 状态:** requires / 前置 `M_S02_EXCEPTION`; possible grants / 可能记录 `R_S02_PUBLIC`.

**Resolution / 收束**

Preserving the Day leaves the exception in force unless explicitly amended; ending it releases only surviving captives. The king is dead in every run and never appears as an active ghost. His portrait can remain in the hall even after public acknowledgement.

延续永昼时例外仍然有效，除非明确修订；终止只能释放尚存囚魂。国王每轮均已死亡，不会成为活跃亡魂。公开承认责任后，大厅仍可保留他的画像。

**Illustration brief / 插画任务**

ART_S02: the empty old royal harbour under snow; a small archival vignette of Aldric signing a winter warrant.

ART_S02：雪下废弃旧王港；阿尔德里克签署寒冬文书的小幅档案插图。

---

## S03 — Permission to Object / 准许异议

Bernard has always been a sailor before a courtier. He loves the company and wants to stay. His problem is that he once treated a flying standard as proof that an order must still be obeyed. Hugh, his former superior, provides a painful mirror.

伯纳德首先是水手，其次才是宫廷近卫。他热爱军团，也希望留下。他的问题在于曾把尚未降下的军旗视为必须继续服从的依据。曾经的长官休让他看到自身选择的另一面。

### S03_01 · Bellgrave Bay / 沉钟湾

**Act / 阶段 1 · anchor_conversation**

Bernard complains that the new crew has no proper watch bill. He asks for the captain’s log to be recovered; he would like to know where the small boats were when the flagship went down.

伯纳德抱怨新军团没有正式值更表，请求找回舰长日志，想知道旗舰沉没时小艇在哪里。

> Bernard: I can put a skeleton on watch, sir. Getting him to report at the right hour is another matter.
>
> 伯纳德：让骷髅值更倒是不难，殿下。让他准点报到就是另一回事了。

**State / 状态:** requires / 前置 `none / 无`; possible grants / 可能记录 `M_S03_LOG`.

### S03_02 · The Iron Gate / 锁海之门

**Act / 阶段 1 · arrival_or_post_battle**

After the confrontation, Bernard compares the recovered closure order with his own memory of the last watch. Hugh says that a commander has to choose which lives he can afford to lose. Bernard replies that he kept men at their stations when boats were still available. He asks to put his own decision on record.

对质后，伯纳德将封湾军令与最后一次值更的记忆对照。休声称统帅必须选择能够承受的损失。伯纳德承认小艇尚可用时，自己仍要求士兵守岗位。他请求将自己的决定记入日志。

> Bernard: There ought to be room in a log for an order we should not have followed.
>
> 伯纳德：航海日志里也该留个位置，记下那些我们本不该服从的命令。

**State / 状态:** requires / 前置 `M_S03_LOG`; possible grants / 可能记录 `M_S03_ORDER, R_S03_ORDER`.

### S03_03 · Bellgrave Bay / 沉钟湾

**Act / 阶段 2 · anchor_conversation**

In a subsequent run Edmund can invite Bernard to challenge an order before departure. Bernard tests the offer with a mundane objection about loading the boats. Edmund can accept or overrule it; either way the remembered fact survives.

后续轮回，埃德蒙可在出航前邀请伯纳德提出异议。伯纳德先用一件普通的装船问题试探。王子可采纳或否决，相关知识均保留。

> Bernard: You may regret giving me permission to speak. / Edmund: I regret it already.
>
> 伯纳德：您可能会后悔准我开口。／埃德蒙：已经后悔了。

**State / 状态:** requires / 前置 `M_S03_ORDER`; possible grants / 可能记录 `R_S03_DISSENT`. Later expedition than / 必须晚于事件轮次 `S03_02`.

### S03_04 · Sunhold / 永昼王城

**Act / 阶段 2 · C05C**

At the Last Muster, Bernard offers to write a volunteer charter if the compulsory oath is released. If kept, he requests an independent grievance log, which Edmund may grant; the captain stays, but this does not free anyone.

最后集结时，若解除强制军誓，伯纳德主动起草志愿军章程。若保留军誓，他请求设立独立申诉日志，王子可批准；卫队长依然留下，但这并不赋予他人自由。

> Bernard: I shall stay, sir. Please do not enter that as everyone’s answer.
>
> 伯纳德：我会留下，殿下。请别把这句话记成所有人的回答。

**State / 状态:** requires / 前置 `M_S03_ORDER`; possible grants / 可能记录 `R_S03_CHARTER`.

**Resolution / 收束**

On release he remains as a volunteer for the final escort and may later train pilots. If the oath remains he serves but records grievances. In the true ending, any continued service requires renewed voluntary consent after Edmund releases his authority.

解除军誓后，他自愿完成最后的护送，随后可训练引航员。保留军誓时仍服役但记录申诉。真结局王子交出支配权后，继续服役必须重新获得自愿同意。

**Illustration brief / 插画任务**

ART_S03: Bernard writing in a salt-stained ship’s log; his helmet rests beside an extinguished signal lamp.

ART_S03：伯纳德在盐渍航海日志上写字，头盔放在熄灭的信号灯旁。

---

## S04 — A Hand for Knots / 打绳结的手

Matilda adores her workshop and the freedom to attempt repairs that living medicine could never achieve. Garran, once a dockworker, likes his great strength but cannot perform a task he once knew by touch. Their story is about craftsmanship, independence and pride, with room for comedy.

玛蒂尔达热爱工作间，也享受生前医学无法做到的修复。曾是码头工的加兰喜欢自己的力气，却无法完成过去凭触觉便能做好的工作。他们的故事关乎手艺、自主和自尊，也可以有幽默。

### S04_01 · Bellgrave Bay / 沉钟湾

**Act / 阶段 1 · anchor_conversation**

Garran tries to knot a mooring line with his enormous hand and crushes the peg. Matilda offers three improved weapons. He asks whether one of them might instead be a hand. No giant-unit unlock is required; this is a workshop resident.

加兰试图用巨大的手系缆绳，却捏碎木桩。玛蒂尔达提出三种改良武器。他问其中能否有一种其实是手。不要求已解锁巨人兵种；他是工作间里的角色。

> Garran: It is a splendid hammer. I was hoping for fingers.
>
> 加兰：这锤子确实不错。可我想要的是手指。

**State / 状态:** requires / 前置 `none / 无`; possible grants / 可能记录 `M_S04_HAND`.

### S04_02 · Broken Oar Harbour / 折桨港

**Act / 阶段 1 · arrival_or_post_battle**

After securing the dock, a damaged block and tackle demonstrates how Garran used to manage heavy ropes. He explains the mechanism if accompanying the company; otherwise a dockside drawing suffices. Recover a light fitting without sacrificing loot.

占领码头后，一套损坏的滑轮组展示加兰过去如何操控重缆。他随军时可亲自解释，否则码头结构图便足够。回收轻型接头，不扣除战利品。

> Matilda: A hinge, then. Why did you not say so? / Garran: I did. Twice.
>
> 玛蒂尔达：原来要个铰链。你怎么不早说？／加兰：说过。两次。

**State / 状态:** requires / 前置 `M_S04_HAND`; possible grants / 可能记录 `M_S04_RIG, R_S04_RIG`.

### S04_03 · Bellgrave Bay / 沉钟湾

**Act / 阶段 1 · anchor_conversation**

In a later anchor scene, Edmund sketches the fitting from memory. Matilda builds a removable tool from ordinary wreck material; Garran chooses when to attach it. Oswin proposes an experimental joint; she insists on asking the patient before fitting it.

之后的锚点场景中，埃德蒙凭记忆画出接头。玛蒂尔达用沉船普通材料做出可拆卸工具，由加兰决定何时装上。奥斯温提出实验关节，她坚持先问患者。

> Matilda: Hold still. No, not forever. Just until I finish the pin.
>
> 玛蒂尔达：别动。不是永远别动，等我把销子装好就行。

**State / 状态:** requires / 前置 `M_S04_RIG`; possible grants / 可能记录 `R_S04_CONSENT`. Later expedition than / 必须晚于事件轮次 `S04_02`.

**Resolution / 收束**

At the muster Garran may remain a volunteer dockworker or cross; Matilda can continue her practice with willing patients. No mechanical loss of giant troops, no mandatory permanent equipment transfer. The fitting is rebuilt, not transported through time.

集结时加兰可自愿当码头工或渡海离去；玛蒂尔达可继续为自愿患者工作。不扣巨人兵种、不强行永久转移装备。接头是重新制作的，不是穿越时间带回的。

**Illustration brief / 插画任务**

ART_S04: stitched giant carefully tying a knot with an articulated hand while Matilda looks on.

ART_S04：缝合巨人用活动手指小心系结，玛蒂尔达在旁观察。

---

## S05 — The Error in the Margin / 页边的错误

Oswin wants recognition as an engineer, not merely vindication as a victim. He fears the destruction of knowledge as much as the misuse of it. An old correction in his own hand leads to a dispute over what can be preserved when the Seal is stopped.

奥斯温希望作为工程学者得到认可，不只是作为受害者昭雪。他既害怕知识被滥用，也害怕知识被毁灭。自己昔日的批注引出一场争论：秘印停止后究竟应该保留什么。

### S05_01 · The Drowned Archive / 沉水藏书阁

**Act / 阶段 3 · arrival_or_post_battle**

A manuscript bears a correction he wrote before his execution. The later annotations reveal a distinction between residual soulfire and the erosion of a complete soul. He is delighted by his own correct arithmetic and appalled by the later application. This supplements K04/K05 but does not replace their official acquisition.

手稿保留他被处死前的修正。后来的批注揭示残余冥火与完整灵魂侵蚀的区别。他先得意自己算对了，随后被实际用途震惊。这补充K04/K05，不替代正式获取。

> Oswin: I was right about the figures. How inconvenient.
>
> 奥斯温：我的数字算对了。真不巧。

**State / 状态:** requires / 前置 `none / 无`; possible grants / 可能记录 `M_S05_NOTE, R_S05_NOTE`.

### S05_02 · Bellgrave Bay / 沉钟湾

**Act / 阶段 3 · anchor_conversation**

On the next return the Prince can reproduce the diagram in broad strokes. Oswin corrects it without remembering any previous conversation, and proposes non-coercive experiments in a small lamp. The test is not a substitute for the city’s heating or an instant cure.

下一次回溯，王子凭记忆画出大致图样。奥斯温不记得之前对话，却能修正草图，提出在小灯上进行非强制实验。实验不能代替城市供暖，也不是即时解药。

> Oswin: Your drawing has improved, Highness. Your handwriting has not.
>
> 奥斯温：殿下，您的画有进步。字可没有。

**State / 状态:** requires / 前置 `M_S05_NOTE`; possible grants / 可能记录 `R_S05_SKETCH`. Later expedition than / 必须晚于事件轮次 `S05_01`.

### S05_03 · Sunhold / 永昼王城

**Act / 阶段 3 · C05D**

At the Winter Council he asks that technical plans be catalogued separately from instructions for binding people. The ruler can authorise supervised study or seal the records. The research proposal never opens a third Seal option or blocks either binary choice.

冬政会议上，他请求将技术设计与束缚人的操作说明分开存档。君主可批准受监督研究或封存档案。研究提案不新增秘印第三选项，也不阻挡两种既定选择。

> Oswin: Let us keep the question. We have had quite enough of this answer.
>
> 奥斯温：把问题留下吧。这个答案我们已经受够了。

**State / 状态:** requires / 前置 `M_S05_NOTE`; possible grants / 可能记录 `R_S05_RESEARCH`.

**Resolution / 收束**

If the Day ends, the drawings are a historical record and possible research basis, not a working replacement. If preserved, his objection remains on record; research does not absolve the ongoing coercion.

永昼终止时，图纸只是历史记录与潜在研究基础，不是已可运行的替代方案。永昼延续时，他的反对意见留档；研究不消除持续的强制剥削。

**Illustration brief / 插画任务**

ART_S05: Oswin examining layered diagrams under a small green lamp; a later gold-ink annotation crosses his old notes.

ART_S05：奥斯温在小小绿灯下检查分层图纸，后来金墨批注压过旧笔记。

---

## S06 — The Missing Verse / 未唱完的歌

Pip went to sea to see the world. His mother still sells lamp oil on Lantern Isle. He worries that the last story he sent her made him sound braver than he was. The arc should contain warmth, mischief and an actual reunion, without demanding that every dead soldier go home.

皮普出海是为了见世面。母亲仍在长灯岛卖灯油。他担心最后寄回家的故事把自己写得过于勇敢。支线应有温暖、淘气与真实重逢，也不要求每个亡灵都选择回家。

### S06_01 · Broken Oar Harbour / 折桨港

**Act / 阶段 1 · arrival_or_post_battle**

Among undelivered mail is a draft by Pip. It promises a tale worth a drink but breaks off halfway through a familiar song. The Prince may read the address; the actual letter remains a current-run object.

未寄出的邮袋里有皮普的信稿，答应带回值得换一杯酒的故事，却在熟悉的歌唱到一半时中断。王子可以记下地址；信件实物仅属于本轮。

> Pip: I was going to improve that ending before I sent it.
>
> 皮普：我本来打算寄出去前，把结尾写得好一点。

**State / 状态:** requires / 前置 `none / 无`; possible grants / 可能记录 `M_S06_LETTER, R_S06_LETTER`.

### S06_02 · Lantern Isle / 长灯岛

**Act / 阶段 1 · arrival_or_post_battle**

Edmund finds the lamp-oil stall. If he has the letter he delivers it; otherwise he explains the wreck and quotes its first line. The mother gives him the final verse, but does not accept a promise of resurrection. She can ask for a name on the public roll.

埃德蒙找到灯油摊。若持有信件就交给她；否则解释海难并引用首句。母亲告诉他歌曲最后一段，却不接受复活承诺。她可请求把儿子名字写进公开名册。

> Mother: He never could remember the last line. Always in too much of a hurry.
>
> 母亲：他从来记不住最后一句。总是急着往下赶。

**State / 状态:** requires / 前置 `M_S06_LETTER`; possible grants / 可能记录 `M_S06_VERSE, R_S06_FAMILY`.

### S06_03 · Bellgrave Bay / 沉钟湾

**Act / 阶段 1 · anchor_conversation**

On a later return Edmund sings the final verse. Pip is delighted and mildly embarrassed that a prince knows his mother’s song. He asks whether they can stop at Lantern Isle again.

之后回溯，埃德蒙唱出最后一段。皮普既惊喜又有点难为情，没想到王子会母亲的歌。他请求再去一次长灯岛。

> Pip: You have been practising, sir. That is a terrible thing to discover about a prince.
>
> 皮普：您偷偷练过，殿下。这可真是件不得了的发现。

**State / 状态:** requires / 前置 `M_S06_VERSE`; possible grants / 可能记录 `R_S06_SONG`. Later expedition than / 必须晚于事件轮次 `S06_02`.

### S06_04 · Lantern Isle / 长灯岛

**Act / 阶段 1 · arrival_or_post_battle**

In a new visit Pip meets his mother after the battle. She recognises the tune before accepting the sight of him. He does not ask her to approve the army. He simply tells her the story of a bad crossing and promises to finish the rest if there is time.

再次到访时，皮普战后与母亲相见。她先认出曲调，才逐渐接受他的模样。他没有要求母亲认同军团，只讲了一次糟糕的渡海，若有时间再讲完。

> Mother: You are late. / Pip: I brought a rather good excuse.
>
> 母亲：你迟到了。／皮普：我倒有个相当充分的理由。

**State / 状态:** requires / 前置 `M_S06_VERSE, R_S06_SONG`; possible grants / 可能记录 `R_S06_REUNION`. Later expedition than / 必须晚于事件轮次 `S06_02`.

**Resolution / 收束**

If the oath is released he can choose home leave or volunteer for the adventure. At the final crossing Edmund can hum the verse; the mother only knows events that occurred this run. The reunion is not required for his name to be restored.

解除军誓后，他可选择回家休假或自愿继续冒险。最终渡航时王子可以哼唱歌谣；母亲只记得本轮发生的事。重逢并非恢复姓名的前置条件。

**Illustration brief / 插画任务**

ART_S06: lamp-oil stall at dusk, a small bugler and his mother on opposite sides of the counter.

ART_S06：黄昏灯油摊，号手与母亲隔着柜台相见。

---

## S07 — A Seat in the Boat / 船上的空座

The Ferryman is familiar without becoming explainable. He knows outcomes, not every event or future. The recurring arc develops from a working relationship to an argument about what the Prince intends to do with an endless series of borrowed histories.

渡魂人逐渐成为熟悉的存在，但始终无法被彻底解释。他知晓结局，不知道每个细节或未来。支线从合作关系发展为关于王子如何使用不断借来的历史的争论。

### S07_01 · Bellgrave Bay / 沉钟湾

**Act / 阶段 1 · anchor_conversation**

On the first available return, guaranteed by the second expedition, the Ferryman comments on the actual outcome. If defeated, he mentions the lost campaign; if crowned, he uses Majesty. Edmund recognises his knowledge once. This beat shares the canonical recognition flag; never replay it.

第一次可用回溯时触发，第二轮出征前保底。渡魂人评论实际结局：失败就提到失利，继位就称陛下。王子仅一次确认他知情。与正史确认标记共用，不重播。

> Edmund: You know? / Ferryman: I know where you have been.
>
> 埃德蒙：你知道？／渡魂人：我知道你去过哪里。

**State / 状态:** requires / 前置 `RETURN_OCCURRED`; possible grants / 可能记录 `M_S07_KNOWS`.

### S07_02 · Silent Shoals / 寂礁群

**Act / 阶段 2 · arrival_or_post_battle**

At Silent Shoals, old ferry stones have different names for the same destination. Edmund asks which is correct. The reply comes privately; nobody else hears it. The Ferryman refuses to settle a theological dispute.

寂礁群的古渡石以不同名称指称同一去处。王子问哪个正确。回复在意识中出现，无旁人听见。渡魂人拒绝裁定神学争论。

> Ferryman: A shore does not much care what a man calls it.
>
> 渡魂人：一片海岸可不太在乎人给它起什么名字。

**State / 状态:** requires / 前置 `M_S07_KNOWS`; possible grants / 可能记录 `M_S07_RITE`.

### S07_03 · Bellgrave Bay / 沉钟湾

**Act / 阶段 3 · anchor_conversation**

Canonical Act IV unlock: after witnessing the Seal release, the Ferryman explains voluntary relinquishment. Edmund asks why victory was not sufficient. The answer concerns the binding, not a moral examination. This is the existing guaranteed K07 event, not a side-story prerequisite.

正史第四幕解锁：亲历秘印释放之后，渡魂人解释自愿解约。王子问为何胜利不够。回答针对契约，而非道德考验。这是已有K07保底事件，不是支线前置。

> Edmund: You could have told me that a victory would not keep me here. / Ferryman: I could have. You would have asked for the road all the same.
>
> 埃德蒙：你本可以告诉我，胜利并不能让我留下。／渡魂人：可以。可你仍会向我要那条路。

**State / 状态:** requires / 前置 `WITNESSED_E05_E08`; possible grants / 可能记录 `K07`.

### S07_04 · Sunhold / 永昼王城

**Act / 阶段 4 · true_final_shore**

At the final shore, the previously empty seat is ready. Optional callbacks to Silent Shoals or earlier arguments change one line only. The canonical Final Crossing dialogue and credits remain.

最后海岸上，始终空着的位置已经准备好。寂礁群或此前争论只改变一句可选呼应。正史最终渡航对白及演职员表保持。

> Ferryman: Then come aboard.
>
> 渡魂人：那就上船吧。

**State / 状态:** requires / 前置 `K07, TRUE_RELEASE_CONFIRMED`; possible grants / 可能记录 `none / 无`.

**Resolution / 收束**

No reveal of his true face, identity or knowledge mechanism. He never remembers on behalf of other people and never returns the completed save to the anchor.

不揭露真实面容、身份或知情原理。他不代替别人保留记忆，也不让已完结存档回到锚点。

**Illustration brief / 插画任务**

ART_S07: empty seat in a small boat, a green lantern and a far shore at first light; reuse B.2 motif.

ART_S07：小舟空座、绿灯、微明远岸；沿用B.2意象。

---

## S08 — The Price of a Passage / 一程船资

Roderick’s generosity once saved a crew’s wages. His later monopoly turns that generosity into an instrument of power. A harbour dispute reveals what it costs a skipper to refuse him.

罗德里克曾慷慨解救一船人的薪资。后来独占航运权，慷慨也成了权力工具。一场港口纠纷揭示船长拒绝他的代价。

### S08_01 · The Last Lighthouse / 天涯灯塔

**Act / 阶段 1 · arrival_or_post_battle**

The signal keeper shows an unpaid rescue fee beside a cancelled sailing order. A familiar merchant mark appears on both. The keeper asks that the harbour debt not be attributed to the fishermen.

守灯人展示一笔未付救援费和取消航行的命令。两者有相同商号标记。他请求不要把港口欠债算到渔民头上。

> Keeper: We had boats enough. What we lacked was permission.
>
> 守灯人：船够用。缺的是准许出航的命令。

**State / 状态:** requires / 前置 `none / 无`; possible grants / 可能记录 `M_S08_MARK, R_S08_LEDGER`.

### S08_02 · Broken Oar Harbour / 折桨港

**Act / 阶段 1 · arrival_or_post_battle**

Roderick offers to reopen the shipping market if his contracts survive. The Prince can demand a current copy of the charter and place it in custody without promising immunity. If Roderick has already fallen, his steward provides the same record after the battle.

罗德里克提出保留合同便重新开放航运市场。王子可索要本轮契约副本并封存，不承诺豁免。若伯爵已倒台，管事战后提供相同记录。

> Roderick: Kill me if you like. The ships will still need captains.
>
> 罗德里克：想杀我就杀吧。那些船还是得有船长。

**State / 状态:** requires / 前置 `M_S08_MARK`; possible grants / 可能记录 `M_S08_BARGAIN, R_S08_ACCOUNT`.

### S08_03 · Sunhold / 永昼王城

**Act / 阶段 2 · C05B**

At the fall of the Council, the ruler separates ordinary sailors’ wage contracts from privileged royal concessions. If no current account is held, the palace can commission an audit rather than treat the remembered charter as evidence.

摄政覆灭时君主将普通船员工资合同与王室特许权分开。若未持有本轮账册，宫廷可委任审计，而非把记忆中的契约当作物证。

> Edmund: Honour the wages. Review the privilege.
>
> 埃德蒙：照付工钱。重审特许权。

**State / 状态:** requires / 前置 `M_S08_BARGAIN`; possible grants / 可能记录 `R_S08_PORT_REVIEW`.

**Resolution / 收束**

An epilogue records whether the port has reopened under review. Roderick’s personal fate is taken from the current encounter, not inferred from the audit.

尾声记录港口是否在审查下重新开放。罗德里克个人命运由本轮遭遇决定，不能由审计推断。

**Illustration brief / 插画任务**

ART_S08: a customs hall with a ship’s payroll and a miniature harbour chart.

ART_S08：海关大厅、船员工资册与小幅海图。

---

## S09 — A Measure of Grain / 一斗麦子

Agnes saved her estate through sound storage practice, then protected it by shifting the risk of hunger onto others. A miller’s daughter asks for a receipt for grain taken under Edmund’s own warrant.

阿格尼丝曾靠可靠的仓储技术挽救领地，后来却将挨饿的风险转嫁给别人。磨坊主的女儿要求为依据王子旧令征走的谷物开具收据。

### S09_01 · Miller’s Crossing / 磨桥渡

**Act / 阶段 1 · arrival_or_post_battle**

The girl shows one half of a split tally stick; the matching half is missing. Edmund recognises his seal on the warrant. He can issue a provisional receipt in his own name, not promise payment from an unrecognised treasury.

女孩出示刻痕木契的一半，另一半不知去向。王子认出征令上的印玺。他可以自己名义签临时收据，但不能承诺从尚未承认他的国库付款。

> Girl: The grain is gone, sir. I thought I ought to keep the stick.
>
> 女孩：麦子已经没了，大人。我想至少该把木契留下。

**State / 状态:** requires / 前置 `none / 无`; possible grants / 可能记录 `M_S09_RECEIPT, R_S09_CLAIM`.

### S09_02 · The Great Granary / 万谷仓

**Act / 阶段 1 · arrival_or_post_battle**

The warehouse record distinguishes reserves legitimately set aside for winter from private diversions. Agnes insists that every sack has an owner. Edmund asks whose names are missing. If the stores were damaged, the loss remains real.

仓储账册区分真正为冬储保留的谷物与私下转拨。阿格尼丝坚持每袋都有主人，王子则追问缺了谁的姓名。若仓库已受损，损失依旧存在。

> Agnes: A famine is not ended by a generous signature. / Edmund: Nor is a debt.
>
> 阿格尼丝：一份慷慨的签字结束不了饥荒。／埃德蒙：也结束不了欠账。

**State / 状态:** requires / 前置 `M_S09_RECEIPT`; possible grants / 可能记录 `M_S09_TALLY, R_S09_AUDIT`.

### S09_03 · Sunhold / 永昼王城

**Act / 阶段 2 · C05D**

The recognised ruler authorises a claims register. A present claimant or surviving public record is required to pay any particular family. If the Prince skipped the grain route this run, the policy begins with an inquiry rather than an automatic full repayment.

获承认的君主批准申索名册。偿付具体家庭必须有本轮申索人或现存公共记录。若王子本轮绕开粮道，政策先从调查开始，而非自动全额偿付。

> Eleanor: Put the missing names back before we count the sacks again.
>
> 埃莉诺：下次清点麦袋以前，先把缺掉的名字补回来。

**State / 状态:** requires / 前置 `M_S09_TALLY`; possible grants / 可能记录 `R_S09_CLAIMS_PLAN`.

**Resolution / 收束**

Preserved stores improve the transition only when actually saved this run. The claim register can exist in any ending; it does not guarantee a good harvest.

只有本轮实际保全的粮储能改善过渡。任何结局均可建立申索名册，但它不保证丰收。

**Illustration brief / 插画任务**

ART_S09: two halves of a wooden tally beside an empty grain measure.

ART_S09：空麦斗旁两半刻痕木契。

---

## S10 — The Names Beneath the Stone / 石碑下的名字

A young novice once learnt the burial songs from Anselm himself. Now the archbishop’s office requires him to remove the names of condemned sailors. The novice obeys in public and secretly preserves the names on the underside of grave markers.

一名年轻见习修士曾亲自向安塞姆学习葬歌。如今大主教的机构要求他抹除获罪水手的名字。他公开服从，却偷偷把姓名留在墓牌背面。

### S10_01 · Hollow Graves / 无碑墓园

**Act / 阶段 2 · arrival_or_post_battle**

The Prince turns over a blank marker and discovers a list in the novice’s small hand. The novice admits he does not know whether the dead can hear him. He only knows a family ought to have somewhere to stand.

王子翻过空白墓牌，发现见习修士细小的笔迹。他承认不知道死者能否听见，只知道家属应该有个能够站着悼念的地方。

> Novice: I was told not to put their names on the stones. No one mentioned the undersides.
>
> 修士：他们只说不能把名字刻在碑上。没说碑底。

**State / 状态:** requires / 前置 `none / 无`; possible grants / 可能记录 `M_S10_NAMES, R_S10_NAMES`.

### S10_02 · The Pale Abbey / 苍白圣堂

**Act / 阶段 2 · arrival_or_post_battle**

The novice can identify the judgement draft and ask Anselm why the date precedes the wreck. His testimony is volunteered only when his safety is secured. If the archbishop is absent, the draft and a surviving copy provide the documentary route.

见习修士可以辨认判决草稿，并问安塞姆日期为何早于沉船。只有安全得到保障才自愿作证。大主教不在时，可通过草稿和存续副本走文证路径。

> Anselm: There are matters you cannot understand. / Novice: I understand the date, Father.
>
> 安塞姆：有些事你还不能理解。／修士：我看得懂日期，神父。

**State / 状态:** requires / 前置 `M_S10_NAMES`; possible grants / 可能记录 `M_S10_DRAFT, R_S10_WITNESS`.

### S10_03 · Sunhold / 永昼王城

**Act / 阶段 2 · C05B**

The sovereign may publish a restored roll based on present records. If the novice was not reached this run, he is not suddenly a witness; the court restores what it can from surviving registers. The missing are marked as missing, not invented.

君主可依据本轮记录公布恢复后的名册。若本轮未找到修士，他不会突然成为证人；宫廷只能依据存续名册恢复可确认内容。缺失的继续标作缺失，不编造。

> Oswin: Leave room for the names we have not found.
>
> 奥斯温：给尚未找到的名字留些位置。

**State / 状态:** requires / 前置 `M_S10_DRAFT`; possible grants / 可能记录 `R_S10_ROLL`.

**Resolution / 收束**

Names become legal and commemorative records, not magical soul keys. Ending the Day frees surviving captives irrespective of the optional list.

姓名承担法律与纪念功能，不是灵魂魔法钥匙。终止永昼释放尚存囚魂，不依赖可选名册。

**Illustration brief / 插画任务**

ART_S10: a quiet flooded graveyard, overturned wooden markers and a lantern.

ART_S10：宁静的水淹墓地、翻过来的木牌与灯火。

---

## S11 — The Practice Sword / 练习剑

Hugh trained Edmund to retreat when a position was lost. Years later he used the language of protecting the navy to defend the murder of his pupil. This optional encounter gives the Prince a personal answer without making the marshal innocent.

休教埃德蒙在阵地无法保住时撤退。多年后他却用保全海军的理由为谋杀学生辩护。这段可选遭遇给王子一个私人层面的答案，但不为元帅脱罪。

### S11_01 · The Iron Gate / 锁海之门

**Act / 阶段 1 · arrival_or_post_battle**

After the Iron Gate battle the Prince recognises an old practice blade in the command room. Hugh admits he removed it from his daily uniform before signing the closure order. If Hugh did not survive the encounter, his written inventory establishes only that the blade was stored, not what he felt.

锁海之门战后王子在指挥室认出旧练习剑。若休存活，他承认签署封湾命令前便不再随身佩戴。若未存活，清单仅证明剑被收存，不编造其感受。

> Edmund: You taught me when to retreat. / Hugh: I did not teach myself well enough.
>
> 埃德蒙：是你教我什么时候该撤退。／休：我自己却没学好。

**State / 状态:** requires / 前置 `none / 无`; possible grants / 可能记录 `M_S11_LESSON, R_S11_ORDER`.

### S11_02 · Blackwake Yard / 黑浪船厂

**Act / 阶段 1 · arrival_or_post_battle**

Shipyard officers worry that exposing Hugh will make the entire fleet guilty. The Prince distinguishes a specific illegal command from ordinary service. Surviving officers may offer a statement to the recognised ruler, not unconditional loyalty to an undead claimant.

船厂军官担心揭发休会使整支舰队获罪。王子区分具体非法命令与普通服役。存续军官可向获承认的君主提交陈述，不会无条件效忠亡灵王位主张者。

> Officer: My oath was to the Crown. / Edmund: Then we had better establish whose seal that is.
>
> 军官：我效忠王冠。／埃德蒙：那我们最好先弄清是谁的印玺。

**State / 状态:** requires / 前置 `M_S11_LESSON`; possible grants / 可能记录 `M_S11_CREWS, R_S11_OFFICERS`.

### S11_03 · Sunhold / 永昼王城

**Act / 阶段 2 · C05B**

The palace distinguishes culpable officers from those not shown to have known the plan. With current testimony, a review can begin immediately; without it, the new ruler orders a formal inquiry. Hugh’s fate follows his current status.

宫城区分负有责任的军官与没有证据表明知情的人员。有本轮证言可立即启动审查，否则新君主下令正式调查。休的命运取决于本轮状态。

> Bernard: We shall need the orders, not a list of everyone who wore his colours.
>
> 伯纳德：我们需要的是军令，不是一张所有穿过他军服的人的名单。

**State / 状态:** requires / 前置 `M_S11_CREWS`; possible grants / 可能记录 `R_S11_REVIEW`.

**Resolution / 收束**

The restored naval command supports the Crown or Queen according to the chosen settlement. The old teacher’s guilt is neither transferred to every sailor nor erased by a confession.

重组海军按本轮政治安排支持王位或女王。旧老师的罪责既不转嫁每一名水手，也不因认罪消失。

**Illustration brief / 插画任务**

ART_S11: an old wooden practice sword and a signed naval order in a fortress chamber.

ART_S11：要塞房间内的旧木练习剑和已签军令。

---

## S12 — The Unopened Petition / 未拆的请愿书

Walter understands how a government can be controlled without wearing its crown. A household clerk has been hiding original petitions beneath approved summaries. The story shows that dismissing the chancellor is only the first step towards a functioning government.

沃尔特知道如何不戴王冠却掌控政府。一名宫廷文书官把请愿原件藏在获准摘要下面。这条故事说明罢免宰相仅是重建政府的第一步。

### S12_01 · Merchant Gate / 白港门

**Act / 阶段 2 · arrival_or_post_battle**

A petition on sailors’ arrears carries both the original text and a shorter authorised summary. The summary leaves out names and the date. The merchant gate clerk identifies the dispatch reference, but cannot speak for the Queen.

一份水手欠饷请愿留有原文及较短的获准摘要。摘要省略姓名和日期。白港门文书能指出发送编号，却不能代表女王发言。

> Clerk: It was answered, according to the register. That is not quite the same as being read.
>
> 文书：登记册说已经回复了。与读过它不完全是一回事。

**State / 状态:** requires / 前置 `none / 无`; possible grants / 可能记录 `M_S12_DUPLICATE, R_S12_PETITION`.

### S12_02 · Sunhold / 永昼王城

**Act / 阶段 2 · C05A**

At the Royal Audience the household clerk produces the original if Eleanor grants access. The Queen explains that her answers have been sent under her seal without her seeing the questions. She asks for independent custody of the correspondence.

王室会面中，若女王批准查阅，宫廷文书出示原件。她解释有人用她的印玺发送答复，她甚至没有见过问题。她请求独立保管通信。

> Eleanor: Apparently I have been very busy. I should like to know what I have been doing.
>
> 埃莉诺：看来我一直很忙。我倒想知道自己都忙了些什么。

**State / 状态:** requires / 前置 `M_S12_DUPLICATE`; possible grants / 可能记录 `M_S12_FILTER, R_S12_ACCESS`.

### S12_03 · Sunhold / 永昼王城

**Act / 阶段 2 · C05B**

During the fall of the Council, Walter argues that replacing experienced clerks will paralyse the city. The ruler retains necessary administrative staff under new oversight and removes Walter’s control of the seal. A current record supports any individual finding of guilt.

摄政覆灭时沃尔特辩称撤换熟练文书会让城市瘫痪。君主在新监督下保留必要行政人员，撤除沃尔特对印玺的控制。认定具体个人罪责须有本轮记录。

> Walter: Someone must keep the kingdom running. / Eleanor: Yes. Someone other than you, for a change.
>
> 沃尔特：总得有人让王国继续运转。／埃莉诺：是啊。这次换个人吧。

**State / 状态:** requires / 前置 `M_S12_FILTER`; possible grants / 可能记录 `R_S12_REGENCY_REFORM`.

**Resolution / 收束**

The ending shows a working petition office, not instant perfect government. A ruler may establish the office even if this arc is unseen; the optional arc provides a named participant and a more specific outcome.

尾声呈现开始运作的请愿机构，不是瞬间完美的政府。未经历支线的君主也可建立机构；支线增加具名参与者与更具体的结果。

**Illustration brief / 插画任务**

ART_S12: an original petition beneath a neat official summary, a small royal seal and an unopened letter.

ART_S12：整齐官方摘要下的请愿原件、小王印与未拆信封。

## Assembly at the capital / 王都场景装配

| Main scene / 主线场景 | Optional contributions / 可选支线内容 |
|---|---|
| Royal Audience, before Crown / 王权选择前 | S01 (siblings), S12 (petition). One short combined exchange; Eleanor's decision remains independent. / 兄妹与请愿合并成短对话，女王独立决定。 |
| Fall of Council / 摄政覆灭 | S08 ports, S10 restored roll, S11 naval review, S12 correspondence. Show one relevant document and summarise the rest in the settlement register. / 港务、名册、军令与通信；展示一份最相关文书，其余进入安排记录。 |
| Last Muster / 最后集结 | S03 charter, S04 Garran, S06 Pip. A single montage with distinct wishes; no compulsory troop loss. / 志愿章程、加兰、皮普；一次短蒙太奇展示不同愿望，不强制扣兵。 |
| Winter Council / 冬政会议 | S01 queen's draft, S02 king's exception, S05 research, S09 claims. Material resources come from actual run state. / 女王草案、先王例外、研究与申索；实物资源仅取本轮状态。 |
| Epilogue / 尾声 | Select up to two resolved optional callbacks relevant to the three decisions, leaving full records in the journal. / 选最多两个与三项决定相关的已收束呼应，完整记录留日志。 |
| Final Crossing / 最后渡航 | S07 canonical release; S01 boat and S06 song as optional brief callbacks, without altering the final release and credits. / 正史解约；小船与歌曲仅作简短可选呼应，不改变最终解约与演职员表。 |

## Side-story outcomes and tone / 支线结果与基调

Do not award a universal morality score. A mother receiving her son, an engineer retaining a drawing, a captain raising an objection, and a clerk keeping a register are different achievements. The Prince may act generously in one scene and retain an oppressive institution in another. Each contradiction should be acknowledged locally. / 不设统一善恶分。母子重逢、工程师留存图纸、卫队长提出异议、文书保留登记册，属于不同成就。王子可在一场戏慷慨，在另一场继续保留压迫性制度；各处分别承认矛盾。

The visual plan requires no final illustrations yet. S01 and S07 deliberately reuse B.2's motifs; the remaining briefs join B.4's visual queue. English labels only; use the existing Prince model and the next character design pass to establish visual continuity. / 此阶段不要求已完成插画。S01、S07有意复用B.2意象，其余进入B.4美术队列。图内仅英文；沿用王子原设定，待下一轮人物造型统一视觉。
