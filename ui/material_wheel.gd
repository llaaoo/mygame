class_name MaterialWheel
extends CanvasLayer
## Live, explicit per-shortcut selection. It owns pointer input, not simulation time.
class Ring extends Control:
 var wheel: MaterialWheel
 func _draw() -> void:
  var center:=size*.5
  for i in range(8):
   var polygon:=PackedVector2Array()
   var angle: float=-PI/2+i*TAU/8
   for j in range(13): polygon.append(center+Vector2.from_angle(angle-PI/8+.025+j*(PI/4-.05)/12)*166)
   for j in range(13): polygon.append(center+Vector2.from_angle(angle+PI/8-.025-j*(PI/4-.05)/12)*74)
   var index:=wheel.page*8+i
   var color:=GameUIStyle.SURFACE_RAISED if i==wheel.hovered else GameUIStyle.PANEL_BG
   if index>=wheel.entries.size() or wheel.entries[index].is_empty(): color=Color(.04,.055,.055,.45)
   draw_colored_polygon(polygon,color)
   if i==wheel.hovered and index<wheel.entries.size() and not wheel.entries[index].is_empty(): draw_arc(center,166,angle-PI/8+.03,angle+PI/8-.03,16,GameUIStyle.GOLD,3,true)
  draw_circle(center,70,GameUIStyle.PANEL_BG_SOLID)
  draw_arc(center,171,0,TAU,96,Color(GameUIStyle.GOLD,.35),1,true)
  draw_arc(center,70,0,TAU,64,Color(GameUIStyle.GOLD,.5),1,true)
  for i in range(8):
   var index:=wheel.page*8+i
   if index<wheel.entries.size() and wheel.entries[index].get("current",false):
    var angle: float=-PI/2+i*TAU/8
    draw_arc(center,162,angle-PI/8+.08,angle+PI/8-.08,16,GameUIStyle.ACCENT,2,true)
class CompactList extends Control:
 var wheel: MaterialWheel
 func _draw() -> void:
  for i in range(wheel.page_size()):
   var index:=wheel.page*wheel.page_size()+i
   var entry: Dictionary=wheel.entries[index] if index<wheel.entries.size() else {}
   var rect:=Rect2(Vector2(0,i*64),Vector2(size.x,58))
   draw_style_box(GameUIStyle.surface_style(i==wheel.hovered),rect)
   if entry.get("current",false): draw_line(rect.position+Vector2(2,4),rect.position+Vector2(2,54),GameUIStyle.ACCENT,3)
var player: Player
var save_request: Callable
var source := ""
var last_source := ""
var opening_direction:=Vector2.DOWN
var entries: Array[Dictionary]=[]
var page := 0
var hovered := -1
var _hold := false
var _ring: Ring
var _compact_view: CompactList
var _compact_labels: Array[Label]=[]
var _compact_mode := false
var _compact_rows := 1
var _layout_selected := false
var _source_host: ScrollContainer
var _source_list: VBoxContainer
var _source_signature := ""
var _title: Label
var _center: Label
var _detail: Label
var _detail_host: PanelContainer
var _labels: Array[Label]=[]
var _elapsed:=0.0
var _entry_source := ""
var _slot_ids: Array[String]=[]
var _preview_choices: Dictionary={}
var _opening_pointer:=Vector2.ZERO
func _ready() -> void:
 layer=GameUIStyle.LAYER_MODAL+2
 add_to_group("live_selector")
 var background:=ColorRect.new()
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.color=Color(0,0,0,.16)
 add_child(background)
 _ring=Ring.new(); _ring.wheel=self; _ring.mouse_filter=Control.MOUSE_FILTER_IGNORE
 _ring.custom_minimum_size=Vector2(360,360); background.add_child(_ring)
 _source_host=ScrollContainer.new(); _source_host.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; _source_host.follow_focus=true; _source_host.add_theme_stylebox_override("panel",GameUIStyle.quiet_panel(.9)); background.add_child(_source_host)
 _source_list=VBoxContainer.new(); _source_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _source_list.add_theme_constant_override("separation",5); _source_host.add_child(_source_list)
 _title=FoundationWidgets.label("",20); _title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; background.add_child(_title)
 _center=FoundationWidgets.label("",15); _center.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _ring.add_child(_center)
 for i in range(8):
  var label:=FoundationWidgets.label("",13); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  _ring.add_child(label); _labels.append(label)
 _compact_view=CompactList.new(); _compact_view.wheel=self; _compact_view.mouse_filter=Control.MOUSE_FILTER_IGNORE; background.add_child(_compact_view)
 for i in range(3):
  var label:=FoundationWidgets.label("",14); label.mouse_filter=Control.MOUSE_FILTER_IGNORE
  _compact_view.add_child(label); _compact_labels.append(label)
 _detail_host=PanelContainer.new(); _detail_host.mouse_filter=Control.MOUSE_FILTER_IGNORE
 _detail_host.add_theme_stylebox_override("panel",GameUIStyle.quiet_panel(.96)); background.add_child(_detail_host)
 _detail=FoundationWidgets.label("",14); _detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 _detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _detail.max_lines_visible=8
 _detail_host.add_child(_detail)
 get_window().focus_exited.connect(close)
 get_viewport().size_changed.connect(_layout)
 _layout(); hide()
func page_size() -> int:
 return _compact_rows if _compact_mode else 8
func selector_rect() -> Rect2:
 return _compact_view.get_global_rect() if _compact_mode else _ring.get_global_rect()
func entry_point(index: int) -> Vector2:
 var slot:=posmod(index,page_size())
 if _compact_mode: return _compact_view.position+Vector2(_compact_view.size.x*.5,slot*64+29)
 return _ring.position+(Vector2(180,180)+Vector2.from_angle(-PI/2+slot*TAU/8)*125)*_ring.scale
func _layout() -> void:
 var size:=get_viewport().get_visible_rect().size
 _ring.scale=Vector2.ONE
 _detail.max_lines_visible=3 if size.x<900 else 8
 _ring.position=Vector2(size.x*.5-180,maxf(64,(size.y-360)*.5-24))
 _source_host.position=Vector2(maxf(20,size.x*.5-390),_ring.position.y+32); _source_host.size=Vector2(190,280)
 _title.position=Vector2(24,24); _title.size=Vector2(size.x-48,56)
 _center.position=Vector2(112,148); _center.size=Vector2(136,64)
 for i in range(8):
  _labels[i].position=Vector2(180,180)+Vector2.from_angle(-PI/2+i*TAU/8)*125-Vector2(64,24)
  _labels[i].size=Vector2(128,48)
 _ring.visible=not _compact_mode
 _compact_view.visible=_compact_mode
 if _compact_mode:
  _compact_view.position=Vector2(size.x*.5-152,maxf(94,size.y*.5-80)); _compact_view.size=Vector2(304,page_size()*64)
  for i in range(3):
   _compact_labels[i].position=Vector2(14,i*64+8); _compact_labels[i].size=Vector2(276,48)
  _source_host.position=Vector2(maxf(20,size.x*.5-360),_compact_view.position.y); _source_host.size=Vector2(190,160)
  _detail_host.position=Vector2(size.x*.5+170,_compact_view.position.y); _detail_host.size=Vector2(minf(260,size.x*.5-190),180)
 else:
  _detail_host.position=Vector2(size.x*.5+185,_ring.position.y+68); _detail_host.size=Vector2(minf(260,size.x*.5-205),200)
 if size.x<900:
  _title.text="选择释放形式 · 世界持续运行"
  # Stack source navigation and the short explanation above the choices.
  # Only presentation scales; pointer projection uses the same transform.
  var source_width:=minf(190,size.x*.3)
  # Reserve the complete three-line font height. A fixed 68px PanelContainer
  # silently grows to its text minimum and otherwise overlaps the first wedge.
  var header_height:=maxf(96,ceilf(_detail.get_theme_font("font").get_height(_detail.get_theme_font_size("font_size")))*3+24)
  var choices_top:=82+header_height+14
  _source_host.position=Vector2(16,82); _source_host.size=Vector2(source_width,header_height)
  _detail_host.position=Vector2(source_width+32,82); _detail_host.size=Vector2(size.x-source_width-48,header_height)
  if _compact_mode:
   _compact_view.position=Vector2(maxf(16,size.x*.5-152),choices_top)
  else:
   var scale_factor:=clampf((size.y-choices_top-28)/360.0,.6,1.0)
   _ring.scale=Vector2.ONE*scale_factor
   _ring.position=Vector2(size.x*.5-180*scale_factor,choices_top)
func remember_source(value: String) -> void:
 if QuickslotMaterials.available(player.skill_manager,value): last_source=value
func open(held := false) -> void:
 if player.ui_blocked or player.health_component.is_dead or not player.actor_context or not player.actor_context.rules.material_operations: return
 if visible: close(); return
 _opening_pointer=get_viewport().get_mouse_position()
 opening_direction=player.get_mouse_direction()
 player.cancel_active_input("选择材料：取消未提交准备")
 _hold=held; page=0; hovered=-1; _entry_source=""
 source=last_source
 if not QuickslotMaterials.available(player.skill_manager,source):
  source=""
  for candidate in QuickslotLoadout.SOURCES:
   if QuickslotMaterials.available(player.skill_manager,candidate): source=candidate; break
 player.input_controller.suppress_held_shortcuts()
 _refresh(); show(); _layout()
 UIMotion.enter(_ring); UIMotion.enter(_detail_host)
func open_for_source(value: String, aim_direction := Vector2.ZERO) -> void:
 if not QuickslotMaterials.available(player.skill_manager,value): return
 last_source=value
 if visible:
  source=value; page=0; hovered=-1; _entry_source=""; _refresh()
 else:
  open(false)
  if not aim_direction.is_zero_approx(): opening_direction=aim_direction.normalized()
func _refresh_sources() -> void:
 var signature:=source+"|"
 for candidate in QuickslotLoadout.SOURCES:
  if QuickslotMaterials.available(player.skill_manager,candidate): signature+=candidate+":"+str(player.skill_manager.shortcuts.revision(candidate))+"|"
 if signature==_source_signature: return
 _source_signature=signature
 FoundationWidgets.clear(_source_list)
 _source_list.add_child(FoundationWidgets.label("动作快捷槽",12,true))
 for candidate in QuickslotLoadout.SOURCES:
  if not QuickslotMaterials.available(player.skill_manager,candidate): continue
  var instance:=player.skill_manager.get_instance(candidate)
  var button:=FoundationWidgets.button(InputBindings.label(InputBindings.action_for_source(candidate))+"   "+instance.data.display_name,open_for_source.bind(candidate))
  button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.clip_text=true
  GameUIStyle.apply_tab(button,candidate==source)
  _source_list.add_child(button)
func close() -> void:
 if not visible: return
 hide(); hovered=-1
 if get_window().has_focus(): get_viewport().warp_mouse(_opening_pointer)
 player.input_controller.pointer_consumed()
 player.input_controller.suppress_held_shortcuts()
func _refresh() -> void:
 var live:=QuickslotMaterials.usable_options(player,source)
 if _entry_source!=source:
  entries=[]; _slot_ids.clear(); _preview_choices.clear(); hovered=-1
  _entry_source=source; _layout_selected=false
 var old_index:=page*page_size()+hovered
 var old_choice: Dictionary=entries[old_index].get("choice",{}) if hovered>=0 and old_index<entries.size() else {}
 var groups: Dictionary={}
 for row in live:
  if not groups.has(row.variant_id): groups[row.variant_id]=[]
  groups[row.variant_id].append(row)
  if row.variant_id not in _slot_ids: _slot_ids.append(row.variant_id)
 if not _layout_selected:
  _compact_mode=_slot_ids.size()<=3; _compact_rows=clampi(_slot_ids.size(),1,3); _layout_selected=true
 entries=[]
 for id in _slot_ids:
  if not groups.has(id): entries.append({}); continue
  var alternatives: Array=groups[id]
  var choice: Dictionary=alternatives[0]
  for row in alternatives:
   if row.choice==_preview_choices.get(id,{}) or not _preview_choices.has(id) and row.current: choice=row; break
  var grouped: Dictionary=choice.duplicate(true); grouped["alternatives"]=alternatives
  entries.append(grouped)
 # Wedges keep their identity during this opening. Lost conditions leave an empty
 # sector; they never slide a different form under a held pointer/release.
 if hovered>=0 and (old_index>=entries.size() or entries[old_index].get("choice",{})!=old_choice): hovered=-1
 page=clampi(page,0,maxi(0,(entries.size()-1)/page_size()))
 # Keep even an emptied page in place; only explicit scrolling changes pages.
 var instance:=player.skill_manager.get_instance(source)
 _title.text="选择释放形式\n仅列当前可用来源 · 选择后手动施放 · 世界持续运行"
 _refresh_sources()
 _center.text=(InputBindings.label(InputBindings.action_for_source(source))+"\n"+instance.data.display_name) if instance else InputBindings.menu_help("尚无选材动作\nK编组已学动作")
 for i in range(8):
  var index:=page*8+i
  _labels[i].text=""
  if index>=entries.size() or entries[index].is_empty(): continue
  var entry: Dictionary=entries[index]
  _labels[i].text=("✓ " if entry.current else "")+entry.title+"\n"+str(entry.get("cost_label","%d MP"%entry.cost))+((" · 瓶%s"%str(entry.choice.get("uid","")).trim_prefix("item.")) if not str(entry.choice.get("uid","")).is_empty() else "")
  _labels[i].add_theme_color_override("font_color",GameUIStyle.TEXT_MAIN if entry.ready else GameUIStyle.TEXT_MUTED)
 for i in range(3):
  _compact_labels[i].visible=i<page_size()
  var index:=page*page_size()+i
  var entry: Dictionary=entries[index] if index<entries.size() else {}
  _compact_labels[i].text=("条件已失效" if _slot_ids.size()>0 else "当前没有可用形式") if entry.is_empty() else ("✓ " if entry.current else "")+entry.title+"\n"+str(entry.get("cost_label","%d MP"%entry.cost))
  _compact_labels[i].add_theme_color_override("font_color",GameUIStyle.TEXT_MUTED if entry.is_empty() else GameUIStyle.TEXT_MAIN)
 _layout(); _update_detail(); _ring.queue_redraw(); _compact_view.queue_redraw()
func _update_detail() -> void:
 var index:=page*page_size()+hovered
 if hovered<0 or index>=entries.size() or entries[index].is_empty():
  var has_choices:=entries.any(func(row): return not row.is_empty())
  var instruction: String="松开中键确认" if _hold else "点击形式确认"
  var pages: String=" · 滚轮翻页 %d/%d"%[page+1,ceili(float(entries.size())/page_size())] if entries.size()>page_size() else ""
  _detail.text=("%s%s\n按 %s 手动释放\nEsc取消"%[instruction,pages,InputBindings.label(InputBindings.action_for_source(source))]) if has_choices else QuickslotMaterials.unavailable_summary(player,source)
  if not has_choices and not QuickslotMaterials.available(player.skill_manager,source): _detail.text=InputBindings.menu_help(_detail.text)
  return
 var entry: Dictionary=entries[index]
 _detail.text="%s · %s\n%s\n%s"%[entry.title,entry.get("cost_label","%d MP"%entry.cost),entry.detail,entry.reason if not entry.ready else ("松开中键确认" if _hold else "点击确认")+" · 按原快捷键释放"]
 if entry.get("alternatives",[]).size()>1: _detail.text+="\n滚轮切换同类实物"
 elif entries.size()>page_size(): _detail.text+="\n滚轮翻页 %d/%d"%[page+1,ceili(float(entries.size())/page_size())]
func _pick(point: Vector2) -> void:
 hovered=-1
 if _compact_mode:
  var local:=point-_compact_view.position
  for i in range(page_size()):
   if Rect2(Vector2(0,i*64),Vector2(_compact_view.size.x,58)).has_point(local): hovered=i; break
 else:
  var offset:=(point-_ring.position)/_ring.scale-Vector2(180,180)
  hovered=-1 if offset.length()<74 or not _hold and offset.length()>192 else int(floor(fposmod(offset.angle()+PI/2+PI/8,TAU)/(TAU/8)))
 var index:=page*page_size()+hovered
 if hovered>=0 and (index>=entries.size() or entries[index].is_empty()): hovered=-1
 _update_detail(); _ring.queue_redraw(); _compact_view.queue_redraw()
func _confirm() -> void:
 var index:=page*page_size()+hovered
 if hovered>=0 and index<entries.size() and not entries[index].is_empty():
  if QuickslotMaterials.select(player,source,entries[index].choice,true):
   last_source=source
   if save_request.is_valid(): save_request.call()
  else:
   _detail.text="选定实物不可用，未修改快捷槽。请选择口袋中的具体喷剂，或Esc返回。"
   return
 close()
func _input(event: InputEvent) -> void:
 if not visible:
  if event.is_action_pressed("material_wheel") and not player.ui_blocked:
   open(true)
   if visible: get_viewport().set_input_as_handled()
  return
 if event is InputEventKey and event.pressed and not event.echo:
  if InputBindings.menu_key(event) in [KEY_ESCAPE,KEY_G]: close(); get_viewport().set_input_as_handled(); return
  for candidate in QuickslotLoadout.SOURCES:
   if event.is_action_pressed(InputBindings.action_for_source(candidate)):
    player.input_controller.suppress_source(candidate)
    if QuickslotMaterials.available(player.skill_manager,candidate): source=candidate; page=0; hovered=-1; _refresh()
    get_viewport().set_input_as_handled(); return
 if event is InputEventMouseMotion: _pick(event.position)
 if event.is_action_released("material_wheel") and _hold: _confirm(); get_viewport().set_input_as_handled(); return
 if event is InputEventMouseButton:
  if _source_host.get_global_rect().has_point(event.position):
   if event.button_index==MOUSE_BUTTON_LEFT: player.input_controller.pointer_consumed()
   return
  if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   var index:=page*page_size()+hovered
   var step:=1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1
   var alternatives: Array=entries[index].get("alternatives",[]) if hovered>=0 and index<entries.size() and not entries[index].is_empty() else []
   if alternatives.size()>1:
    var position:=0
    for i in range(alternatives.size()):
     if alternatives[i].choice.get("uid","")==entries[index].choice.get("uid",""): position=i; break
    var changed: Dictionary=alternatives[posmod(position+step,alternatives.size())].duplicate(true)
    _preview_choices[str(changed.variant_id)]=changed.choice
   else: page=posmod(page+step,maxi(1,ceili(float(entries.size())/page_size())))
   var sector:=hovered if alternatives.size()>1 else -1
   _refresh()
   if sector>=0:
    hovered=sector; _update_detail(); _ring.queue_redraw(); _compact_view.queue_redraw()
  elif event.button_index==MOUSE_BUTTON_LEFT:
   player.input_controller.pointer_consumed()
   if event.pressed and not _hold: _pick(event.position); _confirm()
  if event.button_index!=MOUSE_BUTTON_RIGHT: get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
 if not visible: return
 if player.health_component.is_dead or player.ui_blocked: close(); return
 _elapsed+=delta
 if _elapsed>=.2: _elapsed=0; _refresh()
