class_name Beats
extends RefCounted
## 节拍（规格 3）：每个兵出生时取随机相位；"本帧是否到了某个周期的节拍"
## = floor((t + 相位) / 周期) 是否和上一帧不同。不需要计时器，每个兵天然错开。

var offset := 0.0


## 相位属于战斗逻辑：由主场景的模拟随机源传入，保证同种子可复现。
func _init(rng: RandomNumberGenerator = null) -> void:
	offset = (rng.randf() if rng != null else randf()) * 100.0


func hz(period: float) -> bool:
	var t := AgentState.now + offset
	return floorf(t / period) != floorf((t - AgentState.dt) / period)
