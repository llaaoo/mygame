class_name ActorStatusView
extends VBoxContainer
var compact := false
var context: ActorContext
var stamina_bar: ProgressBar
var stability_bar: ProgressBar
var detail: Label
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for title in ["体力","稳定"]:
		var row:=HBoxContainer.new()
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(row)
		var caption:=FoundationWidgets.label(title,12,true)
		caption.custom_minimum_size.x=34
		caption.autowrap_mode=TextServer.AUTOWRAP_OFF
		row.add_child(caption)
		var bar:=ProgressBar.new()
		bar.custom_minimum_size=Vector2(100,10)
		bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		bar.show_percentage=false
		bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		GameUIStyle.apply_progress(bar,Color("c4ac57") if title=="体力" else Color("9da7b0"),8)
		row.add_child(bar)
		if title=="体力": stamina_bar=bar
		else: stability_bar=bar
	detail=FoundationWidgets.label("",11,true)
	detail.visible=not compact
	add_child(detail)
func _process(_delta: float) -> void:
	visible=context!=null
	if not context or not context.actions: return
	stamina_bar.max_value=context.actions.stamina.maximum
	stamina_bar.value=context.actions.stamina.current
	stability_bar.value=context.actions.stability.current
	var weight:=context.items.weight(context.id) if context.items else 0.0
	var pack: bool=context.items and context.items.is_attached(context.id + ".pack")
	var state: String={"idle":"就绪","attack":"攻击中","dodge":"闪避中","stagger":"失衡","item":"使用物品","aim_item":"瞄准 · 松开出手","spray":"喷洒中 · 松开即停","recovery":"动作恢复"}.get(context.actions.mode,"")
	if context.spray and context.spray.active: state+=" · "+context.items.state_text(context.spray.uid)
	detail.text="%.1f / %.0fkg · %s · %s"%[weight,context.rules.carry_limit,"背包随身" if pack else "背包已放下",state]
	tooltip_text=detail.text
	if compact:
		var constrained:=context.actions.mode in ["stagger","recovery","item","aim_item","spray"]
		detail.visible=constrained or not pack or weight>context.rules.carry_limit
		if constrained:
			detail.text=state
			if context.actions.mode in ["stagger","recovery"]: detail.text+=" · %.1f秒"%context.actions.remaining
