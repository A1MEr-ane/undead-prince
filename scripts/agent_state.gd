class_name AgentState
extends RefCounted
## 分层状态树节点（规格 docs/badnorth-behavior-spec.md 2.2）。
## - 激活一个状态会连带激活所有祖先；互斥状态会顶掉互斥的兄弟
## - 停用一个状态会递归停用所有子孙
## - 状态激活着却没有互斥子状态时触发 on_empty，用来回到默认状态
## - 记录切换时刻，可以问"激活了多久"
## 组件把回调挂到各自的状态上；每帧由根节点 update() 按树序调用激活状态的 on_update。

static var now := 0.0   # 游戏时间（受慢动作影响），由 main 每帧写入
static var dt := 0.0

var name: String
var parent: AgentState
var children: Array[AgentState] = []
var exclusive := false
var active := false
var stamp := 0.0

var on_activate: Array[Callable] = []
var on_deactivate: Array[Callable] = []
var on_change: Array[Callable] = []    # 参数：bool
var on_empty: Array[Callable] = []
var on_update: Array[Callable] = []


func _init(p_name: String, p_parent: AgentState, p_active: bool, p_exclusive: bool) -> void:
	name = p_name
	parent = p_parent
	exclusive = p_exclusive
	stamp = now
	if parent != null:
		parent.children.append(self)
	if p_active:
		set_active(true)


func since() -> float:
	return now - stamp


func set_true() -> void:
	set_active(true)


func set_false() -> void:
	set_active(false)


func set_active(v: bool) -> bool:
	if v == active:
		return false
	_set_internal(v)
	if v:
		_maybe_empty()
	elif parent != null and parent.active:
		parent._maybe_empty()
	return true


func _set_internal(v: bool) -> void:
	if v == active:
		return
	stamp = now
	if v:
		if exclusive and parent != null:
			for s in parent.children:
				if s != self and s.exclusive and s.active:
					s._set_internal(false)
		if parent != null:
			parent._set_internal(true)
		active = true
		for cb in on_activate:
			cb.call()
		for cb in on_change:
			cb.call(true)
	else:
		for c in children:
			c._set_internal(false)
		active = false
		for cb in on_deactivate:
			cb.call()
		for cb in on_change:
			cb.call(false)


func has_active_exclusive_child() -> bool:
	for c in children:
		if c.active and c.exclusive:
			return true
	return false


func _maybe_empty() -> void:
	if active and not has_active_exclusive_child():
		for cb in on_empty:
			cb.call()


## 每帧调用（只对根节点）：先跑自己的更新，再按顺序跑子节点。
func update() -> void:
	if not active:
		return
	for cb in on_update:
		cb.call()
		if not active:
			return
	for c in children:
		c.update()


func path() -> String:
	var s := name
	for c in children:
		if c.active:
			s += "/" + c.path()
			break
	return s
