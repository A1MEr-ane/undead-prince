from pathlib import Path
import importlib.util
import subprocess
import json
import sys
root=Path.cwd()
out=root/'proto/siege/perf/results/t73'

def run(cmd,name):
    print('START '+name,flush=True)
    with (out/name).open('w') as stream:
        p=subprocess.run(cmd,cwd=root,stdout=stream,stderr=subprocess.STDOUT)
    print('END '+name+' exit='+str(p.returncode),flush=True)
    if p.returncode: sys.exit(p.returncode)

spec=importlib.util.spec_from_file_location('probe',root/'proto/siege/perf/run_perf.py')
probe=importlib.util.module_from_spec(spec);spec.loader.exec_module(probe)
r=probe.run_one('godot','march',300,'sim',300,phase=True,timeout=600,out_dir=out/'phase-final-calibration')
(out/'phase-final-calibration.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
old=json.loads((out/'iteration-1/phase/raw/march_300_sim_phase.json').read_text())
print('CALIBRATION p50='+str(r.get('sim_ms'))+' state_equal='+str(r.get('state_hash')==old['state_hash']),flush=True)
if not r.get('ok') or r.get('state_hash')!=old['state_hash']:
    print('ESCALATE: phase calibration battle changed or engine failure',flush=True);sys.exit(1)
run(['tools/verify/proto_siege.sh','--out',str(out/'verify-final')],'verify-final.log')
run(['python3','proto/siege/perf/regression_t73.py',str(out/'before-natural/results.jsonl'),str(out/'verify-final/results.jsonl'),'--out',str(out/'regression-final.json')],'regression-final.log')
run(['python3','proto/siege/perf/compare_t73.py','--samples','300','--modes','sim','--out',str(out/'after-sim')],'after-sim.log')
run(['python3','proto/siege/perf/compare_t73.py','--baseline','--samples','300','--modes','sim','--scenarios','march','--units','100,200,300','--out',str(out/'before-march-recheck')],'before-march-recheck.log')
print('T73_CONTINUE PASS',flush=True)
