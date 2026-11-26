from pathlib import Path
import importlib.util
import subprocess
import json
import sys
import time
root=Path.cwd()
out=root/'proto/siege/perf/results/t73'
while 'T73_CONTINUE PASS' not in (out/'continue.log').read_text():
    time.sleep(2)

def run(cmd,name):
    print('START '+name,flush=True)
    with (out/name).open('w') as stream:
        p=subprocess.run(cmd,cwd=root,stdout=stream,stderr=subprocess.STDOUT)
    print('END '+name+' exit='+str(p.returncode),flush=True)
    if p.returncode: sys.exit(p.returncode)

run(['python3','proto/siege/perf/compare_t73.py','--samples','300','--modes','sim','--scenarios','reinforce','--units','100,200,300,500','--out',str(out/'after-reinforce-reviewed')],'after-reinforce-reviewed.log')
run(['tools/verify/proto_siege.sh','--out',str(out/'verify-reviewed')],'verify-reviewed.log')
run(['python3','proto/siege/perf/regression_t73.py',str(out/'before-natural/results.jsonl'),str(out/'verify-reviewed/results.jsonl'),'--out',str(out/'regression-reviewed.json')],'regression-reviewed.log')
run(['python3','proto/siege/perf/compare_t73.py','--baseline','--samples','300','--modes','sim','--scenarios','march','--units','500','--out',str(out/'before-march-500-recheck')],'before-march-500-recheck.log')

for count in (100,200,300,500):
    for label in ('before','after'):
        flags=['--baseline'] if label=='before' else []
        run(['godot','--headless','--path','.', '--log-file',str(out/f'director-{label}-{count}.engine.log'), '--script','proto/siege/perf/director_bench.gd','--','--strategy=manual','--perf_mode=sim','--perf_scenario=reinforce',f'--perf_units={count}',*flags],f'director-{label}-{count}.log')
spec=importlib.util.spec_from_file_location('probe',root/'proto/siege/perf/run_perf.py')
probe=importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
rows=[]
for strategy in ('main_gate','waves'):
    for label in ('before','after'):
        probe.SCENE='proto/siege/perf/results/t73/baseline_source/perf/perf_runner.tscn' if label=='before' else 'proto/siege/perf/perf_runner.tscn'
        row=probe.run_one('godot',strategy,0,'sim',4500,timeout=600,out_dir=out/f'natural-{label}',extra_args=['--perf_natural=true',f'--strategy={strategy}','--seed=7'])
        row['label']=label
        rows.append(row)
        (out/'natural-summary.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
        print('NATURAL '+label+' '+strategy+' '+str(row.get('sim_ms')),flush=True)
        if not row.get('ok'): sys.exit(1)
probe.SCENE='proto/siege/perf/perf_runner.tscn'
rows=[]
for scenario in ('march','melee'):
    row=probe.run_one('godot',scenario,300,'sim',300,phase=True,timeout=600,out_dir=out/'phase-after')
    rows.append(row)
    print('PHASE '+scenario+' ok='+str(row.get('ok')),flush=True)
    if not row.get('ok'): sys.exit(1)
(out/'phase-summary.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
for strategy,seed in (('main_gate',1),('waves',2)):
    run(['godot','--headless','--path','.', '--log-file',str(out/f'audit-{strategy}-{seed}-final.engine.log'),'--script','proto/siege/perf/audit_t73.gd','--',f'--strategy={strategy}',f'--seed={seed}'],f'audit-{strategy}-{seed}-final.log')
print('T73_EXTRA PASS',flush=True)
