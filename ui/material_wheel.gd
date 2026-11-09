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
   if index>=wheel.entries.size(): color=Color(.04,.055,.055,.45)
   draw_colored_polygon(polygon,color)
   if i==wheel.hovered and index<wheel.entries.size(): draw_arc(center,166,angle-PI/8+.03,angle+PI/8-.03,16,GameUIStyle.GOLD,3,true)
  draw_circle(center,70,GameUIStyle.PANEL_BG_SOLID)
  draw_arc(center,171,0,TAU,96,Color(GameUIStyle.GOLD,.35),1,true)
  draw_arc(center,70,0,TAU,64,Color(GameUIStyle.GOLD,.5),1,true)
  for i in range(8):
   var index:=wheel.page*8+i
   if index<wheel.entries.size() and wheel.entries[index].current:
    var angle: float=-PI/2+i*TAU/8
    draw_arc(center,162,angle-PI/8+.08,angle+PI/8-.08,16,GameUIStyle.ACCENT,2,true)
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
 _detail_host=PanelContainer.new(); _detail_host.mouse_filter=Control.MOUSE_FILTER_IGNORE
 _detail_host.add_theme_stylebox_override("panel",GameUIStyle.quiet_panel(.96)); background.add_child(_detail_host)
 _detail=FoundationWidgets.label("",14); _detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 _detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _detail.max_lines_visible=8
 _detail_host.add_child(_detail)
 get_window().focus_exited.connect(close)
 get_viewport().size_changed.connect(_layout)
 _layout(); hide()
func _layout() -> void:
 var size:=get_viewport().get_visible_rect().size
 _ring.position=Vector2(size.x*.5-180,maxf(64,(size.y-360)*.5-24))
 _source_host.position=Vector2(maxf(20,size.x*.5-390),_ring.position.y+32); _source_host.size=Vector2(190,280)
 _title.position=Vector2(24,24); _title.size=Vector2(size.x-48,56)
 _center.position=Vector2(112,148); _center.size=Vector2(136,64)
 for i in range(8):
  _labels[i].position=Vector2(180,180)+Vector2.from_angle(-PI/2+i*TAU/8)*125-Vector2(64,24)
  _labels[i].size=Vector2(128,48)
 _detail_host.position=Vector2(size.x*.5+185,_ring.position.y+68); _detail_host.size=Vector2(minf(260,size.x*.5-205),200)
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
 var live:=QuickslotMaterials.options(player,source)
 if _entry_source!=source:
  entries=[]
  var groups: Dictionary={}
  for row in live:
   if not groups.has(row.variant_id): groups[row.variant_id]=[]
   groups[row.variant_id].append(row)
  for payload in groups:
   var alternatives: Array=groups[payload]
   var choice: Dictionary=alternatives[0]
   for row in alternatives:
    if row.current: choice=row; break
   var grouped:=choice.duplicate(true); grouped["alternatives"]=alternatives
   entries.append(grouped)
  _entry_source=source
 else:
  for index in range(entries.size()):
   var old: Dictionary=entries[index]
   var found:=false
   for entry in live:
    if entry.variant_id==old.variant_id and entry.choice.get("uid","")==old.choice.get("uid",""):
     var updated: Dictionary=entry.duplicate(true); updated["alternatives"]=old.get("alternatives",[])
     entries[index]=updated; found=true; break
   if not found:
    old.ready=false; old.reason="选定实物已不在口袋，请重新打开轮盘选择。"
 page=clampi(page,0,maxi(0,(entries.size()-1)/8))
 var instance:=player.skill_manager.get_instance(source)
 _title.text="释放来源\n点击左侧动作或按快捷键切槽 · 滚轮翻页 / 同类切瓶 · 世界持续运行"
 _refresh_sources()
 _center.text=(InputBindings.label(InputBindings.action_for_source(source))+"\n"+instance.data.display_name) if instance else "尚无选材动作\nK编组已学动作"
 for i in range(8):
  var index:=page*8+i
  _labels[i].text=""
  if index>=entries.size(): continue
  var entry: Dictionary=entries[index]
  _labels[i].text=("✓ " if entry.current else "")+entry.title+"\n%d MP"%entry.cost+((" · 瓶%s"%str(entry.choice.get("uid","")).trim_prefix("item.")) if not str(entry.choice.get("uid","")).is_empty() else "")
  _labels[i].add_theme_color_override("font_color",GameUIStyle.TEXT_MAIN if entry.ready else GameUIStyle.TEXT_MUTED)
 _update_detail(); _ring.queue_redraw()
func _update_detail() -> void:
 var index:=page*8+hovered
 if hovered<0 or index>=entries.size():
  _detail.text="选择只改变本槽来源，不施法、不消费材料。\n%s\n中键松开 / M模式点击确认 · 移回中心或Esc取消"%(("第%d/%d页"%[page+1,maxi(1,ceili(entries.size()/8.0))]) if not entries.is_empty() else "在K编组已掌握的材料操作；基础火花可直接使用。")
  return
 var entry: Dictionary=entries[index]
 _detail.text="%s · %d MP · %s\n%s\n第%d/%d页 · 中键松开 / M模式点击确认 · Esc取消"%[entry.title,entry.cost,entry.detail,entry.reason if not entry.ready else "可释放 · 确认后按原快捷键施放",page+1,maxi(1,ceili(entries.size()/8.0))]
func _pick(point: Vector2) -> void:
 var offset:=point-(_ring.position+Vector2(180,180))
 hovered=-1 if offset.length()<74 or not _hold and offset.length()>192 else int(floor(fposmod(offset.angle()+PI/2+PI/8,TAU)/(TAU/8)))
 _update_detail(); _ring.queue_redraw()
func _confirm() -> void:
 var index:=page*8+hovered
 if hovered>=0 and index<entries.size():
  if QuickslotMaterials.select(player,source,entries[index].choice):
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
  if event.keycode in [KEY_ESCAPE,KEY_M]: close(); get_viewport().set_input_as_handled(); return
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
   var index:=page*8+hovered
   var step:=1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1
   var alternatives: Array=entries[index].get("alternatives",[]) if hovered>=0 and index<entries.size() else []
   if alternatives.size()>1:
    var position:=0
    for i in range(alternatives.size()):
     if alternatives[i].choice.get("uid","")==entries[index].choice.get("uid",""): position=i; break
    var changed: Dictionary=alternatives[posmod(position+step,alternatives.size())].duplicate(true)
    changed["alternatives"]=alternatives; entries[index]=changed
   else: page=posmod(page+step,maxi(1,ceili(entries.size()/8.0)))
   _refresh()
  elif event.button_index==MOUSE_BUTTON_LEFT:
   player.input_controller.pointer_consumed()
   if event.pressed and not _hold: _pick(event.position); _confirm()
  if event.button_index!=MOUSE_BUTTON_RIGHT: get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
 if not visible: return
 if player.health_component.is_dead or player.ui_blocked: close(); return
 _elapsed+=delta
 if _elapsed>=.2: _elapsed=0; _refresh()
