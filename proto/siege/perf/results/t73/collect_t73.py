from pathlib import Path
import json
import hashlib
import statistics

ROOT=Path.cwd()
OUT=ROOT/'proto/siege/perf/results/t73'

def read(name): return json.loads((OUT/name).read_text())
def tagged(name,prefix):
    lines=[s[len(prefix):] for s in (OUT/name).read_text().splitlines() if s.startswith(prefix)]
    assert len(lines)==1,(name,lines)
    return json.loads(lines[0])

def log_check(name):
    for line in (OUT/name).read_text().splitlines():
        if line.startswith('ERROR: Condition "ret != noErr"'): continue
        assert not ('SCRIPT ERROR' in line or 'Parse Error' in line or line.startswith('ERROR:') or 'ObjectDB instances leaked' in line),(name,line)

before=read('before-sim/summary.json')
after=read('after-sim/summary.json')
lookup=lambda r:(r['scenario'],r['units_target'])
a={lookup(r):r for r in after}
for r in read('after-reinforce-reviewed/summary.json'): a[lookup(r)]=r
ref={lookup(r):r for r in before}
for name in ('before-march-recheck/summary.json','before-march-500-recheck/summary.json'):
    for r in read(name): ref[lookup(r)]=r
assert len(a)==len(ref)==36
comparisons=[]
for old in before:
    key=lookup(old); new=a[key]
    assert ref[key]['battle_hash']==new['battle_hash'],('ESCALATE battle state',key)
    fields=('active','spawned','casualties','won','victory_method','cave_transits','dispatches','combat_events','breach_sample','topology_events')
    for field in fields:
        assert old[field]==new[field],('ESCALATE metric',key,field,old[field],new[field])
    comparisons.append({'scenario':key[0],'units':key[1],'samples':new['samples'],
      'before_ms':old['sim_ms'],'after_ms':new['sim_ms'],
      'speedup_p50':round(old['sim_ms']['p50']/new['sim_ms']['p50'],3),
      'first_before_ms':old['first_sim_ms'],'first_after_ms':new['first_sim_ms'],
      'all_before_ms':old['all_sim_ms'],'all_after_ms':new['all_sim_ms'],
      'battle_hash_equal':True,'battle_hash':new['battle_hash'],
      'flow_relaxed_cells_before':old['flow_relaxed_cells'],'flow_relaxed_cells_after':new['flow_relaxed_cells']})
reg=read('regression-reviewed.json')
assert reg['pairs']==reg['equal_battle_results']==12
for r in reg['rows']:
    assert list(r['differences'])==['params_sha256'],('unexpected natural diff',r)
directors=[]
for units in (100,200,300,500):
    b=tagged(f'director-before-{units}.log','DIRECTOR_BENCH ')
    c=tagged(f'director-after-{units}.log','DIRECTOR_BENCH ')
    for i in range(3):
        assert b['repeats'][i]['decisions']==c['repeats'][i]['decisions'],('ESCALATE director',units,i)
        assert b['repeats'][i]['ordered']==c['repeats'][i]['ordered']>0
    directors.append({'units':units,'before':b,'after':c,
      'median_before_ms':statistics.median(v['director_ms'] for v in b['repeats']),
      'median_after_ms':statistics.median(v['director_ms'] for v in c['repeats'])})
natural=read('natural-summary.json')
classic_lines=[s[6:] for s in (OUT/'natural-driver-classic.log').read_text().splitlines() if s.startswith('SIEGE ')]
assert len(classic_lines)==1
classic_hash=hashlib.sha256(classic_lines[0].encode()).hexdigest()
assert classic_hash==next(r['result_hash'] for r in natural if r['strategy']=='main_gate' and r['label']=='after'), 'ESCALATE natural driver differs from classic CLI'
for strategy in ('main_gate','waves'):
    b=next(r for r in natural if r['strategy']==strategy and r['label']=='before')
    c=next(r for r in natural if r['strategy']==strategy and r['label']=='after')
    assert b['battle_hash']==c['battle_hash'],('ESCALATE natural7',strategy)
    assert b['ended_at']>0 and c['ended_at']>0,('unfinished natural',strategy)
    for field in ('won','victory_method','ended_at','spawned','casualties'):
        assert b[field]==c[field],('ESCALATE natural metric',strategy,field)
repeat=read('natural-waves-repeat.json')
for row in repeat:
    assert row['state_hash']==next(r['state_hash'] for r in natural if r['label']=='after' and r['strategy']=='waves'), 'ESCALATE waves repeat/phase state changed'
phase=read('phase-summary.json')
for r in phase:
    assert r['state_hash']==a[lookup(r)]['state_hash'],('phase divergence',lookup(r))
audit=[]
for strategy,seed in (('main_gate',1),('waves',2)):
    name=f'audit-{strategy}-{seed}-final.log'
    log_check(name)
    lines=[v for v in (OUT/name).read_text().splitlines() if v.startswith('T73_AUDIT PASS')]
    assert len(lines)==1 and 'finished_equal=true' in lines[0],(name,'missing PASS')
    audit+=lines
for count in (100,200,300,500):
    for label in ('before','after'): log_check(f'director-{label}-{count}.log')
log_check('flow-before.log');log_check('flow-after.log')
log_check('verify-reviewed/perf_features.log');log_check('verify-reviewed/features.log')
assert 'T73_BYTE_REPLAY PASS pairs=12' in (OUT/'verify-reviewed.log').read_text()
flow_b=tagged('flow-before.log','FLOW_BENCH ')
flow_c=tagged('flow-after.log','FLOW_BENCH ')
for b,c in zip(flow_b['results'],flow_c['results']):
    assert (b['fields'],b['relaxed_cells'])==(c['fields'],c['relaxed_cells'])
result={'task_id':'T73','baseline_revision':'a058daa4737fab9cfc2cd12775bf487c1e8b498f',
 'environment':before[0]['environment'],'scope':'headless simulation; 2 fixed steps per sample',
 'window_measurement':{'available':False,'attempts_seconds':[600.01,20.01],'retry':read('render-check.json')},
 'comparisons':comparisons,'pressure_battle_equal_pairs':36,'natural_regression':reg,
 'natural_driver_classic_sha256':classic_hash,'flows':{'before':flow_b,'after':flow_c},'director':directors,'natural_seed7':natural,
 'natural_waves_repeat':repeat,'phase_after':phase,'audits':audit,
 'baseline_march_100_recheck_ms':ref['march',100]['sim_ms'],
 'first_grid_iteration_ms':{str(u):read(f'iteration-1/after-sim/raw/march_{u}_sim.json')['sim_ms'] for u in (100,200,300)},
 'self_repairs':3,'validation':'tools/verify/proto_siege.sh --out proto/siege/perf/results/t73/verify-reviewed'}
artifact=ROOT/'proto/siege/perf/T73-results.json'
artifact.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('T73_COLLECT PASS pressure=36/36 natural=12/12 seed7=2/2 byte_replay=12/12 director_decisions=12/12 phase=2/2 audit=2/2')
print('artifact',artifact)
print('| 场景 | 100 | 200 | 300 | 500 |')
print('|---|---:|---:|---:|---:|')
for scenario in ('march','multi','melee','gate','breach','reinforce','cave','dawn','idle'):
    cells=[]
    for units in (100,200,300,500):
        r=next(r for r in comparisons if (r['scenario'],r['units'])==(scenario,units))
        cells.append(f"{r['before_ms']['p50']:.2f} → {r['after_ms']['p50']:.2f}")
    print('| '+scenario+' | '+' | '.join(cells)+' |')
for d in directors: print('DIRECTOR',d['units'],d['median_before_ms'],d['median_after_ms'])
for r in natural: print('NATURAL',r['strategy'],r['label'],r['sim_ms'])
