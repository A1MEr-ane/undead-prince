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
cover = img('art/style/prince_hero.png', 'cover', 1400)
parts.append(f"""<header class="cover">
  <div class="cover-text">
    <p class="eyebrow">开发者设定集 · 含剧透</p>
    <h1>{E(TITLE_ZH)}</h1>
    <p class="sub">{E(TITLE_EN)}</p>
    <p class="cover-lead">舰队沉在沉钟湾，王都为叛徒败亡敲响钟声，妹妹戴上了王冠。直到有人在沉船之间点亮一盏灯。</p>
    <dl class="facts">
      <div><dt>玩法</dt><dd>反向 Bad North：玩家是进攻方，登岛攻城</dd></div>
      <div><dt>结构</dt><dd>肉鸽航路，每局失败或终局都回溯；只有王子记得</dd></div>
      <div><dt>结局</dt><dd>王都三次决定，八种成功结局，另有真结局</dd></div>
    </dl>
  </div>
  {f'<img class="cover-art" src="{cover}" alt="亡魂王子埃德蒙">' if cover else ''}
</header>""")

# 01 一句话与支柱
pillars = [('复仇', '五名仇人各有利益，不靠魔法也有完整的谋杀因果。'), ('亲情', '妹妹是合法女王、有自己意志，不是待救的物件。'),
           ('军团', '旧部有人想冒险，有人只想安息；服役和强制是两回事。'), ('永昼', '王都的白昼靠消耗灵魂维持；终止它代价真实。')]
parts.append(section('premise', '01', '核心', '<div class="pillars">' + ''.join(f'<div class="pillar"><h3>{a}</h3><p>{b}</p></div>' for a, b in pillars) + '</div>'
    + fig('art/story/ART_B02_04/scene.png', 'story-flag', '最后的军旗：沉船之前', 'wide'),
    '王子被自己的王国陷害而死，由渡魂人唤醒，率旧部亡魂攻回王都。每一局从沉钟湾出发；失败或终局，渡魂人都会把他带回原点。'))

# 02 世界的秘密
world = """<div class="cols">
<div><h3>永昼与秘印</h3><p>王都白昼王城没有黑夜，教会说这是神与王室的盟约。真相是一枚秘印：大寒冬时它靠残余冥火和少数自愿者救了城，此后宫廷一代代扩大需求，现在要定期消耗完整的灵魂。舰队的亡魂原本也要被送进去，渡魂人抢先截下了他们。</p></div>
<div><h3>回溯</h3><p>锚点在沉船、国王病逝、妹妹加冕之后。只有王子记得经历过的历史，渡魂人知情，其他人全部重置。保留的是知识、航路和习得的技艺；军队、增益、文书和王都的决定都会清空。胜利不是解约条件，王子要到很后面才明白怎样不再回来。</p></div>
</div>"""
parts.append(section('world', '02', '世界的秘密', world))

# 03 人物（只放核心）
def card(cid, name, role, line, small=False):
    hero = img(f'art/chars/{cid}/hero.png', f'{cid}-hero', 700 if small else 900)
    if not hero and cid == 'CHAR-PRINCE-UNDEAD':
        hero = img('art/style/prince_hero.png', 'cover', 1400)
    art = f'<img src="{hero}" alt="{E(name)}" loading="lazy">' if hero else '<div class="noart">立绘待定</div>'
    return f'<article class="pcard{" small" if small else ""}">{art}<h4>{E(name)}</h4><p class="role">{E(role)}</p><p>{E(line)}</p></article>'
core = [('CHAR-PRINCE-UNDEAD', '埃德蒙', '亡魂王子', '勇敢、爱美、不耐拖延。他签过一道伤害了百姓的征发令，也在沉船时拒绝独自逃生。容易把忠诚当成无限服从。'),
        ('CHAR-QUEEN', '埃莉诺', '女王，20 岁', '会读宫廷账目，被议会控制但不糊涂。死者归来并不让她的王位失效。'),
        ('CHAR-FERRYMAN', '渡魂人', '提灯的摆渡者', '维持死者渡海的秩序，知道被抹去的历史，却不是全知。身份到最后也不完全揭开。')]
crew = [('CHAR-CAPTAIN', '伯纳德', '卫队长 · 阵线', '“请准许我提出异议，殿下。”'), ('CHAR-STITCHER', '玛蒂尔达', '军医 · 缝补', '“死了也不是乱扭的理由。”'),
        ('CHAR-MAGE', '奥斯温', '法师 · 冥火', '“制度骇人，工程精妙。”'), ('CHAR-BUGLER', '皮普', '号手 · 号令', '“就是有几位分成了好几块。”')]
foes = [('CHAR-EARL', '罗德里克伯爵', '盐市港', '出卖航线，护的是航运特权'), ('CHAR-COUNTESS', '阿格尼丝女伯爵', '万谷仓', '扣下补给，怕的是饥荒'),
        ('CHAR-ARCHBISHOP', '安塞姆大主教', '苍白圣堂', '伪造判决，怕的是教会失信'), ('CHAR-MARSHAL', '休元帅', '锁海之门', '王子的剑术老师，封湾不救'),
        ('CHAR-CHANCELLOR', '沃尔特宰相', '永昼王城', '组织阴谋，要的是联盟延续')]
ch = '<div class="pgrid three">' + ''.join(card(*c) for c in core) + '</div>'
ch += '<h3>沉钟湾旧部：增益的来源</h3><div class="pgrid four">' + ''.join(card(*c, small=True) for c in crew) + '</div>'
ch += '<h3>五名仇人：每条走廊一个首领</h3><div class="pgrid five">' + ''.join(card(cid, n, f'首领据点 · {site}', why, small=True) for cid, n, site, why in foes) + '</div>'
parts.append(section('cast', '03', '人物', ch))

# 04 航路
geo = fig('art/style/ui_chart.png', 'chart', '航海图：颜色是难度，紫色纹章是首领据点', 'wide')
geo += '<p>38 个地点、75 条有向航线、四座王都城门。一局只走一条路。<b>路越短越难</b>：前几局要绕远路攒战力、收集证据；王子记住的敌情越多，后面越能走捷径。</p>'
show = [('bay', '沉钟湾：据点，每局从这里出发'), ('ENV-GATE', '锁海之门：休元帅的双塔与铁链'), ('ENV-ABBEY', '苍白圣堂：钟楼与圣光'), ('ENV-SUNHOLD', '永昼王城：白石与不落的日光')]
g = ''
for eid, cap in show:
    e = eid if eid.startswith('ENV-') else 'ENV-BAY'
    p = img(f'art/env/{e}/site.png', f'site-{e}', 1200)
    if p:
        g += f'<figure><img src="{p}" alt="{E(cap)}" loading="lazy"><figcaption>{E(cap)}</figcaption></figure>'
if g:
    geo += f'<div class="gallery">{g}</div>'
geo += '<p class="mat">七个地区：灰潮外岛 · 引航水域 · 松卫边境 · 金穗三角洲 · 盐沼海缘 · 旧王领 · 永昼盆地</p>'
parts.append(section('atlas', '04', '王冠海航路', geo))

# 05 玩法
gp = '<ol class="flow"><li>沉钟湾：和旧部说话，用残响学技艺</li><li>航海图选路，下一站的奖励提前可见</li><li>登岛：部署 → 即时战斗 → 夺旗</li><li>王都：三次决定穿插在战斗之间</li><li>结局或失败 → 回溯</li></ol>'
gp += fig('art/style/ui_boons.png', 'boons', '增益选择：伯纳德的三张卡', 'wide')
gp += '<div class="tbl-wrap"><table class="tbl"><thead><tr><th>旧部</th><th>改写的战场动作</th><th>给敌人的状态</th></tr></thead><tbody>' + ''.join(
    f'<tr><td><b>{a}</b></td><td>{b}</td><td>{c}：{d}</td></tr>' for a, b, c, d, *_ in BOONS) + '</tbody></table></div>'
gp += '<p class="note">增益只改看得见的事：推、撞、烧、落水、尸体起身。每局带走的是知识和技艺：敌情记忆让打过的岛变简单，旧部默契让增益更稳。</p>'
parts.append(section('play', '05', '玩法', gp))

# 06 兵种
un = fig('art/units/undead_lineup.png', 'undead', '亡魂大军：死亡也会触发东西', 'wide') + fig('art/units/kingdom_lineup.png', 'kingdom', '王国守军：活人，白金日光', 'wide')
if un:
    parts.append(section('units', '06', '兵种', un))

# 07 结局
end = """<ol class="flow"><li><b>王权</b>：坚持王位，或承认妹妹</li><li><b>军誓</b>：保留强制，或只留自愿者</li><li><b>永昼</b>：延续，或让太阳落下（第三阶段才开放）</li></ol>"""
end += '<div class="tbl-wrap"><table class="tbl endings"><thead><tr><th></th><th>结局</th><th>王权</th><th>军誓</th><th>永昼</th><th>渡魂人</th></tr></thead><tbody>'
for eid, name, a, b, c, st, after, q in ENDINGS:
    end += f'<tr><td class="eid">{eid}</td><td><b>{name}</b></td><td>{a}</td><td>{b}</td><td>{c}</td><td class="q">{E(q)}</td></tr>'
end += '</tbody></table></div>'
end += '<p>开放顺序：第一次胜利只能是 E01；之后开放 E02–E04；查清秘印后开放 E05–E08。</p>'
ec = ''
for eid, name in [('E01', '灰烬王冠'), ('E08', '第一次日落'), ('TRUE', '最后的渡航')]:
    p = img(f'art/story/ENDING-{eid}/ending.png', f'ending-{eid}', 1200)
    if p:
        ec += f'<figure><img src="{p}" alt="{name}" loading="lazy"><figcaption>{name}</figcaption></figure>'
if ec:
    end += f'<div class="gallery">{ec}</div>'
end += '<h3>真结局</h3><p>亲眼看到秘印释放囚魂之后，王子才知道契约也能由自己放弃。下一次胜利后，他安排好继承、解除军誓，渡过灰海。演职员表，存档封存。</p>'
end += '<blockquote class="big">渡魂人：这盏灯一旦熄灭，就再没有回来的岸了。<br>埃德蒙：我知道。<br>渡魂人：那就上船吧。</blockquote>'
parts.append(section('endings', '07', '结局', end))

# 08 美术
art = fig('art/style/ui_dialogue.png', 'dialogue', '叙事层：手绘厚涂与粗墨线', 'wide') + fig('art/style/battle_mock.png', 'battle', '局内：同样的小兵，加墨线和阵营边光', 'wide')
art += '<p>亡魂是青绿冥火，王国是白金日光。局内保留 3D 地形加精灵的做法，只改渲染。</p>'
parts.append(section('art', '08', '美术方向', art))

TOC = [('premise', '核心'), ('world', '世界'), ('cast', '人物'), ('atlas', '航路'), ('play', '玩法')] + ([('units', '兵种')] if un else []) + [('endings', '结局'), ('art', '美术')]
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
