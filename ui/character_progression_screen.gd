class_name CharacterProgressionScreen
extends VBoxContainer
## Shared actor progression view. Only the injected requests can change gameplay.
class BranchGraph extends Control:
 var links: Array[Dictionary]=[]
 func _draw() -> void:
  for link in links:
   draw_line(link.from,link.to,GameUIStyle.ACCENT if link.learned else GameUIStyle.BORDER_STRONG,2,true)
var actor: Player
var save_request: Callable
var train_request: Callable
var _overview: Label
var _experience_bar: ProgressBar
var _body: HBoxContainer
var _branches: VBoxContainer
var _canvas: BranchGraph
var _detail: VBoxContainer
var _school := -1
var _selected := ""
var _signature := ""
var _elapsed := 0.0
var _attributes := false
func setup(player: Player,save: Callable,train: Callable,attributes := false) -> void:
 actor=player; save_request=save; train_request=train; _attributes=attributes
 size_flags_horizontal=Control.SIZE_EXPAND_FILL; size_flags_vertical=Control.SIZE_EXPAND_FILL
 add_theme_constant_override("separation",10)
 _overview=FoundationWidgets.label("",14); add_child(_overview)
 _experience_bar=ProgressBar.new(); _experience_bar.custom_minimum_size.y=7; _experience_bar.show_percentage=false; add_child(_experience_bar)
 _body=HBoxContainer.new(); _body.size_flags_vertical=Control.SIZE_EXPAND_FILL; _body.add_theme_constant_override("separation",12); add_child(_body)
 var side:=ScrollContainer.new(); side.custom_minimum_size.x=146; side.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; side.follow_focus=true; _body.add_child(side)
 _branches=VBoxContainer.new(); _branches.size_flags_horizontal=Control.SIZE_EXPAND_FILL; side.add_child(_branches)
 var scroller:=ScrollContainer.new(); scroller.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroller.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroller.follow_focus=true; _body.add_child(scroller)
 _canvas=BranchGraph.new(); _canvas.custom_minimum_size=Vector2(470,450); scroller.add_child(_canvas)
 var details:=ScrollContainer.new(); details.custom_minimum_size.x=240; details.size_flags_vertical=Control.SIZE_EXPAND_FILL; details.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; details.follow_focus=true; _body.add_child(details)
 _detail=VBoxContainer.new(); _detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _detail.add_theme_constant_override("separation",10); details.add_child(_detail)
 _refresh()
func _process(delta: float) -> void:
 if not is_instance_valid(actor): return
 _elapsed+=delta
 if _elapsed<.2 or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): return
 _elapsed=0
 var signature:=str([actor.stats_component.level,actor.stats_component.experience,actor.stats_component.attribute_points,actor.stats_component.primary_values(),actor.mastery_manager.serialize_state()])
 if signature!=_signature: _signature=signature; _refresh()
func _refresh() -> void:
 var stats:=actor.stats_component; var mastery:=actor.mastery_manager
 var data:=ActorProgression.values(actor)
 _overview.text="角色 Lv.%d · 经验 %d / %d    属性点 %d    Perk点 %d\n生命 %d · 法力 %d · 体力 %.0f（回复 %.1f/秒） · 负重承受 %.0f\n升级：3属性点＋1Perk点；成功实践提升分支熟练度，每升一级分支获得25角色经验。世界持续运行。"%[stats.level,stats.experience,stats.exp_to_next,stats.attribute_points,mastery.get_available_perk_points(),actor.health_component.max_hp,actor.mana_component.max_mp,data.max_stamina,data.stamina_regeneration,actor.actor_context.rules.carry_limit+data.carry_bonus]
 _experience_bar.max_value=maxi(1,stats.exp_to_next); _experience_bar.value=stats.experience
 FoundationWidgets.clear(_branches)
 _branches.add_child(FoundationWidgets.button("属性与派生",_show_attributes))
 for school in mastery.TREE_RESOURCE_PATHS:
  var tree:=mastery.get_tree_data(school)
  var level:=mastery.get_mastery(school).level
  var button:=FoundationWidgets.button(tree.display_name+"\n熟练度 %d"%level,_select_school.bind(school))
  button.clip_text=true; GameUIStyle.apply_tab(button,not _attributes and school==_school); _branches.add_child(button)
 if _attributes: _draw_attributes()
 else:
  if _school<0: _school=SkillMastery.School.MELEE
  _draw_tree()
func _show_attributes() -> void:
 _attributes=true; _refresh()
func _select_school(school: int) -> void:
 _attributes=false; _school=school; _selected=""; _refresh()
func _clear_canvas() -> void:
 FoundationWidgets.clear(_canvas); _canvas.links=[]; _canvas.queue_redraw()
func _draw_attributes() -> void:
 _clear_canvas(); FoundationWidgets.clear(_detail)
 _canvas.custom_minimum_size=Vector2(400,480)
 var column:=VBoxContainer.new(); column.position=Vector2(8,8); column.size=Vector2(380,470); column.add_theme_constant_override("separation",10); _canvas.add_child(column)
 column.add_child(FoundationWidgets.label("下一点基础派生变化",20))
 var stats:=actor.stats_component
 var current:=stats.derived_values()
 for key in Buff.PRIMARY_STATS:
  var next:=stats.derived_values({key:int(stats.get(key))+1})
  var text:=""
  match key:
   "strength": text="近战加成 %d→%d；负重承受 +%.0f→+%.0f"%[current.physical_damage,next.physical_damage,current.carry_bonus,next.carry_bonus]
   "intelligence": text="法力 %d→%d；法术加成 %d→%d；作业耗时 ×%.2f→×%.2f"%[current.max_mana,next.max_mana,current.magic_damage,next.magic_damage,current.work_multiplier,next.work_multiplier]
   "agility": text="远射加成 %d→%d；移速加成 %.0f→%.0f；闪避耗体 ×%.2f→×%.2f；属性准备 ×%.3f→×%.3f"%[current.ranged_damage,next.ranged_damage,current.move_speed_bonus,next.move_speed_bonus,current.dodge_multiplier,next.dodge_multiplier,current.preparation_multiplier,next.preparation_multiplier]
   "endurance": text="生命 %d→%d；体力 %.0f→%.0f；回复 %.1f→%.1f/秒；危险伤害减免 %.0f%%→%.0f%%"%[50+current.max_hp_bonus,50+next.max_hp_bonus,current.max_stamina,next.max_stamina,current.stamina_regeneration,next.stamina_regeneration,(1-current.hazard_damage_multiplier)*100,(1-next.hazard_damage_multiplier)*100]
  column.add_child(FoundationWidgets.label("%s %d（有效%d）\n%s"%[StatsComponent.primary_title(key),stats.get(key),stats.effective_stat(key),text],14))
  var button:=FoundationWidgets.button(StatsComponent.primary_title(key)+" +1",_train.bind(key),stats.attribute_points<=0); button.tooltip_text=text; column.add_child(button)
 column.minimum_size_changed.connect(_fit_attributes.bind(column))
 _fit_attributes(column)
 _detail.add_child(FoundationWidgets.label("属性准备",19))
 _detail.add_child(FoundationWidgets.label("主属性由基础值、真实装备与增益共同计算。加点不补满资源；耐力会立即改变体力上限。\n\n任务、现场作业与施法检查有效属性；永久Perk要求基础属性，不能借临时增益点亮。\n\n力量支撑近战与携带；敏捷支撑远射、机动与准备；智力支撑施法与作业；耐力支撑生存与体力。",14,true))
func _train(key: String) -> void:
 if train_request.is_valid(): train_request.call(key)
 _refresh()
func _draw_tree() -> void:
 _clear_canvas()
 var mastery:=actor.mastery_manager; var tree:=mastery.get_tree_data(_school)
 var rows:=0; var positions: Dictionary={}
 for perk: SkillPerkData in tree.perks:
  rows=maxi(rows,perk.row)
  positions[perk.perk_id]=Vector2(10+perk.column*155,18+perk.row*112)
 _canvas.custom_minimum_size=Vector2(475,maxi(450,rows*112+120))
 for perk: SkillPerkData in tree.perks:
  for required in perk.prerequisite_ids:
   if positions.has(required): _canvas.links.append({"from":positions[required]+Vector2(72,64),"to":positions[perk.perk_id]+Vector2(72,0),"learned":mastery.has_perk(perk.perk_id)})
  var known:=mastery.has_perk(perk.perk_id)
  var ready:=mastery.can_unlock_perk(perk.perk_id)
  var button:=FoundationWidgets.button(perk.display_name+"\n"+("已学习" if known else "可学习" if ready else "条件未满足"),_select_perk.bind(perk.perk_id))
  button.position=positions[perk.perk_id]; button.size=Vector2(145,64); button.clip_text=true
  button.tooltip_text=perk.description+"\n"+mastery.requirement_text(perk)
  GameUIStyle.apply_button(button,GameUIStyle.ACCENT if known else GameUIStyle.GOLD if ready else GameUIStyle.TEXT_MUTED,perk.perk_id==_selected)
  _canvas.add_child(button)
 if _selected.is_empty() and not tree.perks.is_empty(): _selected=(tree.perks[0] as SkillPerkData).perk_id
 _canvas.queue_redraw(); _show_perk_detail()
func _select_perk(id: String) -> void:
 _selected=id; _draw_tree()
func _show_perk_detail() -> void:
 FoundationWidgets.clear(_detail)
 var mastery:=actor.mastery_manager; var perk:=mastery.get_perk(_selected)
 if not perk: return
 var tree:=mastery.get_tree_data(_school); var practice:=mastery.get_mastery(_school)
 _detail.add_child(FoundationWidgets.label(tree.display_name,20))
 _detail.add_child(FoundationWidgets.label(tree.description+"\n熟练度%d · %.0f / %.0f实践经验"%[practice.level,practice.xp,practice.xp_to_next],14,true))
 _detail.add_child(HSeparator.new()); _detail.add_child(FoundationWidgets.label(perk.display_name,19))
 _detail.add_child(FoundationWidgets.label(perk.description,14))
 _detail.add_child(FoundationWidgets.label(mastery.requirement_text(perk),13,true))
 var reason:=mastery.unlock_reason(perk.perk_id)
 _detail.add_child(FoundationWidgets.label(reason if not reason.is_empty() else "条件已满足，确认学习才扣点。",14,true))
 var button:=FoundationWidgets.button("学习："+perk.display_name,_learn.bind(perk.perk_id),not reason.is_empty()); button.clip_text=true; _detail.add_child(button)
func _learn(id: String) -> void:
 if actor.mastery_manager.unlock_perk(id) and save_request.is_valid(): save_request.call()
 _refresh()

func _fit_attributes(column: VBoxContainer) -> void:
 if not _attributes or not is_instance_valid(column) or column.is_queued_for_deletion(): return
 _canvas.custom_minimum_size=Vector2(400,maxf(480,column.get_combined_minimum_size().y+20))
