class_name Interactable
extends Node
## 可交互对象接口 — 玩家按 E 时触发
## 子类覆写 interact(actor) 定义交互行为
##
## 与 SignalReceiver 正交：
##   Interactable   = 玩家主动交互（按 E）
##   SignalReceiver = 机关信号驱动（开关→门）


var _callback: Callable


func set_callback(cb: Callable) -> void:
	_callback = cb


func interact(actor: Node2D) -> void:
	if _callback.is_valid():
		_callback.call(actor)
