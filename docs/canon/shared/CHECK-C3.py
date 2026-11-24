from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
d=json.loads((root/'C/CAMPAIGN-DATA.json').read_text()); n={v['id']:v for v in d['nodes']}; e=[tuple(x) for x in d['edges']]
assert len(n)==39 and len(e)==len(set(e))==75
assert all(a in n and b in n for a,b in e)
paths={}
for st in range(1,5):
    ids={i for i,v in n.items() if v['stage']<=st}; es=[(a,b) for a,b in e if a in ids and b in ids]; adj={i:[b for a,b in es if a==i] for i in ids}; ps=[]
    def visit(i,path):
        assert i not in path
        path=path+[i]
        if i=='sunhold': ps.append(path); return
        assert adj[i], (st,i)
        for j in adj[i]: visit(j,path)
    visit('bay',[]); assert set().union(*map(set,ps))==ids; paths[st]=ps
    assert all(p[:2]==['bay','wreck'] for p in ps)
    assert all(any((a,b) in list(zip(p,p[1:])) for p in ps) for a,b in es)
    print(st,len(ids),len(es),len(ps),min(map(len,ps))-2,max(map(len,ps))-2)
for a in json.loads((root/'B/SIDE-STORY-INDEX.json').read_text())['arcs']:
    for b in a['beats']:
        assert any(b['node'] in p for p in paths[b['stage']])
for a,b,st in [('oar','lantern',1),('gate','yard',1),('light','oar',1),('mill','granary',1),('graves','abbey',2),('archive','sunhold',3),('orchard','sunhold',2)]:
    assert any(a in p and b in p and p.index(a)<p.index(b) for p in paths[st])
print('PASS topology + side-story locations and ordered pairs')
