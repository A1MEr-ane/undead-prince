from pathlib import Path
import subprocess
import time
import sys
root=Path.cwd();out=root/'proto/siege/perf/results/t73'
while 'T73_EXTRA PASS' not in (out/'extra.log').read_text(): time.sleep(2)
cmd=['godot','--headless','--path','.', '--log-file',str(out/'natural-driver-classic.engine.log'),'proto/siege/siege.tscn','--','--strategy=main_gate','--seed=7']
with (out/'natural-driver-classic.log').open('w') as stream:
    p=subprocess.run(cmd,cwd=root,stdout=stream,stderr=subprocess.STDOUT)
if p.returncode: sys.exit(p.returncode)
import importlib.util,json
spec=importlib.util.spec_from_file_location('probe',root/'proto/siege/perf/run_perf.py')
probe=importlib.util.module_from_spec(spec);spec.loader.exec_module(probe)
rows=[]
for phase in (False,True):
    row=probe.run_one('godot','waves',0,'sim',4500,phase=phase,timeout=600,out_dir=out/'natural-waves-repeat',extra_args=['--perf_natural=true','--strategy=waves','--seed=7'])
    rows.append(row)
    print('WAVES_RECHECK phase='+str(phase)+' ok='+str(row.get('ok'))+' sim='+str(row.get('sim_ms')),flush=True)
    if not row.get('ok'): sys.exit(1)
(out/'natural-waves-repeat.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
for name in ('collect_t73.py','write_report.py'):
    p=subprocess.run(['python3',str(out/name)],cwd=root)
    if p.returncode: sys.exit(p.returncode)
print('T73_ARTIFACTS_READY',flush=True)
