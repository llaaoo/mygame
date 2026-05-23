class_name SignalReceiver
extends Node
## 信号接收者接口 — 任何可被 Switch/PressurePlate 驱动的对象
## 子类覆写 receive_signal(signal_id)
##
## 标准信号 ID:
##   "activate"   — 激活（开门、启动机关）
##   "deactivate" — 取消激活（关门、停止机关）
##   "toggle"     — 切换状态


var _callback: Callable


func set_callback(cb: Callable) -> void:
	_callback = cb


func receive_signal(signal_id: String) -> void:
	if _callback.is_valid():
		_callback.call(signal_id)
