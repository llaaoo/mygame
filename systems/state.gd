class_name State
extends Node

## 状态机状态基类
@warning_ignore("unused_signal")
signal transitioned(state: Node, new_state_name: String)

## 持有该状态的实体（通常是 Player 等 CharacterBody2D）
var entity: Node

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
