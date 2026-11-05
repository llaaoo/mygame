extends State
## The state executes inputs; the controller owns the timed operation.
func enter() -> void:
	entity.velocity = Vector2.ZERO

func exit() -> void:
	if entity.field_work and entity.field_work.is_busy():
		entity.field_work.cancel("操作已中断", false)

func physics_update(_delta: float) -> void:
	if entity.ui_blocked: return
	for action in entity.poll_universal_actions():
		if action.action_type == Action.ActionType.MOVE:
			entity.field_work.cancel("移动：作业取消")
			entity.field_work.close_panel()
			entity.state_machine.transition_to("move")
			return
		entity.resolve_action(action)
		if not entity.field_work.is_busy(): return
