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
var _elapsed := 0.0
var _attributes := false
var _layout_key := ""
var _controls_signature := ""
var _tab_signature := ""
var _branch_buttons: Dictionary={}
var _attribute_labels: Dictionary={}
var _attribute_buttons: Dictionary={}
var _perk_buttons: Dictionary={}
var _practice_label: Label
var _perk_reason: Label
var _learn_button: Button
var _branch_scroll: ScrollContainer
var _graph_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _attribute_column: VBoxContainer
func setup(player: Player,save: Callable,train: Callable,attributes := false) -> void:
 actor=player; save_request=save; train_request=train; _attributes=attributes
 size_flags_horizontal=Control.SIZE_EXPAND_FILL; size_flags_vertical=Control.SIZE_EXPAND_FILL
 add_theme_constant_override("separation",10)
 _overview=FoundationWidgets.label("",14); add_child(_overview)
 _experience_bar=ProgressBar.new(); _experience_bar.custom_minimum_size.y=7; _experience_bar.show_percentage=false; add_child(_experience_bar)
 _body=HBoxContainer.new(); _body.size_flags_vertical=Control.SIZE_EXPAND_FILL; _body.add_theme_constant_override("separation",12); add_child(_body)
 _branch_scroll=ScrollContainer.new(); _branch_scroll.custom_minimum_size.x=180; _branch_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; _branch_scroll.follow_focus=true; _body.add_child(_branch_scroll)
 _branches=VBoxContainer.new(); _branches.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _branch_scroll.add_child(_branches)
 _graph_scroll=ScrollContainer.new(); _graph_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _graph_scroll.size_flags_stretch_ratio=.64; _graph_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; _graph_scroll.follow_focus=true; _body.add_child(_graph_scroll)
 _canvas=BranchGraph.new(); _canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _canvas.custom_minimum_size=Vector2(475,450); _graph_scroll.add_child(_canvas)
 _detail_scroll=ScrollContainer.new(); _detail_scroll.custom_minimum_size.x=260; _detail_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _detail_scroll.size_flags_stretch_ratio=.36; _detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; _detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; _detail_scroll.follow_focus=true; _body.add_child(_detail_scroll)
 _detail=VBoxContainer.new(); _detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _detail.add_theme_constant_override("separation",10); _detail_scroll.add_child(_detail)
 resized.connect(_layout_regions); _canvas.resized.connect(_layout_graph)
 _layout_regions()
 _refresh()
func _process(delta: float) -> void:
 if not is_visible_in_tree() or not is_instance_valid(actor): return
 _elapsed+=delta
 if _elapsed<.2: return
 _elapsed=0
 _refresh()
func _refresh() -> void:
 var stats:=actor.stats_component; var mastery:=actor.mastery_manager
 var data:=ActorProgression.values(actor)
 var recovery:=ActorProgression.stamina_values(actor)
 _overview.text="角色 Lv.%d · 经验 %d / %d    属性点 %d    Perk点 %d\n生命 %d · %s · 体力 %.0f · 当前回复 %.1f/秒（基础%.1f） · 负重承受 %.0f"%[stats.level,stats.experience,stats.exp_to_next,stats.attribute_points,mastery.get_available_perk_points(),actor.health_component.max_hp,QuickslotView.magic_status(actor),recovery.maximum,recovery.regeneration,recovery.base_regeneration,actor.actor_context.rules.carry_limit+data.carry_bonus]
 _overview.tooltip_text="升级：3属性点＋1Perk点；成功实践提升分支熟练度。回复仍受消耗延迟与格挡限制。"
 _experience_bar.max_value=maxi(1,stats.exp_to_next); _experience_bar.value=stats.experience
 if _branch_buttons.is_empty():
  _branches.add_child(FoundationWidgets.button("属性与派生",_show_attributes))
  for school in mastery.TREE_RESOURCE_PATHS:
   var button:=FoundationWidgets.button("",_select_school.bind(school)); button.clip_text=true
   _branches.add_child(button); _branch_buttons[school]=button
 for school in mastery.TREE_RESOURCE_PATHS:
  var tree:=mastery.get_tree_data(school)
  var level:=mastery.get_mastery(school).level
  var button: Button=_branch_buttons[school]
  button.text=tree.display_name+"\n熟练度 %d"%level
  if _tab_signature!=str([_attributes,_school]): GameUIStyle.apply_tab(button,not _attributes and school==_school)
 _tab_signature=str([_attributes,_school])
 if _school<0: _school=SkillMastery.School.MELEE
 var layout_key: String="attributes" if _attributes else str(_school)
 if layout_key!=_layout_key:
  _layout_key=layout_key
  if _attributes: _draw_attributes()
  else: _draw_tree()
 _update_existing()
func _update_existing() -> void:
 var stats:=actor.stats_component; var levels: Array=[]
 for mastery in actor.mastery_manager.get_all_masteries(): levels.append(mastery.level)
 var magic:=actor.actor_context.magic
 var signature:=str([_layout_key,_selected,stats.level,stats.attribute_points,[stats.strength,stats.intelligence,stats.agility,stats.endurance],stats.primary_values(),actor.mastery_manager.revision,levels,actor.mastery_manager.get_mastery(_school).xp,actor.health_component.is_dead,magic.awakened,magic.mana_base,magic.hp_cost,magic.stamina_cost,actor.mana_component.max_mp,actor.health_component.max_hp,actor.actor_context.actions.stamina.maximum])
 if signature==_controls_signature: return
 _controls_signature=signature
 if _attributes:
  for key in _attribute_labels:
   var text:=_attribute_text(key)
   _attribute_labels[key].text="%s %d（有效%d）\n%s"%[StatsComponent.primary_title(key),actor.stats_component.get(key),actor.stats_component.effective_stat(key),text]
   _attribute_buttons[key].disabled=actor.stats_component.attribute_points<=0
   _attribute_buttons[key].tooltip_text=text
  return
 var mastery:=actor.mastery_manager
 for id in _perk_buttons:
  var perk:=mastery.get_perk(id); var known:=mastery.has_perk(id); var ready:=mastery.can_unlock_perk(id)
  _perk_buttons[id].text=perk.display_name+"\n"+("已学习" if known else "可学习" if ready else "条件未满足")
  GameUIStyle.apply_button(_perk_buttons[id],GameUIStyle.ACCENT if known else GameUIStyle.GOLD if ready else GameUIStyle.TEXT_MUTED,id==_selected)
 for link in _canvas.links: link.learned=mastery.has_perk(str(link.id))
 _canvas.queue_redraw()
 if is_instance_valid(_learn_button):
  var perk:=mastery.get_perk(_selected); var reason:=mastery.unlock_reason(_selected)
  var practice:=mastery.get_mastery(_school)
  _practice_label.text=mastery.get_tree_data(_school).description+"\n熟练度%d · %.0f / %.0f实践经验"%[practice.level,practice.xp,practice.xp_to_next]
  _perk_reason.text=reason if not reason.is_empty() else "条件已满足，确认学习才扣点。"
  _learn_button.disabled=not reason.is_empty(); _learn_button.text="学习："+perk.display_name
func _show_attributes() -> void:
 _attributes=true; _refresh()
func _select_school(school: int) -> void:
 _attributes=false; _school=school; _selected=""; _layout_key=""; _refresh()
func _clear_canvas() -> void:
 _attribute_column=null
 FoundationWidgets.clear(_canvas); _canvas.links=[]; _canvas.queue_redraw()
 _attribute_labels.clear(); _attribute_buttons.clear(); _perk_buttons.clear()
 _learn_button=null; _practice_label=null; _perk_reason=null
 _controls_signature=""
func _draw_attributes() -> void:
 _clear_canvas(); FoundationWidgets.clear(_detail)
 _canvas.custom_minimum_size=Vector2(400,480)
 var column:=VBoxContainer.new(); _attribute_column=column; column.position=Vector2(8,8); column.size=Vector2(380,470); column.add_theme_constant_override("separation",10); _canvas.add_child(column)
 column.add_child(FoundationWidgets.label("下一点基础派生变化",20))
 for key in Buff.PRIMARY_STATS:
  var label:=FoundationWidgets.label("",14); column.add_child(label); _attribute_labels[key]=label
  var button:=FoundationWidgets.button(StatsComponent.primary_title(key)+" +1",_train.bind(key)); column.add_child(button); _attribute_buttons[key]=button
 column.minimum_size_changed.connect(_fit_attributes.bind(column))
 _fit_attributes(column)
 _detail.add_child(FoundationWidgets.label("属性准备",19))
 _detail.add_child(FoundationWidgets.label("主属性由基础值、穿戴装备与增益共同计算。加点不补满资源；耐力会立即改变体力上限。\n\n任务、现场作业与施法检查有效属性；永久Perk要求基础属性，不能借临时增益点亮。\n\n力量支撑近战与携带；敏捷支撑远射、机动与准备；智力支撑作业与觉醒后的施法；学习和属性不替代觉醒；耐力支撑生存与体力。",14,true))
func _train(key: String) -> void:
 if train_request.is_valid(): train_request.call(key)
 _refresh()
func _draw_tree() -> void:
 _clear_canvas()
 var mastery:=actor.mastery_manager; var tree:=mastery.get_tree_data(_school)
 var rows:=0
 for perk: SkillPerkData in tree.perks:
  rows=maxi(rows,perk.row)
 _canvas.custom_minimum_size=Vector2(475,maxi(450,rows*112+120))
 for perk: SkillPerkData in tree.perks:
  var known:=mastery.has_perk(perk.perk_id)
  var ready:=mastery.can_unlock_perk(perk.perk_id)
  var button:=FoundationWidgets.button(perk.display_name+"\n"+("已学习" if known else "可学习" if ready else "条件未满足"),_select_perk.bind(perk.perk_id))
  button.custom_minimum_size=Vector2(145,68); button.clip_text=true
  button.tooltip_text=perk.description+"\n"+mastery.requirement_text(perk)
  GameUIStyle.apply_button(button,GameUIStyle.ACCENT if known else GameUIStyle.GOLD if ready else GameUIStyle.TEXT_MUTED,perk.perk_id==_selected)
  _canvas.add_child(button)
  _perk_buttons[perk.perk_id]=button
 if _selected.is_empty() and not tree.perks.is_empty(): _selected=(tree.perks[0] as SkillPerkData).perk_id
 _layout_graph(); _show_perk_detail()
func _layout_regions() -> void:
 if not _branch_scroll: return
 _branch_scroll.custom_minimum_size.x=180 if size.x<1100 else 208
 _layout_graph()
func _layout_graph() -> void:
 if not _canvas: return
 if _attributes:
  if is_instance_valid(_attribute_column):
   _attribute_column.size.x=maxf(380,minf(580,_canvas.size.x-24))
   _attribute_column.position.x=maxf(8,(_canvas.size.x-_attribute_column.size.x)*.5)
  return
 if _perk_buttons.is_empty(): return
 var tree:=actor.mastery_manager.get_tree_data(_school)
 var columns:=0; var rows:=0; var node_height:=68.0
 for perk: SkillPerkData in tree.perks:
  columns=maxi(columns,perk.column); rows=maxi(rows,perk.row)
  node_height=maxf(node_height,_perk_buttons[perk.perk_id].get_combined_minimum_size().y)
 var grid_width:=float(columns*165+145)
 _canvas.custom_minimum_size=Vector2(grid_width+24,maxf(360,(rows+1)*(node_height+44)+24))
 var origin:=maxf(12,(_canvas.size.x-grid_width)*.5)
 for perk: SkillPerkData in tree.perks:
  var button:=_perk_buttons[perk.perk_id] as Button
  button.position=Vector2(origin+perk.column*165,24+perk.row*(node_height+44)); button.size=Vector2(145,node_height)
 _canvas.links.clear()
 for perk: SkillPerkData in tree.perks:
  for required in perk.prerequisite_ids:
   if not _perk_buttons.has(required): continue
   var before:=_perk_buttons[required] as Button; var after:=_perk_buttons[perk.perk_id] as Button
   _canvas.links.append({"id":perk.perk_id,"from":before.position+Vector2(before.size.x*.5,before.size.y),"to":after.position+Vector2(after.size.x*.5,0),"learned":actor.mastery_manager.has_perk(perk.perk_id)})
 _canvas.queue_redraw()
func _select_perk(id: String) -> void:
 _selected=id; _show_perk_detail(); _update_existing()
func _show_perk_detail() -> void:
 FoundationWidgets.clear(_detail)
 var mastery:=actor.mastery_manager; var perk:=mastery.get_perk(_selected)
 if not perk: return
 var tree:=mastery.get_tree_data(_school); var practice:=mastery.get_mastery(_school)
 _detail.add_child(FoundationWidgets.label(tree.display_name,20))
 _practice_label=FoundationWidgets.label(tree.description+"\n熟练度%d · %.0f / %.0f实践经验"%[practice.level,practice.xp,practice.xp_to_next],14,true); _detail.add_child(_practice_label)
 _detail.add_child(HSeparator.new()); _detail.add_child(FoundationWidgets.label(perk.display_name,19))
 _detail.add_child(FoundationWidgets.label(perk.description,14))
 _detail.add_child(FoundationWidgets.label(mastery.requirement_text(perk),13,true))
 var reason:=mastery.unlock_reason(perk.perk_id)
 _perk_reason=FoundationWidgets.label(reason if not reason.is_empty() else "条件已满足，确认学习才扣点。",14,true); _detail.add_child(_perk_reason)
 _learn_button=FoundationWidgets.button("学习："+perk.display_name,_learn.bind(perk.perk_id),not reason.is_empty()); _learn_button.clip_text=true; _detail.add_child(_learn_button)
func _learn(id: String) -> void:
 if actor.mastery_manager.unlock_perk(id) and save_request.is_valid(): save_request.call()
 _refresh()

func _fit_attributes(column: VBoxContainer) -> void:
 if not _attributes or not is_instance_valid(column) or column.is_queued_for_deletion(): return
 _canvas.custom_minimum_size=Vector2(400,maxf(480,column.get_combined_minimum_size().y+20))
 _layout_graph()
func _attribute_text(key: String) -> String:
 var stats:=actor.stats_component; var current:=stats.derived_values(); var next:=stats.derived_values({key:int(stats.get(key))+1})
 match key:
  "strength": return "近战加成 %d→%d；负重承受 +%.0f→+%.0f"%[current.physical_damage,next.physical_damage,current.carry_bonus,next.carry_bonus]
  "intelligence":
   if not actor.mana_component.can_cast(): return "作业耗时 ×%.2f→×%.2f；尚未觉醒，加点不授予施法资格或可用魔力。"%[current.work_multiplier,next.work_multiplier]
   return "法术加成 %d→%d；作业耗时 ×%.2f→×%.2f；魔力容量仍受觉醒投入限制。"%[current.magic_damage,next.magic_damage,current.work_multiplier,next.work_multiplier]
  "agility": return "远射加成 %d→%d；移速加成 %.0f→%.0f；闪避耗体 ×%.2f→×%.2f；属性准备 ×%.3f→×%.3f"%[current.ranged_damage,next.ranged_damage,current.move_speed_bonus,next.move_speed_bonus,current.dodge_multiplier,next.dodge_multiplier,current.preparation_multiplier,next.preparation_multiplier]
  "endurance":
   var buffs:=actor.get_node("BuffManager") as BuffManager
   var current_body:=ActorProgression.values(actor)
   var next_body:=ActorProgression.values(actor,{"endurance":stats.endurance+1})
   var current_hp:=roundi(buffs.preview_attribute_delta("max_hp"))
   var next_hp:=roundi(buffs.preview_attribute_delta("max_hp",next.max_hp_bonus-current.max_hp_bonus))
   return "生命 %d→%d；体力 %.0f→%.0f；基础回复 %.1f→%.1f/秒；危险伤害减免 %.0f%%→%.0f%%"%[current_hp,next_hp,current_body.max_stamina,next_body.max_stamina,current_body.stamina_regeneration,next_body.stamina_regeneration,(1-current.hazard_damage_multiplier)*100,(1-next.hazard_damage_multiplier)*100]
 return ""
