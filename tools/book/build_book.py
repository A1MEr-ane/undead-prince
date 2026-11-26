#!/usr/bin/env python3
"""生成开发者设定集（book/index.html + book/img/*.jpg）。

只读 docs/canon 与 art/；缺图时自动跳过对应插图。
用法：python3 -I tools/book/build_book.py
"""
import json, os, subprocess, collections, html, shutil

R = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(R, 'book')
IMG = os.path.join(OUT, 'img')
CANON = os.path.join(R, 'docs', 'canon')
os.makedirs(IMG, exist_ok=True)
E = html.escape
used = []


def img(src_rel, name, width=1600):
    """把 art 下的 png 压成 jpg 放进 book/img，返回相对路径；源不存在返回 None。"""
    src = os.path.join(R, src_rel)
    if src_rel.startswith('art/chars/'):
        # 立绘优先用正在重画的 A 风格版本（T58/T59 工作目录），合并后自动回落到仓库内的文件
        for wt in ('亡魂王子-t58', '亡魂王子-t59'):
            alt = os.path.join(os.path.dirname(R), wt, src_rel)
            if os.path.exists(alt) and os.path.isdir(os.path.join(os.path.dirname(alt), 'v1')):
                src = alt
                break
    if not os.path.exists(src):
        return None
    dst = os.path.join(IMG, name + '.jpg')
    if not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(src):
        subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '78',
                        '-Z', str(width), src, '--out', dst],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    used.append(name + '.jpg')
    return 'img/' + name + '.jpg'


def fig(src_rel, name, cap, cls='', width=1600):
    p = img(src_rel, name, width)
    if not p:
        return ''
    return f'<figure class="{cls}"><img src="{p}" alt="{E(cap)}" loading="lazy"><figcaption>{E(cap)}</figcaption></figure>'


camp = json.load(open(os.path.join(CANON, 'C', 'CAMPAIGN-DATA.json')))
ovr = json.load(open(os.path.join(R, 'data', 'campaign', 'overrides.json')))['sites']
N = {n['id']: n for n in camp['nodes']}
out_adj = collections.defaultdict(list); in_adj = collections.defaultdict(list)
for a, b in camp['edges']:
    out_adj[a].append(b); in_adj[b].append(a)


def bfs(s, adj):
    d = {s: 0}; q = [s]
    for x in q:
        for y in adj[x]:
            if y not in d:
                d[y] = d[x] + 1; q.append(y)
    return d


fb, tb = bfs('bay', out_adj), bfs('sunhold', in_adj)
REGIONS = [
    ('Greywake', '灰潮外岛', '石板、深色海岩、木码头与风化渔屋', ['bay', 'wreck', 'light', 'oar', 'lantern', 'west', 'northrelief', 'saltmarket']),
    ('Pilot Waters', '引航水域', '浅色低石构、礁岛、灯标与海事纪念物', ['pilot', 'kings', 'roads']),
    ('Pinewatch', '松卫边境', '冷铁、方正石砌、松木与有秩序的军事防御', ['gate', 'yard', 'watchskerry', 'foundry']),
    ('Grainlands', '金穗三角洲', '赭色庄稼、砖木磨坊及河道工程', ['mill', 'harvest', 'granary', 'lock', 'titheford', 'barleyhall']),
    ('Saltmarsh', '盐沼海缘', '芦苇、湿石、灰绿水体与古老葬仪几何', ['silent', 'graves', 'abbey', 'funeral', 'reedcross', 'hospice', 'sealquay']),
    ('Old Realm', '旧王领', '风化王朝石构、寒冷废墟与旧王室色彩遗存', ['archive', 'old', 'orchard', 'banners', 'winterpalace', 'oldbridge']),
    ('Sunhold', '永昼盆地', '白石、金色八芒日纹与克制的红摄政标记', ['merchant', 'lion', 'provision', 'procession', 'sunhold']),
]
ENV_ID = {n: 'ENV-' + n.upper() for n in N}
TYPE_ZH = {'hub': '据点', 'battle': '战斗', 'lore': '剧情', 'boss': '首领', 'entry': '王都入口', 'capital': '王都'}
BOSS = {'gate': '休元帅', 'granary': '阿格尼丝女伯爵', 'abbey': '安塞姆大主教', 'saltmarket': '罗德里克伯爵（新增）', 'sunhold': '沃尔特宰相（新增，宫城战）'}

# ---------- 人物 ----------
CHARS = [
    ('王室与渡魂人', [
        ('CHAR-PRINCE-UNDEAD', '埃德蒙', '亡魂王子 · 26 岁殒命', '在白昼王城长大，更爱旧王果园。十二岁随休学剑，二十二岁独立指挥舰队。签过一道没有期限的紧急征发令，发现拖欠成惯例后要求审计，议会借他果决的名声设局。沉船时拒绝独自乘艇逃生，最后的承诺是带大家回家。勇敢、不耐拖延、爱美；容易以为善意足以赋予自己决策权。', '“难得他们说了句实话。”'),
        ('CHAR-QUEEN', '埃莉诺', '女王 · 20 岁', '比兄长小六岁。少时就会读宫廷账目，用小册子记粮价、任命和来客的承诺；在果园更喜欢修好输掉的小船。议会给了她加冕礼、受控的宫廷和哥哥叛国的版本。她怀疑有隐瞒，却不知全部阴谋。有合法王位，有自己的意志，不是待救的物件。', '“如果你是为王位而来，我宁愿亲耳听你说。”'),
        ('CHAR-FERRYMAN', '渡魂人', '提灯的摆渡者', '没有可靠的出生、死亡或本名。维持死者渡海的秩序，不能执行活人的法律。在舰队亡魂被送进秘印之前截下了他们，把回溯交给能抵达王都的人。知道被抹去的历史，却不是全知；检查绳结、留一处空座、善用沉默。身份到最后也不完全揭开。', '“获胜从来就不是我们契约的条件。”'),
        ('CHAR-KING', '阿尔德里克', '先王 · 55 岁病逝', '疼爱子女，却相信国家机密不该让他们知道。年轻时想把秘印限定于自愿供奉，严冬里签下截留获罪者灵魂的例外，此后一再推迟复审。没有参与谋杀，但要为自己隐瞒的政策负责。只通过肖像、政令和回忆出场。', ''),
        ('CHAR-MOTHER', '贝阿特丽斯', '王后 · 已故', '沿海贵族出身，七年前因病自然去世，兄妹当时十九岁和十三岁。她的死不是阴谋，是这个家庭第一次失去。', ''),
        ('CHAR-PRINCE', '生前的埃德蒙', '沉船之前', '同一张脸的生者版本，用于回忆和果园、军旗等剧情插画。', ''),
    ]),
    ('沉钟湾旧部（增益提供者）', [
        ('CHAR-CAPTAIN', '伯纳德', '卫队长 · 阵线', '出身折桨港引航员家庭，兄弟死于海上后从军。教会王子怎样跟水手说话而不必让人立正。仍给不再生锈的头盔上油，记录没有应答的士兵。成长在于敢于反对错误命令。', '“请准许我提出异议，殿下。我恐怕得好好说上一通。”'),
        ('CHAR-STITCHER', '玛蒂尔达', '军医 · 缝补', '在苍白圣堂系统的施济院受训，因为舰船军医更自主而参军。把亡灵身体看作不可思议的医学机会，别人谈永生，她争论缝线长度。第一具缝合巨人是码头工加兰。学会分清患者意愿和军官要求。', '“别动。死了也不是乱扭的理由。”'),
        ('CHAR-MAGE', '奥斯温', '宫廷法师 · 冥火', '苍白圣堂档案学徒出身，研究残余冥火。最后一次航行前因调查受限的葬仪账目被处死，灵魂被拘留尚未消耗。渴望平反，欣赏秘印的工程，厌恶它的管理者，认为更小的非消耗系统值得研究。', '“制度骇人，工程精妙。我反对把这两句话混为一谈。”'),
        ('CHAR-BUGLER', '皮普', '小号手 · 号令', '长灯岛渔民之子，为军饷和看看王都入伍。舰队是他的笑话第一次有听众的地方，死时还在受损甲板上吹号。喜欢亡灵航行，怕安静；想自己决定什么时候吹散队号。', '“全员到齐，殿下。就是有几位分成了好几块。”'),
    ]),
    ('五名仇人（首领）', [
        ('CHAR-EARL', '罗德里克', '伯爵 · 港税与航运 · 盐市港', '家族借船给王室换来税收特权。王子的审计威胁这种安排，他出卖航线、支付佣兵、禁止搜救。待人和气，记得船长生日，却把所有义务当成可谈的交易。', ''),
        ('CHAR-COUNTESS', '阿格尼丝', '女伯爵 · 粮约与征发 · 万谷仓', '歉收时继承河谷领地，她建的仓储系统确实减少了损耗。如今优先保障权贵和王都仓库，借王子的征发令从别处取粮，明知而扣下舰队补给。比起丑闻更怕饥荒。', ''),
        ('CHAR-ARCHBISHOP', '安塞姆', '大主教 · 葬仪与秘印 · 苍白圣堂', '曾是诚恳的施济院教士，见过严冬里的燃料短缺，为截留获罪者的例外辩护。拟定了虚假判决，批准转送舰队灵魂。害怕承认罪行会毁掉每位教士的公信力。', ''),
        ('CHAR-MARSHAL', '休', '元帅 · 军令与增援 · 锁海之门', '凭军功晋升的边境军官，王子的剑术老师，曾教他保全士兵比守阵更重要时要撤退。后来相信审计会分裂舰队，明知而封湾、阻止救援。', ''),
        ('CHAR-CHANCELLOR', '沃尔特', '宰相 · 印玺与继承 · 永昼王城', '书记官出身，组织了相互依赖的权力联盟。安排了致命的赈粮任务和随后的摄政。愿意给王子个人平反，却仍把普通水手列为叛徒。认为女王有用而非无能，所以限制她。', ''),
    ]),
]

# ---------- 结局 ----------
ENDINGS = [
    ('E00', '再沉灰海', '—', '—', '—', 'I', '王都定局之前的任何失败。知识保留，决定与死亡清空。首次失败有专属插画。', '“看来还没到家。”'),
    ('E01', '灰烬王冠', '坚持', '保留', '延续', 'I', '王冠复归，亡灵卫队站在王座前，军团仍受命令束缚。王子发现胜利能恢复身份，却不能让生前生活回来。首胜只能是它。', '“那么，陛下。一切都如你所愿吗？”'),
    ('E02', '空冠', '坚持', '解除', '延续', 'II', '王子保留王冠，卫队室空出一些位置。部分家属拿到拖欠的补偿，隐秘的灵魂供给仍在继续。', '“你让士兵走了。我倒是注意到，城里依然亮着。”'),
    ('E03', '冥夜摄政', '承认', '保留', '延续', 'II', '妹妹坐在王座上，王子立于其侧。兄长的军权可能损害他本想恢复的妹妹的自主。', '“你把王冠留给了她。王国呢？”'),
    ('E04', '归途', '承认', '解除', '延续', 'II', '皮普吹散队号，兄妹在港口度过平常的一个下午，这座城却不知何为傍晚。一户人家仍在等失踪者解脱。', '“弟兄们都到家了。除了那些我们还没找到的人。”'),
    ('E05', '长夜之王', '坚持', '保留', '终止', 'III', '第一次日落照在亡灵君主和仍在工作的码头上。囚魂被释放，军事强制仍在。', '“太阳落下了。你的命令却还没有结束。”'),
    ('E06', '凡世王国', '坚持', '解除', '终止', 'III', '国王在烛光下签冬季预算。王国靠常规制度和自愿者过冬，名字指的是制度回归凡世，不是王子变回活人。', '“一个需要蜡烛的王国。想想那笔开销吧。”'),
    ('E07', '最后的守望', '承认', '保留', '终止', 'III', '首轮冬备结束时兄妹在岸边相见，王子承诺守望。可选的远期推演只作为可能的未来。', '“漫长的守望。希望你还记得问问谁愿意留下。”'),
    ('E08', '第一次日落', '承认', '解除', '终止', 'III', '妹妹看着白色城墙失去光彩，自愿留下的人保持自由。王国面对未知的寒冬。情感上最完整的一条，但不是道德密码。', '“很美的一场日落。可惜没有别人记得。”'),
]
KNOW = [
    ('K01', '谋杀计划', '地方证据或宰相宫廷档案', '揭露摄政阴谋'),
    ('K02', '女王意志', '家书、童年信物或直接会面', '可承认女王而不强制退位'),
    ('K03', '军誓强制', '军团对白，集结时保底解释', '解除强制服役'),
    ('K04', '截留亡魂', '盐沼档案、送葬货运或王都名册', '理解燃料来源'),
    ('K05', '初始盟约', '沉水藏书阁或宫廷盟约副本', '理解永昼起源'),
    ('K06', '秘印停机', '奥斯温解读 K04/K05 与通道图，后期保底', '本轮终止永昼'),
    ('K07', '自愿解约', '亲历 E05–E08 后由渡魂人解释', '真结局准备'),
]
TIMELINE = [
    ('数代前', '内海统一，海防设施与纪念物建成。'),
    ('数代前', '大寒冬。王室与教会建立第一枚秘印，旧王庭地位下降。'),
    ('阿尔德里克早期', '试图把献祭限于自愿者；后来的寒冬里批准获罪者例外，复审一再拖延。'),
    ('约 26 年前', '埃德蒙出生。'),
    ('约 20 年前', '埃莉诺出生。'),
    ('约 14 年前', '休开始教王子剑术。'),
    ('约 9 年前以前', '果园竞舟，兄妹修好木船。'),
    ('约 9 年前', '王子首次巡防，妹妹十一岁。'),
    ('约 7 年前', '王后贝阿特丽斯病逝。'),
    ('约 4 年前', '王子独立指挥舰队。'),
    ('最后航行前', '奥斯温被处死，亡魂被拘留尚未消耗。'),
    ('上一冬', '王子签发紧急征发令。'),
    ('随后春季', '王子要求审计；议会策划致命改航，预拟判决。'),
    ('锚点前', '赈粮船队被改航，沉于沉钟湾；禁止搜救，判决发布。'),
    ('沉船后', '国王病逝，女王加冕；渡魂人截下亡魂，唤醒军团（含奥斯温）。'),
    ('T0 锚点', '固定的首次出征开场，五名共谋者都还活着。每次回溯都回到这里。'),
]
BOONS = [
    ('伯纳德', '阵线', '破阵', '敌人盾牌失效、格挡取消', '盾击 · 方阵推进 · 冲阵 · 号旗落点 · 归队', '铁律：破阵的敌人被击退时，撞到的同伴也破阵'),
    ('玛蒂尔达', '缝补', '缝线', '死后尸体立即可招魂，多一次重组', '取样 · 急救台 · 拖尸 · 缝合弹 · 改良缝线', '杰作：每场第一个阵亡的亡魂以巨人身份站起'),
    ('奥斯温', '冥火', '冥燃', '持续掉血，死亡时点燃周围', '余烬刃 · 引燃 · 火径 · 精密计算 · 残余利用', '工程精妙：冥燃叠到 3 层时引爆击飞'),
    ('皮普', '号令', '惊惶', '士气变差，死亡时传给同伴', '走调 · 集结号 · 冲锋号 · 回声 · 点卯', '散队号：号点时所有惊惶敌人后退一步'),
    ('渡魂人', '渡海（稀有）', '沉', '击退多退一截，落水必死', '留一处空座 · 检查绳结 · 你求的是一条路 · 上一轮的头衔 · 收潮', '不占槽位，每个都有代价'),
]


def section(id_, num, title, body, lead=''):
    lead_html = f'<p class="lead">{lead}</p>' if lead else ''
    return f'<section id="{id_}"><header class="sec-head"><span class="sec-num">{num}</span><h2>{E(title)}</h2></header>{lead_html}{body}</section>'


parts = []
TITLE_ZH = os.environ.get('BOOK_TITLE_ZH', '亡者归航')
TITLE_EN = os.environ.get('BOOK_TITLE_EN', 'FLEET OF THE FALLEN')
cover = img('art/chars/CHAR-PRINCE-UNDEAD/hero.png', 'cover', 1400) or img('art/style/prince_hero.png', 'cover', 1400)
parts.append(f"""<header class="cover">
  <div class="cover-text">
    <p class="eyebrow">开发者设定集 · 含剧透 · 2026 年 11 月</p>
    <h1>{E(TITLE_ZH)}</h1>
    <p class="sub">{E(TITLE_EN)}</p>
    <p class="cover-lead">舰队沉在沉钟湾，王都为叛徒败亡敲响钟声，妹妹戴上了王冠。如今每到入夜，一支沉没的舰队从海面浮起。</p>
    <dl class="facts">
      <div><dt>玩法</dt><dd>夜间登陆攻城：用冥火召唤亡灵军团，天亮前攻下要塞</dd></div>
      <div><dt>结构</dt><dd>沿航道向王都远征的肉鸽；失败或终局都会回溯，只有王子记得</dd></div>
      <div><dt>结局</dt><dd>王都三次决定，八种成功结局，另有一个真结局</dd></div>
    </dl>
  </div>
  {f'<img class="cover-art" src="{cover}" alt="亡灵王子埃德蒙">' if cover else ''}
</header>""")

# 01 核心
pillars = [('复仇', '五名仇人各有利益，不靠魔法也有完整的谋杀因果。'), ('亲情', '妹妹是合法女王，有自己的意志，不是待救的物件。'),
           ('军团', '旧部有人想冒险，有人只想安息；服役和强制是两回事。'), ('永昼', '王都的神迹和全国的冬恩，都靠消耗灵魂维持。')]
parts.append(section('premise', '01', '核心', '<div class="pillars">' + ''.join(f'<div class="pillar"><h3>{a}</h3><p>{b}</p></div>' for a, b in pillars) + '</div>'
    + fig('art/story/ART_B02_04/scene.png', 'story-flag', '最后的军旗：沉船之前，王子拒绝独自登上救生艇', 'wide'),
    '王子被自己的王国陷害而死。渡魂人在沉船之间点亮一盏灯，与他立下契约：他可以回来，率领旧部和亡魂向王都进军。每次失败或尘埃落定，契约都会把他带回同一个夜晚。'))

# 02 世界
world = """<div class="cols">
<div><h3>灵魂力量</h3><p>灵魂承载人格和记忆。人死后会留下一点残余冥火，它在没有日光的夜里能凝成形体，日出就散。王子的军团就由这些冥火召唤而成：战场上的士兵是死者的回声，没有人格，天亮即散；真正有名有姓的只有沉钟湾的旧部。</p>
<p>强行抽取灵魂本身，能得到多得多的力量，代价是那个人被一点点磨掉，直到彻底消失。</p></div>
<div><h3>两个太阳</h3><p>自然的太阳照常升落，世界有昼夜和四季。王都上空另有一轮苍白的环形光盘，那是太阳教会的神迹"永昼之日"，长明不熄，却没有热度。人造的光不算白天，所以王都在夜里同样可以攻打。</p>
<p>永昼之日熄灭的那一天，王都会第一次迎来完整的黑夜，看见满天星。</p></div>
</div>
<h3>神迹与秘密</h3>
<div class="tbl-wrap"><table class="tbl"><thead><tr><th>百姓看到的</th><th>真相（只有少数人知道）</th></tr></thead><tbody>
<tr><td>王都的永昼是神与王室立约的证明</td><td>光由秘印抽取的灵魂转化而来</td></tr>
<tr><td>冬天教士从王都请回圣火，点燃各地教堂的圣火龛，这是神恩</td><td>圣火是灵魂之火；运圣火的船，回程装的是被截留的死者</td></tr>
<tr><td>教会主持葬仪，登记亡者</td><td>部分葬仪把死者送往秘印</td></tr>
<tr><td>亡灵是天谴</td><td>亡灵只是夜里凝成形体的残余冥火</td></tr>
</tbody></table></div>
<p class="note">全国都靠圣火过冬，但分得极不均匀：王都最暖，外岛和贫村只有一点。终止永昼意味着所有圣火龛在这个冬天之后不再点燃，代价由整个王国承担。</p>
<h3>王子与他的军团</h3>
<p>王子白天可以行走、谈判、出现在宫廷里，只是没有战斗的力量。他的军团只在夜里存在：日出时回声散去，旧部和舰队亡魂沉回船壳，整支舰队在水下随他航行，入夜再浮起。回溯只是王子和渡魂人之间的契约，与永昼无关。</p>
<h3>宗教与王朝</h3>
<p>太阳教会原本是水手的信仰，敬拜为航行指方向的太阳；王朝起于海上，旧纹章是星与浪。大寒冬时教会造出永昼，王室改用白底金八芒日以示立约。旧王庭的遗迹上刻的仍是星。</p>"""
parts.append(section('world', '02', '世界', world))

# 03 人物
def card(cid, name, role, line, small=False):
    hero = img(f'art/chars/{cid}/hero.png', f'{cid}-hero', 700 if small else 900)
    art = f'<img src="{hero}" alt="{E(name)}" loading="lazy">' if hero else '<div class="noart">立绘待定</div>'
    return f'<article class="pcard{" small" if small else ""}">{art}<h4>{E(name)}</h4><p class="role">{E(role)}</p><p>{E(line)}</p></article>'
core = [('CHAR-PRINCE-UNDEAD', '埃德蒙', '亡灵王子', '勇敢、爱美、不耐拖延。他签过一道伤害了百姓的冬季征发令，也在沉船时拒绝独自逃生。容易把忠诚当成无限服从。'),
        ('CHAR-QUEEN', '埃莉诺', '女王，20 岁', '会读宫廷账目，掌管各地冬恩的分配，却不知道圣火从哪里来。被议会控制，但不糊涂。'),
        ('CHAR-FERRYMAN', '渡魂人', '提灯的摆渡者', '只渡人，不碰圣火，也不能熄灭永昼。知道被抹去的历史，却不是全知。身份到最后也不完全揭开。')]
crew = [('CHAR-CAPTAIN', '伯纳德', '卫队长 · 整体战力', '“请准许我提出异议，殿下。”'), ('CHAR-STITCHER', '玛蒂尔达', '军医 · 兵种质变', '“死了也不是乱扭的理由。”'),
        ('CHAR-MAGE', '奥斯温', '法师 · 冥火', '“制度骇人，工程精妙。”'), ('CHAR-BUGLER', '皮普', '号手 · 指挥', '“就是有几位分成了好几块。”')]
foes = [('CHAR-EARL', '罗德里克伯爵', '盐市港', '他的船队运送圣火，也运送死者'), ('CHAR-COUNTESS', '阿格尼丝女伯爵', '万谷仓', '靠冬恩分配控制粮区，怕的是饥荒'),
        ('CHAR-ARCHBISHOP', '安塞姆大主教', '苍白圣堂', '秘印的守护者，伪造了叛国判决'), ('CHAR-MARSHAL', '休元帅', '锁海之门', '王子的剑术老师，相信没有冬恩就会内乱'),
        ('CHAR-CHANCELLOR', '沃尔特宰相', '永昼王城', '组织阴谋，要的是联盟延续')]
ch = '<div class="pgrid three">' + ''.join(card(*c) for c in core) + '</div>'
ch += '<h3>沉钟湾旧部：增益的来源</h3><div class="pgrid four">' + ''.join(card(*c, small=True) for c in crew) + '</div>'
ch += '<h3>五名仇人：每条航线一个首领</h3><div class="pgrid five">' + ''.join(card(cid, n, f'首领据点 · {site}', why, small=True) for cid, n, site, why in foes) + '</div>'
parts.append(section('cast', '03', '人物', ch))

# 04 攻城
siege = '<p>每场战斗都是一个夜晚：五分钟，从入夜打到破晓。王子手里没有预先编好的军队，只有<b>冥火</b>。</p>'
siege += '''<div class="cols">
<div><h3>冥火</h3><p>开局有一笔储备，随夜色回复，有储存上限，越接近黎明回复越快。召唤每种亡灵各有费用，长按就能连续部署；冥火也用来施放狂化、虚弱、轰击和集结。多召一队兵，还是留着施一个法术，是每一刻的取舍。</p></div>
<div><h3>自主作战</h3><p>亡灵落地后自己选目标、走路线、交战。玩家决定的是在哪里、什么时候、投入多少、投入什么。集中突破、两翼夹击、佯攻、分批增援，都来自空间、时间和兵力的分配，而不是专门的按钮。</p></div>
</div>'''
siege += fig('art/style/battle_mock.png', 'battle', '局内画面样张：小兵带墨线外轮廓，亡灵是青绿边光，守军是暖金边光', 'wide')
siege += '''<h3>一个夜晚的三段</h3>
<div class="tbl-wrap"><table class="tbl"><thead><tr><th>阶段</th><th>目的</th><th>可能的行动</th></tr></thead><tbody>
<tr><td><b>初夜</b></td><td>准备战场</td><td>刺客切掉高地弓兵，巨人打开薄弱墙段，小股佯攻牵制</td></tr>
<tr><td><b>中段</b></td><td>扩大战果</td><td>趁守军调动留下的空档绕侧，开辟第二战线</td></tr>
<tr><td><b>黎明前</b></td><td>兑现构筑</td><td>冥火回复和亡灵战力到达顶峰，主力总攻</td></tr>
</tbody></table></div>
<p class="note">这不是脚本。守军的伤亡不补充，城墙的破口不修复，所以每一波都给下一波留下条件；构筑成型后，也可能一波就解决原本需要层层准备的防线。</p>
<h3>守军会调兵</h3>
<p>守军依托地形和要塞防守：盾兵守阵线，枪兵卡隘口，弓兵占高地，骑兵是机动预备队，神职者有范围攻击。各战区有最低驻防，威胁大了会派兵支援，但派兵有延迟、行军要真实走路。玩家可以看到援军的去向，并利用它离开后留下的空缺。</p>
<h3>胜利</h3>
<p>全歼守军；或者攻占主据点，迫使剩余守军跑去港口坐船撤离。天亮前两者都没做到，就是失败。</p>
<h3>地形与要塞</h3>
<p>自然地形没有血量，不可破坏，只决定通路和交战宽度。城墙和城门是主要的进攻思路，可以局部打破。大路适合主力展开，小路可以绕行，山洞是捷径。暗影刺客之类的兵种可以无视部分地形。</p>'''
parts.append(section('siege', '04', '夜袭攻城', siege, '玩家站在进攻方。参考的是 Bad North 的微缩战场和低操作调度，以及部落冲突式的原子化部署和皇室战争式的资源回复。'))

# 05 构筑
UNITS6 = [('盾骷髅', '生存流', '最大生命 + 持续回血 + 减伤反伤：几只骷髅就能在正门拖住大批守军'),
          ('暗影刺客', '渗透流', '特殊通行 + 潜行 + 击杀后重新潜行：越过常规通路，连续处理弓兵和神职者'),
          ('巫妖', '控制流', '致盲 + 眩晕 + 控制扩散：让挤在城门的盾枪守军无法反击'),
          ('狂战士', '濒死爆发流', '跳劈 + 不屈 + 击杀回血：构筑成型后连续跳入敌阵'),
          ('死灵骑士', '冲锋流', '冲锋 + 践踏 + 再次突进：在开阔大路上追击转移中的守军'),
          ('缝合巨人', '破城流', '强化耐久 + 范围震荡 + 破墙：前期打开侧墙，给主力更宽的交战面')]
bd = '<p>远征前期要靠多兵种配合，后期可以围绕一两个兵种形成近乎"轮椅"的质变；混编、冥火经济、指挥法术也都是成型路线。</p>'
bd += '<div class="tbl-wrap"><table class="tbl"><thead><tr><th>兵种</th><th>方向</th><th>强化组合示例</th></tr></thead><tbody>' + ''.join(f'<tr><td><b>{a}</b></td><td>{b}</td><td>{c}</td></tr>' for a, b, c in UNITS6) + '</tbody></table></div>'
bd += '''<h3>强化从哪来</h3><div class="tbl-wrap"><table class="tbl"><thead><tr><th>旧部</th><th>方向</th></tr></thead><tbody>
<tr><td><b>伯纳德</b></td><td>整体战力：前排、生存、全军属性</td></tr>
<tr><td><b>奥斯温</b></td><td>冥火：储备、上限、回复、召唤费用，以及直接伤害法术</td></tr>
<tr><td><b>皮普</b></td><td>指挥：狂化、虚弱、集结、调度</td></tr>
<tr><td><b>玛蒂尔达</b></td><td>特定兵种的质变</td></tr>
<tr><td><b>渡魂人</b></td><td>改变规则的馈赠，例如"开局冥火加倍，但夜里不再回复"，或"以战养战：只靠击杀获得冥火"</td></tr>
</tbody></table></div>'''
bd += fig('art/ui/ui_hub.png', 'hub', '沉钟湾据点：五位旧部站在浮起的旗舰甲板上', 'wide')
bd += '<p class="note">跨越回溯保留的是王子学到的东西：指挥和召唤的技艺、打过的战场的敌情、对每位旧部的默契、走过的航路和证据的下落。士兵本身每一夜重新召唤。</p>'
parts.append(section('build', '05', '构筑', bd))

# 06 航路
geo = fig('art/style/ui_chart.png', 'chart', '航海图：颜色是难度，紫色纹章是首领据点', 'wide')
geo += '<p>王冠海上 38 个地点、四座王都城门。一局沿一条航道向王都突破，五到七场攻城，中间穿插剧情地点；攻下一处只是打开下一段航道，不经营领土。<b>路越短越难</b>：前几局要绕远路攒构筑、收集证据，王子记住的敌情越多，后面越能走捷径。</p>'
geo += '''<div class="tbl-wrap"><table class="tbl"><thead><tr><th>阶段</th><th>典型战场</th><th>规模</th></tr></thead><tbody>
<tr><td>前期</td><td>渔村、灯塔、哨站</td><td>2–3 个战区，木栅或无墙</td></tr>
<tr><td>中期</td><td>港口、城镇、修道院</td><td>4 个战区，城墙、城门、高地、山洞</td></tr>
<tr><td>后期</td><td>要塞关口、永昼王城</td><td>5–6 个战区，两道防线</td></tr>
</tbody></table></div>
<p>战场按战区组织：海岸、高地、外城、主堡……每个战区有一个精心构图的固定视角，玩家在总览图上切换战区。王都的夜战最特别：永昼之日把整座城照得通明，亡灵失去夜色的掩护，守军的弓兵看得更远。</p>'''
parts.append(section('atlas', '06', '王冠海航路', geo))

# 07 兵种
un = fig('art/units/undead_lineup.png', 'undead', '亡魂大军', 'wide') + fig('art/units/kingdom_lineup.png', 'kingdom', '王国守军：活人，白金日光', 'wide') + fig('art/units/chibi_lineup.png', 'chibi', '局内的 Q 版小兵：2.3 头身，墨线描边，阵营边光', 'wide')
if un:
    parts.append(section('units', '07', '兵种', un))

# 08 结局
end = """<p>王都章节里，王子要作出三次决定，分开在三个场景里，每次都会改变接下来的战斗和剧情。</p>
<ol class="flow"><li><b>王权</b>：坚持自己的王位，或承认妹妹的王冠</li><li><b>军誓</b>：保留对旧部的强制，或只留自愿者</li><li><b>永昼</b>：让秘印继续消耗灵魂，或终止它，让王都和全国的圣火一起熄灭</li></ol>"""
end += '<div class="tbl-wrap"><table class="tbl endings"><thead><tr><th></th><th>结局</th><th>王权</th><th>军誓</th><th>永昼</th><th>渡魂人</th></tr></thead><tbody>'
for eid, name, a, b, c, st, after, q in ENDINGS:
    end += f'<tr><td class="eid">{eid}</td><td><b>{name}</b></td><td>{a}</td><td>{b}</td><td>{c}</td><td class="q">{E(q)}</td></tr>'
end += '</tbody></table></div>'
ec = ''
for eid, name in [('E01', '灰烬王冠'), ('E03', '冥夜摄政'), ('E04', '归途'), ('E08', '第一次日落'), ('TRUE', '最后的渡航')]:
    p_ = img(f'art/story/ENDING-{eid}/ending.png', f'ending-{eid}', 1400)
    if p_:
        ec += f'<figure><img src="{p_}" alt="{name}" loading="lazy"><figcaption>{eid if eid != "TRUE" else "真结局"} · {name}</figcaption></figure>'
if ec:
    end += f'<div class="gallery wide2">{ec}</div>'
end += '<p>开放顺序：第一次胜利只能是 E01；之后开放 E02–E04；查清秘印之后开放 E05–E08。"第一次日落"指的是永昼之日熄灭后，王都第一次迎来真正的黑夜和满天星。</p>'
end += '<h3>真结局</h3><p>亲眼看到秘印释放囚魂之后，王子才第一次明白束缚可以被放下。解约的权利一直在他手里。下一次胜利后，他安排好继承、解除军誓，熄灭渡魂人的灯，渡过灰海。演职员表，存档封存。</p>'
end += '<blockquote class="big">渡魂人：这盏灯一旦熄灭，就再没有回来的岸了。<br>埃德蒙：我知道。<br>渡魂人：那就上船吧。</blockquote>'
parts.append(section('endings', '08', '结局', end))

# 09 美术
art = fig('art/style/ui_dialogue.png', 'dialogue', '对话界面：半身立绘与暗化的场景', 'wide')
art += '''<ul class="bullets">
<li><b>人物立绘</b>：精炼墨线。成熟比例，墨线只在形体转折处出现，一个自然的主光源、大面积暗部、细轮廓光，构图像海报。</li>
<li><b>结局插画</b>：史诗厚涂，强调光影、权力关系和氛围；画面上不放任何文字。</li>
<li><b>光的语言</b>：亡灵是青绿冥火，王国是白金日光，永昼之日是苍白无热的光盘。</li>
<li><b>UI</b>：深墨蓝漆面加一条细金线，克制，只有一种材质；转场只用三种：涨潮、钟声、提灯。</li>
<li><b>局内</b>：3D 微缩地形加朝向镜头的小兵精灵，每个战区一个固定视角。</li>
</ul>'''
parts.append(section('art', '09', '美术方向', art))
TOC = [('premise', '核心'), ('world', '世界'), ('cast', '人物'), ('siege', '攻城'), ('build', '构筑'), ('atlas', '航路')] + ([('units', '兵种')] if un else []) + [('endings', '结局'), ('art', '美术')]
toc = ''.join(f'<a href="#{a}">{b}</a>' for a, b in TOC)

CSS = open(os.path.join(os.path.dirname(__file__), 'book.css')).read()
page = f'''<title>{E(TITLE_ZH)}设定集</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Serif+SC:wght@600;900&family=Noto+Sans+SC:wght@400;500;700&family=Cinzel:wght@600&display=swap">
<style>{CSS}</style>
<nav class="toc">{toc}</nav>
<main>{''.join(parts)}
<footer><p>依据 docs/canon（ABC R1）、docs/roguelike.md、docs/boons.md、docs/art-style.md 生成。名称与数值均为暂定。</p></footer></main>
'''
open(os.path.join(OUT, 'index.html'), 'w').write(page)
for f in os.listdir(IMG):
    if f not in used:
        os.remove(os.path.join(IMG, f))
tot = sum(os.path.getsize(os.path.join(IMG, f)) for f in os.listdir(IMG))
print(f'book/index.html，图片 {len(set(used))} 张，{tot/1e6:.1f} MB')
