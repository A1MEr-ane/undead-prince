extends "res://proto/siege/perf/results/t73/baseline_source/siege.gd"
## 压力探针仅跳过胜负结算；自然局完整执行正式状态机。

func resolve_outcome() -> void:
	if str(args.get("perf_natural", "false")) == "true":
		super.resolve_outcome()
