#!/usr/bin/env python3
"""把 STYLE.txt + characters.json/units_ui.json 拼成逐张的最终提示词，写到 art/prompts/rendered/。
提示词由 Claude 编写；执行者只能原样使用，不得改写。"""
import json, os
D = os.path.dirname(os.path.abspath(__file__))
STYLE = '\n'.join(l for l in open(os.path.join(D, 'STYLE.txt')).read().strip().splitlines() if not l.startswith('STYLE ('))
OUT = os.path.join(D, 'rendered'); os.makedirs(OUT, exist_ok=True)
REF = "\nREFERENCE IMAGES: attached images show the approved line weight, flat shadow treatment, rim light and palette. Match their rendering exactly; do NOT copy their composition or characters unless told to."
c = json.load(open(os.path.join(D, 'characters.json')))
n = 0
for ch in c['characters']:
    for kind, tpl in c['templates'].items():
        if kind == 'hero' and ch.get('reuse_hero'):
            continue
        p = tpl.replace('{STYLE}', STYLE)
        for k in ('subject', 'pose', 'props', 'expressions', 'rim'):
            p = p.replace('{' + k + '}', ch.get(k, ''))
        open(os.path.join(OUT, f"{ch['id']}__{kind}.txt"), 'w').write(p + REF + '\n'); n += 1
u = json.load(open(os.path.join(D, 'units_ui.json')))
for item in u['units']:
    open(os.path.join(OUT, f"UNITS__{item['id']}.txt"), 'w').write(item['prompt'].replace('{STYLE}', STYLE) + REF + '\n'); n += 1
print(n, 'prompts')
