class_name ActorStatusView
extends VBoxContainer
var compact := false
var context: ActorContext
var stamina_value: Label
var stamina_bar: ProgressBar
var stability_bar: ProgressBar
var detail: Label
var enchantment_label: Label
var combo_label: Label
var art_label: Label
var buildup_label: Label
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for title in ["体力","稳定"]:
		var row:=HBoxContainer.new()
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(row)
		row.add_theme_constant_override("separation",8)
		if compact:
			var glyph:=TextureRect.new(); glyph.texture=GameUIStyle.icon("zap" if title=="体力" else "shield")
			glyph.custom_minimum_size=Vector2(18,18); glyph.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; glyph.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			glyph.modulate=Color("a5ae82") if title=="体力" else Color("9da7b0"); glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_child(glyph)
		else:
			var caption:=FoundationWidgets.label(title,12,true); caption.custom_minimum_size.x=34
			caption.autowrap_mode=TextServer.AUTOWRAP_OFF; row.add_child(caption)
		var bar:=ProgressBar.new()
		bar.custom_minimum_size=Vector2(0 if compact else 100,6)
		bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		bar.show_percentage=false
		bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		GameUIStyle.apply_progress(bar,Color("a5ae82") if title=="体力" else Color("9da7b0"),6)
		row.add_child(bar)
		if title=="体力":
			stamina_bar=bar
			stamina_value=FoundationWidgets.label("",12); stamina_value.custom_minimum_size.x=68
			stamina_value.size_flags_horizontal=Control.SIZE_SHRINK_END
			stamina_value.autowrap_mode=TextServer.AUTOWRAP_OFF; stamina_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(stamina_value)
		else: stability_bar=bar
	detail=FoundationWidgets.label("",11,true)
	detail.visible=not compact
	add_child(detail)
	buildup_label=FoundationWidgets.label("",12,true); add_child(buildup_label)
	enchantment_label=FoundationWidgets.label("",11,true)
	enchantment_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(enchantment_label)
	combo_label=FoundationWidgets.label("",11,true)
	combo_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(combo_label)
	art_label=FoundationWidgets.label("",11,true)
	art_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(art_label)
func _process(_delta: float) -> void:
	visible=context!=null
	if not context or not context.actions: return
	var art:=context.actions.weapon_art_view(Input.is_key_pressed(KEY_SHIFT))
	var martial_state:=context.actions.technique_status(art.is_empty())
	var hold:=context.actions.weapon_hold_view()
	art_label.visible=not hold.is_empty() or not art.is_empty() or not martial_state.is_empty()
	if not hold.is_empty():
		art_label.text="%s · %s\n松开左键 · 体力%.0f"%[hold.title,"重发" if hold.charged else "蓄力%d%%"%roundi(hold.progress*100),hold.cost]
		if hold.release_enchantment: art_label.text+=" · 消耗附魔"
		if not str(hold.reason).is_empty(): art_label.text+="\n"+str(hold.reason)
		art_label.modulate=GameUIStyle.GOLD if str(hold.reason).is_empty() else GameUIStyle.TEXT_DISABLED; art_label.tooltip_text="右键/闪避/菜单取消；最多准备2秒。体力与冷却在松开接受后结算。"
	elif not art.is_empty():
		art_label.text="%s · %s · %s"%[InputBindings.label("weapon_art"),art.title,"收招后" if art.recovering else "%.1f秒"%art.remaining]
		if art.get("alternatives",[]).size()>1: art_label.text+=" · Ctrl切换（%d/2）"%(art.alternatives.map(func(row): return row.title).find(art.title)+1)
		if not str(art.reason).is_empty(): art_label.text+="\n"+str(art.reason)
		art_label.modulate=GameUIStyle.GOLD if str(art.reason).is_empty() else GameUIStyle.TEXT_DISABLED
		art_label.tooltip_text="手动发动武技 · 体力%.0f · Shift显式释放实际附魔"%art.cost
	elif not martial_state.is_empty():
		art_label.text=martial_state; art_label.tooltip_text=martial_state
		art_label.modulate=GameUIStyle.TEXT_MUTED
	var chain:=context.actions.combo_snapshot()
	combo_label.visible=not chain.is_empty()
	if not chain.is_empty():
		combo_label.text=("%s · %d/%d %s · %s"%[chain.weapon,int(chain.index)+1,chain.count,chain.title,chain.phase]) if chain.active else ("左键接续 · %d/%d %s · %.1f秒"%[int(chain.index)+1,chain.count,chain.title,chain.remaining])
		if not chain.active and not str(chain.reason).is_empty(): combo_label.text+=" · "+str(chain.reason)
		combo_label.modulate=Color("dacb93") if chain.active else Color("abc8b7")
		var manager:=context.actor.get_node("SkillManager") as SkillManager
		for source in QuickslotLoadout.SOURCES if art.is_empty() else []:
			var binding:=manager.shortcuts.binding(source)
			if binding.get("kind","")!="technique": continue
			var view:=context.actions.technique_view(str(binding.technique_id),Input.is_key_pressed(KEY_CTRL),Input.is_key_pressed(KEY_SHIFT))
			if not view.is_empty() and view.linked and str(view.reason).is_empty():
				combo_label.text+="\n可接 %s · %s"%[InputBindings.label(InputBindings.action_for_source(source)),view.title]
				break
	var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	var coating:=context.items.coating(uid)
	enchantment_label.visible=coating!=null and coating.enchantment!=null
	if enchantment_label.visible:
		enchantment_label.text="涂层 · %s · %.0f秒"%[coating.enchantment.title,float(context.items.coating_state(uid).expires_at)-context.items.clock_seconds]
		enchantment_label.tooltip_text=coating.enchantment.describe(context.actor)
		enchantment_label.modulate=coating.enchantment.color.lightened(.25)
	stamina_bar.max_value=context.actions.stamina.maximum
	stamina_bar.value=context.actions.stamina.current
	stamina_value.text="%.0f/%.0f"%[context.actions.stamina.current,context.actions.stamina.maximum]
	stability_bar.value=context.actions.stability.current
	stability_bar.get_parent().visible=not compact or context.actions.stability.current<99.9 or context.actions.guarding
	var weight:=context.items.weight(context.id) if context.items else 0.0
	var pack: bool=context.items and context.items.is_attached(context.id + ".pack")
	var state: String={"idle":"就绪","attack":"攻击中","dodge":"闪避中","stagger":"失衡","item":"使用物品","aim_item":"瞄准 · 松开出手","spray":"喷洒中 · 松开即停","recovery":"动作恢复"}.get(context.actions.mode,"")
	if context.spray and context.spray.active: state+=" · "+context.items.state_text(context.spray.uid)
	detail.text="%.1f / %.0fkg · %s · %s"%[weight,(context.rules.carry_limit+float(ActorProgression.values(context.actor).carry_bonus)),"背包随身" if pack else "背包已放下",state]
	buildup_label.text=StatusPresentation.buildup_text(context.actor.get_node("BuffManager") as BuffManager)
	buildup_label.visible=not buildup_label.text.is_empty()
	buildup_label.tooltip_text="积累达到阈值才施加对应状态；停止接触后按原规则消退。"
	tooltip_text=detail.text
	if compact:
		var constrained:=context.actions.counter_remaining>0 or context.actions.mode in ["stagger","recovery","item","aim_item","spray"]
		var queued:=context.actions.buffered_action_label()
		detail.visible=constrained or not pack or weight>(context.rules.carry_limit+float(ActorProgression.values(context.actor).carry_bonus)) or not queued.is_empty()
		if not queued.is_empty(): detail.text=queued+" · 收招后尝试"
		if constrained:
			detail.text="反击机会 · %.1f秒"%context.actions.counter_remaining if context.actions.counter_remaining>0 else state
			if context.actions.mode in ["stagger","recovery"]: detail.text+=" · %.1f秒"%context.actions.remaining
