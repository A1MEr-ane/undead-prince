# Bad North 本地机制取证（T48，部分交付）

**结论：需要 Lead 复核，调查已按任务卡停止。** `docs/badnorth-art-spec.md` §2.2 将 **0.1 翻转滞回**泛化到士兵表现；本地样本的身体实际走 GPU 顶点展开与**零阈值翻转**，独立 CPU `Billboard` 的 0.1 滞回没有接入已检查的三个士兵预制体。详见证据索引 B01–B06。未修改原规格。

1. **镜头**：30° 俯角；用正交视野尺寸缩放。连续拖动 / 长按与可关闭的短按分档并存；分档跨 0° 用最短角差。主 Camera 的 `orthographic` 布尔引用尚未闭环，不能宣称已完成投影复核。（`LOCAL_CONFIRMED`：C01–C02、C04–C15；`UNKNOWN`：C03）
2. **公告板与翻转**：独立 `Billboard.LateUpdate` 在 CPU 朝向与翻转，确有 0.1 滞回；样本士兵身体为 `SpriteAnimator → BatchedSprite → Unlit/ColoredCharacter` 的 GPU 路径，按零阈值决定镜像。身体展开保留变换后的 up；击飞全链与转镜头稳定性未实测。（`LOCAL_CONFIRMED`：B01–B07；冲突升级点：B06）
3. **装备**：盾与弓样本是独立三维网格；盾挂在动画节点下。剑的表示、全部武器类型及完整前后遮挡尚未核实。（`LOCAL_CONFIRMED`：E01–E03、R02；`UNKNOWN`：E04 及剑的表示）
4. **飞行物**：普通箭和重型箭使用带重力、阻力的固定步积分，初速度来自轨迹表；绘制是精灵驱动的动态网格。盾上的箭是随盾附着的盖章网格，容量 4；未见写回盾贴图。`TankArcherArrow` 是否对应任务所称“弩矢”未确认。（`LOCAL_CONFIRMED`：P01–P06、R03）
5. **特效**：血、水花、火花样本有 Unity ParticleSystem；尘土另用容量 256 的自定义网格。火、烟的实际引用链未完成，不能将它们一概归类；方向生成与面向镜头分属不同层次。（`LOCAL_CONFIRMED`：F01–F09；`UNKNOWN`：F10、R04 后半链）

地形只定位到模块数据与相关处理器，没有完成数量、兼容规则、平滑 / 法线、材质混合或导航对应关系的复核（T01–T02）。**以下内容不能作为六个系统全部验收通过的依据。**

## 1. 来源、方法及停止边界

本次检查日期为 2026-11-25（Asia/Singapore）。版本为本地 macOS **Bad North: Jotunn Edition 2.00.5，build 36，Unity 2018.4.0f1，Mono**。直接依据是 `Manifests/provenance.json` 的版本记录和导出工程 `ProjectVersion.txt`；未重新做安装包 / DLL 的整包哈希核验（V01）。

先读了仓库 `AGENTS.md`、`docs/collab.md`、T48 任务卡、`docs/badnorth-art-spec.md`，以及 `~/Downloads/BAD_NORTH_ART_TECH_RESEARCH.md` §2–6、§10。仅以现有解包内容为调查对象，没有重新解包或绕过访问控制。

源码以 `DecompiledSource/Assembly-CSharp/` 为入口；资源以 AssetRipper 导出的 Unity YAML 和 `.meta` 为入口，通过 GUID 关联预制体、材质、Shader、Sprite 和纹理；编译程序文本仅用于理解运行阶段。所有记录为自行撰写的摘要，没有将原作代码 / shader / 图像 / 模型放入仓库。

完整路径及字段集中在 [证据索引](BAD_NORTH_EVIDENCE_INDEX.md)。本文 ID 均指向该表，沿用其中的路径前缀和证据等级。`LOCAL_CONFIRMED` 只说明直接读到字段 / 行为，不等于已经在游戏中观察到，也不等于覆盖全部对象。未调用外部服务、未查公开链接、未运行原作或 Unity 重建工程。

**停止原因**：身体渲染实际链与 §2.2 的滞回适用范围冲突，命中 T48 的 `escalate_if`。确认该冲突后停止扩展调查；下述其他系统仅整理此前已读到的材料，缺口保留 `UNKNOWN`。未擅自修正规格，也未进入 `FLEET_ART_TECH_DECISION.md` 的技术选型。

## 2. 镜头：输入路径与参数应分别记录

### 投影、俯角与缩放

`LevelCamera.Awake` 将 pitch 节点设为 30°；`Constants` 同时记录相机角度与高度补偿值（C01）。`LevelCamera.UpdateCameraOrtho` 操作 Unity 正交半高，而控制层的 `GetOrthoWidth/SetOrthoWidth` 使用**完整视野宽度**，中间按显示宽高比换算（C02）。

现有规格说主镜头正交；本次已确认尺寸控制机制，但尚未完成主 Camera 投影布尔的对象关联。`IslandGameplay.unity` 中 `_camera` 指向 fileID `778`，场景有多台 Camera，搜索结果包含正交与透视两种值；在停止前没有核对到该引用对应的具体 Camera 块（C03，`UNKNOWN`）。

默认缩放限制不是硬编码的“7.5–12”，那只是 C# 内部默认值。导出场景的默认配置为**宽度最小 10、基准最大 22**，实际最大宽度还与岛屿雾直径比较取较大值。另有平台位掩码覆盖 `128/520/1040`；本次没有读枚举定义，不将这些数值擅自命名为 PC / 主机 / 移动平台（C12–C13）。

滚轮目标按 1.04 的比例基数变化，再由 seeker 平滑接近；捏合直接改宽度，另有限速 1300 像素 / 秒并在触及边界后重建捏合基准。场景中的缩放 seeker 为最大速度 60、最小速度 1、加速度 1000、减速距离 3、误差 0.001（C14）。这些均为局部读取结果，没有测实际可见缩放极限。

### 连续拖动、短按分档及跨零

拖动按屏幕水平位移累计偏航，场景 `rotationMultiplier=180`；不存在把每次拖动强制量化到四个方向的逻辑。松手可接惯性旋转（C04、C10）。

`CameraController.UpdateButtonYaw` 区分短按和长按：非 Joystick 的按钮在 0.175 秒内松开、且用户未禁用旋转吸附时，进入 `CameraSeeker.SeekToLatch`；长按则使用 `CameraRotator`。因此“连续环绕”与“快捷分档”同时成立（C05）。

分档场景参数为 4 档、45° 基准、沿输入方向附加 7.5°。这里的 `latchOvershootDegrees` 直接参与目标角计算，不能仅凭字段名推断它会再回弹至精确对角线。分档 seeker 的 angle 模式使用 `DeltaAngle/MoveTowardsAngle`，明确处理跨 0° 的短路径（C06–C07）。

连续旋转从当前 yaw 加角增量，再写四元数；它不将 359° 与 1° 当普通标量插值。该实现事实并不替代快速反向 / 连转多圈的运行验证（C08）。

### 平滑与时间

按键偏航场景参数为最大 230°/s、加速度 1000°/s²、减速度 1750°/s²、停止阈值 5°/s。分档 seeker 参数则为最大 920°/s、最小 2.5°/s、加速度 4500°/s²、减速距离 25°、误差 0.5°；两条路径不同（C09、C11）。

松手惯性同时进行指数衰减和线性减速，场景值分别为 `0.6` 与 `5`，旋转速度上限 1080°/s；拖动端另有 95°/s 的释放触发阈值和 1000°/s 的释放速度限制（C10、C04 对应源路径）。

镜头组件的时间步最多 0.05 秒，并按各组件 `timeScaleEffect` 混合缩放时间与未缩放时间。拖动、分档、惯性、按键、缩放的场景权重各不相同；选队缩放 / 偏移过渡才独立使用 `unscaledDeltaTime`。不能把整个镜头系统统称为完全不受慢动作影响（C15）。

## 3. 身体：应区分独立 Billboard 与 GPU 展开路径

### 独立 CPU Billboard 已确认的行为

`CameraController.Update` 刷新 `Billboard` 的共享水平视向；每个 `Billboard.LateUpdate` 设置朝向。当父节点 up 接近世界竖直时使用共享旋转，否则沿父节点 up 构建旋转。可翻转对象根据父 forward 与相机 right 的关系决定镜像，保留 `flipped` 状态，在越过 **0.1** 阈值后才翻转局部 X 缩放（B01–B02）。这直接支持现有规格对该**类本身**的描述。

### 士兵身体的实际资源链

检查 `English_SwordShield`、`English_Archer`、`Viking_SwordShield` 的组件及 GUID 后，三者身体挂的是 `SpriteAnimator`，没有上述 CPU `Billboard`（B03）。

`SpriteAnimator` 继承 `BatchedSprite`。`BatchedSprite.Awake` 创建动态四顶点网格并添加 MeshRenderer，禁用原 SpriteRenderer。四个原始顶点重合，UV 承担图集坐标，`uv2` 承担平面尺寸，tangent 携带 up 信息；可见几何由顶点程序展开（B04）。因此，仅看到预制体中的 SpriteRenderer 或 MeshRenderer，均不足以直接判断实际几何形状。

身体材质 `Colored.mat` 指向 `Unlit_ColoredCharacter.asset`，与编译文本的 `Unlit/ColoredCharacter` 对应。已读 `_GAME_ON` 顶点分支使用变换后的法线 / up、视图矩阵和 `uv2` 生成平面；镜像判定为**当前点积是否过零**。该分支没有上一帧镜像状态或 0.1 阈值（B05）。`Colored.mat` 里虽有 `_AXIS_Y` 字符串，本次不能只凭材质关键字名称推断具体分支；确认依据是已关联的角色 shader 顶点程序。

这与现有规格 §2.2 将 0.1 滞回归到小兵精灵的表述发生冲突（B06）。**本次不裁定其他对象是否也存在同样问题，不自行改规格；交 Lead 决定是否拆开两条路径，并授权后续调查。**

### 动画、倾倒及外观

身体展开使用变换后的 up，再与相机方向建立横向基；这为倾倒保留了局部方向信息，但不能拿 CPU `Billboard` 的父 up 分支代替身体的击飞证据。`Ragdoller` 已读到通过物理代理同步位置、切换 Ragdoll / Rise 动画和恢复导航的行为；完整旋转驱动链、极端角度与实际抖动尚未闭环或观察（B07）。

`SpriteAnimator` 更换帧时更新身体 Sprite；外观通过独立 `sprite2` 和 `_PartTex` 传入，以顶点色 RG 指向外观区域。R01 已追到身体帧共用的 Group 0 图集与外观纹理。材质文件的 `_MainTex` 初始值并不是最终运行时帧纹理，必须结合属性块覆盖读取（B08、R01）。

本次没有重新核验“12 帧 / 秒”及“37–71 帧”的总量结论。`Swordsman_Attack.anim` 的 `m_SampleRate=60` 是动画剪辑字段，不能据此宣称贴图动画为 60 帧 / 秒。

## 4. 装备：网格、挂点与遮挡的边界

`English_SwordShield` 的 Shield 对象有独立 MeshFilter / MeshRenderer，引用 `Weapons_Shield_1.asset`，并在 LevelMesh 组件中列出另两个候选网格；`Viking_SwordShield` 亦有盾网格。英军弓与维京弓分别指向独立弓网格；材质均沿 `Palette.mat → Unlit_FlatVoxel.asset → Palette.png` 关联（E01–E02、R02）。

盾路径为 `BounceAnim/ShieldAimer/ShieldAnim/Shield`。攻击剪辑包含该挂点的变换曲线，以及身体对象的动画曲线；盾状态逻辑通过 Animator 参数控制相关姿态（E03；`Shield.Setup/ShieldAnimParams`）。

剑样本没有在已打印的组件中出现独立剑 MeshFilter，但这不充分证明剑一定完全画在身体帧里；本次未检查图像或全部动态附加过程，保留未知。也不将“盾和弓是三维网格”推广为“全部武器三维”。

已读身体材质队列 2040、装备 Palette 队列 2061，身体 shader 有 alpha-to-coverage、关闭背面剔除和沿视线微偏移。仍需对有效平台变体的深度状态、装备几何和实际画面一起核验，才能说明前后遮挡；**渲染队列数字本身不足以证明正确遮挡**（E04）。

## 5. 飞行物：求解、积分与盖章是三个阶段

### 发射求解

`ProjectileMath` 提供固定角度 / 速度 / 顶点高度等解析工具，`HeightBasedProjectileSolver` 会使用其中的顶点高度求解。然而，已追到的普通弓箭链是 `Archery.AimAt → TrajectoryUtility.Sample → startVelocity`，不能只依据工具类存在就认定普通箭实时调用解析抛物线求解（P01）。

`TrajectoryUtility` 在水平距离 / 高差网格记录起速、撞击速度、飞行时间等属性，采样时插值；计算代价的路径会用与实际箭相同的 Projectile 步进模拟。瞄准还读取目标速度和预计撞击时间作提前量（P01）。预计算的完整生成时机没有继续追完。

普通轨迹预制体配置速度范围 2–12、阻力 2、起点偏移 0.1、重力 9.8；重型箭轨迹则是 2–20、阻力 0.5、起点偏移 0.3、重力 9.8。`Viking_TankArcher` 引用 `TankArcherTrajectory` 与 `TankArcher_Arrow`（P03）。这些字段是轨迹配置，不等于每一发都取最大速度。

### 飞行与渲染

普通箭每固定步沿当前速度覆盖的路段射线检测；没有命中时，先衰减阻力并施加重力，再移动位置。箭朝向跟随速度。反弹 / 翻滚后会转入 Rigidbody 路径，不能将整个生命周期视为一个解析公式（P02；`Arrow.Bounce`）。

`Arrow.prefab` 与 `TankArcher_Arrow.prefab` 的已查可视对象是 SpriteRenderer + BatchedSprite，运行时通过四顶点网格绘制。两者用 `Billboard.mat → Unlit_Billboard.asset`，精灵落在 Group 2 图集。具体轴向 shader 变体、是否并用其他 Renderer 及所有镜头角度效果未核验（P04、R03）。

`TankArcherArrow` 以非分配射线检测处理多个命中，穿透后削减速度与 energy；飞行画面长度还随速度在局部 Z 轴上缩放并刷新 sprite 尺寸。暂称“重型箭”，避免未经核实直接将其等同于弩矢（P05）。

### 插盾箭

`Shield.Stick` 从盾网格边界选择附着点，将箭的姿态转到盾空间，取得随机 stamped sprite，交给盾上的 `SpriteStamperRoot`。`maxCount=4`；其 trunk 是盾的子节点，因此随盾动画移动。`SpriteStamper` 将盖章数据写入自己的 Mesh / MeshRenderer，容量满后循环覆盖；不是每支箭永久保留一个活动飞行物，也未见写回盾牌纹理（P06）。

现有规格的“盖章”一词可作概括，但实现应参照这里的独立盖章网格证据，不据“盾的精灵”字面推断 RenderTexture 贴图烘焙。

## 6. 特效：已确认的样本与尚未关联的类

### 复用入口不等于统一渲染实现

`ReusableParticle` 自身无额外逻辑，继承 `ReusableEffect`。后者第一次请求时缓存一个实例，收集子效果接口和 ParticleSystem，关闭循环 / 自动播放；后续播放触发 `onPlay` 事件和接口。`ReusableEffectManager` 在设置岛屿时预建配置数组中的效果（F01）。这是可直接验证的复用方式；没有证明每类效果都有固定数量 GameObject 的通用池。

| 样本 | 已直接核验的内容 | 尚缺的链段 |
|---|---|---|
| BloodSlash / BloodSplat / BloodSplash / HitEffect | Unity ParticleSystem；UVModule 未启用，非已启用的序列图动画；使用 SquareParticle 等材质（F02） | Material 后的 Shader / Texture（R04） |
| SmallSplash | Drops 与 Circle 两个发射器；渲染模式数值 0 / 2；箭入水时生成（F03） | 引擎枚举解释与 Shader / Texture |
| SwordClash | 两种渲染模式 1 / 0，Spark 材质，未启用 UV 序列模块（F04） | 引擎枚举解释与 Shader / Texture |
| DustParticles | 256 槽、1024 顶点的自定义 Mesh，循环写生成位置 / 方向 / 时间（F06） | 场景实际材质和 shader 展开 |
| BloodDecal | SpriteStamp、Bloodstains 系列 Sprite、BloodStain 材质（F07） | 贴地 / 投射方式、shader、纹理及与涂色体积的并用关系 |
| WindSmoke | 源码中的 8×8 位置纹理和 8 个四顶点面片、网格与纹理复用（F08） | 哪个实际烟对象引用此类及材质 |
| WindParticleSystem | 源码中的双 RenderTexture 位置模拟、Graphics.Blit、网格绘制（F09） | 它是否用于所问的火 / 烟对象 |

方向性方面，`ReusableEffect.PlayAt` 可接 forward，带随机 up 构造姿态；`BloodSlash` 又有 `Directional` 子对象。生成方向是世界姿态信息，粒子渲染朝向是另一层配置；本次未核查 Unity 2018 对 `m_RenderMode/m_RenderAlignment` 枚举的完整定义，也未观察旋转镜头后的画面，故不声称已证实全部方向性特效的旋转表现（F05）。

火焰的实际组件链完全未闭环；烟只读到候选源码类。不能将类名存在、相似 shader 文件名或原规格的概括代替实际引用证据（F10）。

## 7. 地形：停止前的有限进展

`Module` 包含 `cells`，cell 内有 edges、8 个 corners、6 个内部面 / 可导航面标志，并保存 MeshFilter 和方向变体集合（T01）。这证明数据表示包含几何与可导航侧信息，不能仅凭字段推出全部模块固定占一个 cell。

已定位 `ModuleProcessor`、`MeshMerger/MeshMerger2`、`NavigationManager/NavigationMesh`；检索见 `SoftenMesh`、`SoftNormals/VoxelsNormals` 及草 / 崖面过滤等符号。**检索到符号不证明它在发行场景启用**。停止前未完成调用链、序列化配置与材质引用，因此不新增以下结论（T02）：

- “约 935”究竟是 Mesh 资产数、逻辑模块数、方向变体数，及其统计口径。
- 模块面的兼容签名、旋转 / 镜像许可、权重和失败恢复。
- 运行时是否修改实际轮廓、是否焊接位置、如何平滑法线、哪些硬边保留。
- 草岩过渡的真实材质链及几何 / 遮罩分工。
- 导航三角形、视觉地表、碰撞及几何软化的对应关系。

没有据此判定原规格的地形结论错误，也没有将其重新标为本次 `LOCAL_CONFIRMED`。

## 8. 交 Lead 的复核与后续缺口

本轮需要决定的只有已触发的升级项：是否接受将 §2.2 拆成“CPU Billboard：有 0.1 滞回”和“已查士兵身体 GPU 路径：零阈值镜像”，并授权继续补完取证。该决定不要求更换引擎或改生产代码。

恢复后优先补主 Camera 引用闭环、身体 `_GAME_ON` 启用生命周期及其他平台分支，再补剑 / 重型箭称谓、装备深度、火烟与贴花的完整引用链，最后完成地形统计与导航 / 视觉对应关系。复杂平原、灯塔、城镇、城堡的适用性和 Godot 架构判断属于后续决策 / 原型；本次证据不能替代这些实验，也没有写入技术选型文件。

无截图、无性能数据、无原作运行观察；本轮仅验证文档存在、改动边界及 Markdown 差异。详见 [T48 交付报告](../../reports/agents/T48.md)。
