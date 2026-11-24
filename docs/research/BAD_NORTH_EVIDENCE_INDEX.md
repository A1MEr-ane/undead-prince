# Bad North 本地证据索引（T48，部分交付）

**状态：REVIEW_REQUIRED。** 发现与 `docs/badnorth-art-spec.md` §2.2 的适用范围冲突后，按 T48 的 `escalate_if` 停止继续取证。下表保留停止前取得的证据；文件存在检查通过不代表六个系统调查完成。

调查日期：2026-11-25（Asia/Singapore）。版本边界：本地 macOS **Jotunn Edition 2.00.5 / build 36 / Unity 2018.4.0f1 / Mono**，来源见 V01；不外推到其他版本或平台。

所有原作路径相对 `~/Downloads/BadNorth-Unpacked/`。为保持表格可读，使用以下**确定的路径前缀**：

| 前缀 | 展开为 |
|---|---|
| `CS/` | `DecompiledSource/Assembly-CSharp/Voxels/TowerDefense/` |
| `ROOTCS/` | `DecompiledSource/Assembly-CSharp/` |
| `AS/` | `UnityProject/ExportedProject/Assets/` |
| `SH/` | `CompiledShaders/` |

等级：`LOCAL_CONFIRMED` = 直接读到本地字段或行为；`PUBLIC_CONFIRMED` = 已核查的公开来源；`OBSERVED` = 实际运行观察；`HYPOTHESIS` = 推断；`UNKNOWN` = 尚未核实。本次没有上网核验，也没有运行原作，因此没有使用 `PUBLIC_CONFIRMED` 或 `OBSERVED`。

## 精简证据表

每行一个判断；同一行的路径、字段及限制共同界定结论。全部行适用上述同一版本。

| ID | 结论 | 相对路径；类 / 资源；可核验字段或观察 | 等级 |
|---|---|---|---|
| V01 | 本次来源记录为 macOS 2.00.5、build 36、Unity 2018.4.0f1、Mono | `Manifests/provenance.json`：`game.version/build/unity_version/scripting_backend`；`UnityProject/ExportedProject/ProjectSettings/ProjectVersion.txt`：`m_EditorVersion`。版本来源记录已读，未重新校验整包哈希。 | LOCAL_CONFIRMED |
| V02 | 可读对象是发行包恢复产物；着色器文本不是开发者原始源码 | `解包说明.txt`：AssetRipper 2.0.0、规范反编译结果为 ILSpyCmd 9.1；`SH/resources.assets/unnamed__133.shader.txt` 文件头标明不能直接作为有效 shader 编译。 | LOCAL_CONFIRMED |
| C01 | 战斗镜头俯角在初始化时设为 30° | `CS/LevelCamera.cs`：`Awake`、`pitchTransform`；`ROOTCS/Voxels/Constants.cs`：`cameraAngle`。 | LOCAL_CONFIRMED |
| C02 | 缩放操作正交高度 / 宽度，并含选队的尺寸系数 | `CS/LevelCamera.cs`：`orthoHeight`、`UpdateCameraOrtho`、`currentSquadSelectZoom`；`CS/LevelCameraExtensions.cs`：`GetOrthoWidth/SetOrthoWidth`。这里的宽度是完整水平视野，区别于 Unity 的半高参数。 | LOCAL_CONFIRMED |
| C03 | 主镜头投影布尔的引用闭环尚未完成 | `AS/Modules/IslandGameplay.unity`：`LevelCamera` 的 `_camera` 指向 fileID `778`；场景同时存在 `orthographic: 1` 和 `orthographic: 0`，停止前未逐块核对 `778`。不能凭全场景搜索替代对象关联。 | UNKNOWN |
| C04 | 拖动支持任意连续水平增量 | `CS/CameraDragger.cs`：`OnDrag`、`rotationMultiplier`；`CS/LevelCameraExtensions.cs`：`RotateBy`；`AS/Modules/IslandGameplay.unity`：`rotationMultiplier=180`，整屏水平拖动对应 180° 增量。 | LOCAL_CONFIRMED |
| C05 | 非手柄的短按松开可触发分档寻位；长按继续连续旋转 | `CS/CameraController.cs`：`UpdateButtonYaw`、`cameraTapTime=0.175`、`suppressCameraRotateSnap`、`ControllerType.Joystick`；`CS/CameraSeeker.cs`：`SeekToLatch`。 | LOCAL_CONFIRMED |
| C06 | 分档不是强制锁死全局角度，也不是准确停在四个对角线上 | `CS/CameraSeeker.cs`：`numberOfLatches/latchGlobalOffset/latchOvershootDegrees`；`AS/Modules/IslandGameplay.unity` fileID `3330`：4 档、45° 基准、沿输入方向另加 7.5°；该路径以含偏移的目标寻位。 | LOCAL_CONFIRMED |
| C07 | 跨 0° 的分档寻位使用最短角差 | `ROOTCS/SimpleLinearSeeker.cs`：`EMode.angle`、`GetDiff/MoveTowards` 调用 `Mathf.DeltaAngle/MoveTowardsAngle`；`AS/Modules/IslandGameplay.unity` `3330.seeker.mode=1`。 | LOCAL_CONFIRMED |
| C08 | 连续偏航以增量更新四元数；不直接对归一化欧拉角作普通线性插值 | `CS/LevelCamera.cs`：`yaw` getter/setter；`CS/LevelCameraExtensions.cs`：`RotateBy`；`CS/CameraRotator.cs`：`UpdateInternal`。未做跨零运行观测。 | LOCAL_CONFIRMED |
| C09 | 按键偏航使用有限加减速度 | `ROOTCS/SimpleLinearAccelerator.cs`：`Update`；`AS/Modules/IslandGameplay.unity` fileID `3332`：`maxSpeed=230`、`acceleration=1000`、`deceleration=1750`、`minSpeed=5`（角度 / 时间单位）。 | LOCAL_CONFIRMED |
| C10 | 松手惯性同时使用指数衰减与线性减速 | `CS/CameraSpinner.cs`：`BeginSpin/UpdateInternal`；`AS/Modules/IslandGameplay.unity` `3331`：`linearSlowdown=5`、`exponentialSlowdown=0.6`、`maxSpinVelocity=1080`、`minSpinVelocity=0.01`。 | LOCAL_CONFIRMED |
| C11 | 寻位的场景参数不同于 C# 默认值 | `AS/Modules/IslandGameplay.unity` `3330.seeker`：`maxSeekVelocity=920`、`minSeekVelocity=2.5`、`acceleration=4500`、`decelerationDist=25`、`maxError=0.5`；`ROOTCS/SimpleLinearSeeker.cs`：`Update`。 | LOCAL_CONFIRMED |
| C12 | 缩放上限随岛屿雾范围扩大，不能写成固定 22 | `CS/CameraLimiter.cs`：`orthoWidthMax/ResetLevelView`；`AS/Modules/IslandGameplay.unity` `3336.platformSettings`：默认最小宽 10、基准最大宽 22；实际最大值取 `levelWidth` 与配置最大值中较大者，`levelWidth` 来自雾最大半径的两倍。 | LOCAL_CONFIRMED |
| C13 | 缩放另有平台覆盖；本次未解释平台位掩码 | `AS/Modules/IslandGameplay.unity` `3336.platformVariants`：`128→8/15`、`520→12/12`、`1040→12/12`（最小宽 / 基准最大宽）；平台枚举映射未继续调查。 | LOCAL_CONFIRMED |
| C14 | 滚轮按比例改变目标，捏合直接改变视野宽度并限速 | `CS/CameraZoomer.cs`：`ZoomBy/PinchZoom`、`steppedMovementExponent=1.04`、`maxPinchSpeed=1300`；场景 `3333.seeker`：最大速度 60、最小速度 1、加速度 1000、减速距离 3、误差 0.001。 | LOCAL_CONFIRMED |
| C15 | 镜头各路径的时间尺度不同，不能统一说完全不受慢动作影响 | `CS/LevelCameraComponent.cs`：`deltaTime` 上限 0.05；场景 `3329/3330/3331/3332/3333.timeScaleEffect` 分别为 `0/0.2/0.4/0.1/0.4`；`CS/LevelCamera.cs` 的选队过渡独立使用 `Time.unscaledDeltaTime`。 | LOCAL_CONFIRMED |
| B01 | 独立 CPU Billboard 在 LateUpdate 朝向相机水平投影，倾倒时用父节点 up | `CS/Billboard.cs`：`UpdateRotations/LateUpdate`、`parent.up.y` 阈值 0.9、`flatLook`；`CS/CameraController.cs` 的 `Update` 刷新共享方向。 | LOCAL_CONFIRMED |
| B02 | 0.1 滞回确实存在于 CPU Billboard | `CS/Billboard.cs`：`flippable/flipped`、`Flip`、`LateUpdate`；依当前翻转状态改变点积符号，低于 −0.1 时翻转 `localScale.x`。 | LOCAL_CONFIRMED |
| B03 | 已查士兵身体没有挂载上述 CPU Billboard | `AS/GameObject/English_SwordShield.prefab`、`English_Archer.prefab`、`Viking_SwordShield.prefab`：身体为 `SpriteAnimator`，未发现 `Billboard.cs.meta` 的 GUID `1ffe029659e69e8b32f23151554deb2f`；只对这三个样本成立。 | LOCAL_CONFIRMED |
| B04 | 士兵身体运行时改用动态四顶点 MeshRenderer | `CS/SpriteMagic/BatchedSprite.cs`：`Awake/GetMesh/SetScaledUV2`；四个原始顶点在原点，尺寸写 `uv2`，up 写 tangent，生成 MeshRenderer 后禁用原 SpriteRenderer。 | LOCAL_CONFIRMED |
| B05 | 身体朝向与镜像由角色着色器的顶点程序处理；已查分支按点积零阈值切换 | `AS/Material/Colored.mat` → `AS/Shader/Unlit_ColoredCharacter.asset`；`SH/resources.assets/unnamed__133.shader.txt`：`Unlit/ColoredCharacter`、`_GAME_ON` 的 glcore 顶点段（从第 3117 行开始），读取法线、视图矩阵、`in_TEXCOORD1`，零阈值决定横向偏移符号；未见该分支保存上一帧翻转状态。 | LOCAL_CONFIRMED |
| B06 | **升级项：不能将 B02 的 0.1 滞回直接归到 B05 的士兵身体路径** | 仓库 `docs/badnorth-art-spec.md` §2.2 的泛化表述，与 B03–B05 的样本实际引用链冲突。停止后不自行更改该规格，也不把所有其他对象归到同一路径。 | LOCAL_CONFIRMED |
| B07 | 身体 GPU 展开保留变换后的 up；不能把 CPU Billboard 倾倒分支当作身体证据 | `CS/SpriteMagic/BatchedSprite.cs`：`SetScaledUV2`；`SH/resources.assets/unnamed__133.shader.txt` `_GAME_ON` 顶点段：变换 tangent、与相机方向构成横向基，再用 `_CameraUpScale` 补偿。具体击飞旋转连续性尚未运行验证。 | LOCAL_CONFIRMED |
| B08 | 身体与外观纹理在资源及运行时两段关联 | `AS/GameObject/English_SwordShield.prefab`：`SpriteAnimator.sprite/sprite2`；`CS/SpriteMagic/SpriteAnimator.cs`：`SetSprite2/GetMaterialPropertyBlock` 设置 `_PartTex`、用顶点色 RG 记录外观区域；图集链见 R01。 | LOCAL_CONFIRMED |
| E01 | 样本盾牌是独立三维网格 | `AS/GameObject/English_SwordShield.prefab`：`Shield` 的 MeshRenderer / MeshFilter、`m_Mesh` → `AS/Mesh/Weapons_Shield_1.asset`；`CS/Shield.cs`：`Setup/bounds` 读取网格边界。材质链见 R02。 | LOCAL_CONFIRMED |
| E02 | 样本弓是独立三维网格，不能据此推断所有武器 | `AS/GameObject/English_Archer.prefab`：`Bow` → `AS/Mesh/Archer_Bow_Short_1.asset`；`Viking_Archer.prefab` → `AS/Mesh/Archer_Bow_Viking.asset`；二者材质均为 `Palette.mat`。剑是否完全在身体图内尚未核实。 | LOCAL_CONFIRMED |
| E03 | 盾挂点随动画变换，身体帧与盾曲线可同时驱动 | `AS/GameObject/English_SwordShield.prefab`：`BounceAnim/ShieldAimer/ShieldAnim/Shield`；`AS/AnimationClip/Swordsman_Attack.anim`：`path` 指向 `BounceAnim/ShieldAimer/ShieldAnim`，并含身体对象曲线。未把 `m_SampleRate=60` 误报为身体贴图换帧率。 | LOCAL_CONFIRMED |
| E04 | 身体与装备存在独立绘制队列及三维深度关系，但完整遮挡机制未闭环 | `AS/Material/Colored.mat`：`m_CustomRenderQueue=2040`；`Palette.mat`：2061；`SH/resources.assets/unnamed__133.shader.txt`：`AlphaToMask On/Cull Off`，`_GAME_ON` 有沿视线的小幅顶点偏移。所有平台的 ZTest/ZWrite 与遮挡实测留待复核。 | UNKNOWN |
| P01 | 普通箭实际调用轨迹表，不足以仅凭 ProjectileMath 推断发射路径 | `CS/Archery.cs`：`AimAt/Shoot`；`CS/Ballistics/TrajectoryUtility.cs`：`Sample` 对距离 / 高差网格插值，`GetCost` 用 `Projectile.Update` 模拟；`ROOTCS/ProjectileMath.cs` 及 `CS/HeightBasedProjectileSolver.cs` 另有解析求解工具，尚未追到箭的实际调用。 | LOCAL_CONFIRMED |
| P02 | 飞行箭逐固定步积分重力和线性阻力，并沿速度定向 | `CS/Ballistics/Projectile.cs`：`Update`；`CS/Ballistics/Arrow.cs`：`OnInstantiate`、`projectiling.OnUpdate`，先沿步长射线检测，未命中时积分并 `MoveRotation/MovePosition`。不是无阻力的严格解析抛物线。 | LOCAL_CONFIRMED |
| P03 | 普通箭和重型箭的轨迹配置不同 | `AS/GameObject/TrajectoryUtility.prefab`：`minSpeed=2/maxSpeed=12/drag=2/startOffset=0.1/gravity=9.8`；`TankArcherTrajectory.prefab`：`2/20/0.5/0.3/9.8`；`Viking_TankArcher.prefab` 的 `Archery` 引用后者与 `TankArcher_Arrow.prefab`。 | LOCAL_CONFIRMED |
| P04 | 飞行箭存在精灵驱动的网格绘制路径 | `AS/GameObject/Arrow.prefab`、`TankArcher_Arrow.prefab`：SpriteRenderer + BatchedSprite → `AS/Material/Billboard.mat` → `Unlit/Billboard`；运行时四顶点展开见 B04，图集链见 R03。具体 billboard 轴、平台分支及是否并用其他 Renderer 未继续核对。 | LOCAL_CONFIRMED |
| P05 | 重型箭可穿透并衰减能量，画面长度随速度改变 | `CS/Ballistics/TankArcherArrow.cs`：`RaycastNonAlloc`、`energy/minEnergy`、`OnInstantiate`；沿 Z 缩放后调用 `BatchedSprite.UpdateScale`，未耗尽时继续飞行。这里沿用原符号名，未确认游戏称谓是否为“弩矢”。 | LOCAL_CONFIRMED |
| P06 | 盾上箭通过附着于盾的独立盖章网格保留，容量为 4 | `CS/Shield.cs`：`Stick`、`SpriteStamperRoot.maxCount=4`；`CS/Ballistics/Arrow.cs`：`GetStamp`；`CS/SpriteMagic/SpriteStamperRoot.cs`：`Add`；`SpriteStamper.cs`：`SetupBase/Add/ApplyAndIterate`，新建 MeshRenderer / MeshFilter，按容量循环覆写。未见写回盾牌贴图。 | LOCAL_CONFIRMED |
| F01 | ReusableParticle 是复用效果入口，不足以仅凭名称判断渲染类型 | `CS/ReusableParticle.cs` 继承 `ReusableEffect`；`ReusableEffect.cs`：`GetOrCreate/Setup/PlayAtInternal` 缓存一个实例，关闭子 ParticleSystem 的循环与自动播放，触发 `onPlay` 及接口；`ReusableEffectManager.cs` 预建数组中效果。 | LOCAL_CONFIRMED |
| F02 | 已查血斩 / 血溅 / 命中效果采用 Unity ParticleSystem，未启用序列图模块 | `AS/GameObject/BloodSlash.prefab`、`BloodSplat.prefab`、`BloodSplash.prefab`、`HitEffect.prefab`：ParticleSystem / ParticleSystemRenderer；`UVModule.enabled=0`、`tilesX/tilesY=1`；渲染模式分别含 `0` 与 `2`，材质见 R04。未推断全部血效果相同。 | LOCAL_CONFIRMED |
| F03 | 小水花由两个粒子发射器组合 | `AS/GameObject/SmallSplash.prefab`：`Drops/Circle`、两个 ParticleSystemRenderer，`m_RenderMode=0/2`；两个 UVModule 均未启用；`Arrow.cs` 的 `Splash` 在水位 −0.105 生成。枚举的 Unity 引擎定义未继续核查。 | LOCAL_CONFIRMED |
| F04 | 拼刀火花存在另一种粒子渲染模式 | `AS/GameObject/SwordClash.prefab`：两个 ParticleSystemRenderer 的 `m_RenderMode=1/0`，使用 `AS/Material/Spark.mat`，UVModule 未启用。 | LOCAL_CONFIRMED |
| F05 | 有方向性的生成参数与粒子面向镜头是两个独立层次 | `CS/ReusableEffect.cs`：`PlayAt(Vector3, Vector3)` 按 forward 和随机 up 构造旋转；`BloodSlash.prefab` 含 `Directional` 对象，已查粒子 `m_RenderAlignment=0`。运行时转镜头的形变 / 遮挡未观察。 | LOCAL_CONFIRMED |
| F06 | 尘土使用固定容量自定义网格槽位 | `CS/DustParticles.cs`：`count=256/vertCount=1024`、`SpawnParticles/LateUpdate`，顶点存生成位置、tangent 存方向与风时间，循环替换槽位；其场景材质引用链尚未追完。 | LOCAL_CONFIRMED |
| F07 | 地面血贴花有 SpriteStamp 资源入口 | `AS/GameObject/BloodDecal.prefab`：`SpriteStamp`、`sprites`、SpriteRenderer → `AS/Material/BloodStain.mat`，`Bloodstains_0…3.asset`。尚未读完整投射 / 贴地与材质链。 | LOCAL_CONFIRMED |
| F08 | WindSmoke 源码存在自定义网格和位置纹理方案，但使用对象未确认 | `CS/WindSmoke.cs`：`OnIslandFirstEnter/GetMesh/GetTexture`，8×8 路径位置纹理、8 个四顶点面片、MeshRenderer，`textures/meshes` 复用；实际 prefab / 材质引用未追到。 | LOCAL_CONFIRMED |
| F09 | WindParticleSystem 源码存在双 RenderTexture 位置模拟方案 | `CS/WindParticleSystem.cs`：`Setup/Redraw/ParticleUpdate`、`texture0/texture1/srcMoveMaterial/drawMaterial`；以 Graphics.Blit 更新位置并绘制网格，不能仅凭类名归到火或烟。 | LOCAL_CONFIRMED |
| F10 | 火焰 / 烟的实际 Renderer→Material→Shader→Texture 链仍缺失 | `CS/WindSmoke.cs`、`CS/WindParticleSystem.cs` 仅为候选；停止前未查完引用它们的对象，不能确认全部火烟为粒子池、序列帧或网格。 | UNKNOWN |
| T01 | 模块数据含多 cell、边、角和可导航侧面信息 | `ROOTCS/Voxels/Module.cs`：`cells/meshFilters/orientations`、`Cell.edges/corners/internalSide/navigable`；这只确认数据结构，没有确认兼容求解与实际模块数量。 | LOCAL_CONFIRMED |
| T02 | 地形数量、兼容性、平滑、法线、材质过渡及导航关系尚未形成新结论 | `ROOTCS/Voxels/ModuleProcessor.cs`、`CS/MeshMerger.cs`、`MeshMerger2.cs`、`NavigationManager.cs`、`NavigationMesh.cs` 已定位；仅检索到 `SoftenMesh`、`SoftNormals/VoxelsNormals` 等符号，停止后没有继续读链或统计。不能将检索命中升级为生效机制。 | UNKNOWN |

## 已闭合及未闭合的资源链

以下补充表仍遵循每行一个资源链判断；路径前缀和版本同上。

| ID | Renderer → Material → Shader → Texture / Mesh | 引用证据与边界 | 等级 |
|---|---|---|---|
| R01 | `AS/GameObject/English_SwordShield.prefab` 身体 SpriteRenderer（运行时由 BatchedSprite 替换）→ `AS/Material/Colored.mat` → `AS/Shader/Unlit_ColoredCharacter.asset`；帧 `AS/Sprite/Swordsman0001.asset` → `AS/Texture2D/SpriteAtlasTexture-Sprites (Group 0)-2048x1024-fmt4.png`；外观 `AS/Sprite/PartTex_English.asset` → `AS/Texture2D/PartTex_Median_BlurAlpha.png` | 身体材质 GUID `cc6af5a44f8aacd44827b5d50cb7ebf6`；Shader GUID `ea28076c17f990d449e2c13854ff46a8`；帧图集 GUID `dde22549d047a264ca11637bec13954a`；部位纹理 GUID `f2cef281632543a4ea05fb93edb69084`；运行时 `_MainTex/_PartTex` 覆盖见 `SpriteAnimator/BatchedSprite`，不能只读材质里静态占位纹理。编译文本以 shader 名关联，未再核对原始对象 ID。 | LOCAL_CONFIRMED |
| R02 | `English_SwordShield.prefab` 的 Shield MeshRenderer → `AS/Material/Palette.mat` → `AS/Shader/Unlit_FlatVoxel.asset` → `AS/Texture2D/Palette.png`；MeshFilter → `AS/Mesh/Weapons_Shield_1.asset` | 材质 GUID `32a104b5c0beceb4ab6c45d77c0c8753`，Shader GUID `f7723ea5139cd6849bd8aa84fd804147`，Mesh GUID `b3c1638f8fa058d4aa3887b0767bd6f9`；材质 / 网格引用均已解析 .meta；未读取网格顶点形状。 | LOCAL_CONFIRMED |
| R03 | `AS/GameObject/Arrow.prefab`、`TankArcher_Arrow.prefab` → `AS/Material/Billboard.mat` → `AS/Shader/Unlit_Billboard.asset`；`AS/Sprite/Arrow_0.asset`、`TankArcher_Arrow_0.asset` → `AS/Texture2D/SpriteAtlasTexture-Sprites (Group 2)-1024x2048-fmt12.png` | 材质 GUID `94f4c2e5880f7c14da5c72093c53463c`，Shader GUID `26aa0ec08bf12bf49bae5b6cf1081c62`，图集 GUID `cc145653222e5fb4892cb1102fc30032`；四顶点运行时网格来自 BatchedSprite。轴向展开与印章变体未继续追完。 | LOCAL_CONFIRMED |
| R04 | 血斩 / 血溅 / 小水花 / 命中样本的 ParticleSystemRenderer → `AS/Material/SquareParticle.mat`；`BloodSplash.prefab` 另含 `BloodSplash.mat`；`SwordClash.prefab` → `Spark.mat` | 已解析的材质 GUID 分别为 `207784011d46de443b044d444f58afa2`、`c8ca17f3ef21c8b4c97ecff05f047871`、`754d30382b454bd4fa948a1ec4332912`。停止前尚未读取这些材质的 Shader / Texture 引用，链在 Material 截止。 | UNKNOWN |

## 复核入口

优先复核 B03–B06：对照三个预制体的组件 GUID、`SpriteAnimator` 继承关系、`BatchedSprite.Awake` 和 `Unlit/ColoredCharacter` 的 `_GAME_ON` 顶点分支。该分支可由 `ShaderConstants.cs` 的 `_GAME_ON` 启停符号定位，但本次未完成整个状态切换调用链。

停止后的工作仅为撰写这两份研究文档、交付报告、运行任务卡验证和 Git 提交；未运行原作 / 重建 Unity 工程，未复制原作代码、shader 文本、贴图或模型进入仓库。
