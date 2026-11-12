class_name ActorInventoryScreen
extends CanvasLayer
## One live inventory/gear screen. Every mutation goes through injected domain requests.
var actor: Player
var actions: InventoryActions
var session: CampaignSession
var use_request: Callable
var notify: Callable
var navigation_request: Callable
var _navigation: ExpeditionNavigation
var page_request: Callable:
 set(value):
  page_request=value
  if is_instance_valid(_navigation): _navigation.navigate=value; _navigation.visible=value.is_valid()
var configure_request: Callable
var _view_context: Dictionary={}
var _view_generation := 0
var _categories: Dictionary={}
var _containers: Dictionary={}
var _gear_column: VBoxContainer
var _gear_scroll: ScrollContainer
var ground_id := ""
var selected := ""
var mode := "all"
var selected_slot := -1
var container_filter := "all"
var _panel: PanelContainer
var _columns: HBoxContainer
var _bag: VBoxContainer
var _details: VBoxContainer
var _detail_column: VBoxContainer
var _detail_actions: GridContainer
var _binding_host: VBoxContainer
var _binding_open := false
var _compare_open := false
var _compare_return_scroll := 0
var _more_open := false
var _grid_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _portrait: PaperDollView
var _grid: GridContainer
var _search: LineEdit
var _summary: Label
var _mini_vitals: Label
var _clock_label: Label
var _place_label: Label
var _coins_label: Label
var _sort: OptionButton
var _grid_toggle: Button
var _grid_mode := false
var _stats: Label
var _needs_label: Label
var _state_label: Label
var _item_art: ItemArtView
var _quantity: SpinBox
var _popup: PopupMenu
var _dirty := true
var _refresh_time:=0.0
var _detail_clock:=0.0
var _last_health:=100
var _alert: Label
var _message := ""
var _message_time := 0.0
var _damage_warning_time := 0.0
var _tiles: Dictionary={}
var _detail_signature: Dictionary={}
var _portrait_signature: Array=[]
func _ready() -> void:
 layer=GameUIStyle.LAYER_MODAL
 add_to_group("modal_ui")
 _build(); hide()
 session.inventory.changed.connect(_invalidate)
 actor.health_component.health_changed.connect(_health_changed)
 get_viewport().size_changed.connect(_layout)
 _layout()
func _exit_tree() -> void:
 if session and session.inventory.changed.is_connected(_invalidate): session.inventory.changed.disconnect(_invalidate)
func open(focus := "all",ground := "") -> void:
 if actor.health_component.is_dead or not GameUIStyle.can_open(self): return
 _view_generation+=1
 mode=focus; ground_id=ground; selected=""; selected_slot=-1; container_filter="all"
 _search.text=""; _binding_open=false; _compare_open=false; _more_open=false; _detail_signature.clear(); _last_health=actor.health_component.hp
 _dirty=true; show(); GameUIStyle.begin_modal(self); _refresh(); _focus_entry.call_deferred()
func _focus_entry() -> void:
 if not visible: return
 var focus:=_panel.find_next_valid_focus()
 if focus: focus.grab_focus()
func open_item(definition_id: String, preferred_uid := "") -> void:
 open("equipment" if session.inventory.definitions.get(definition_id) is EquipmentData else "all")
 var sources:=session.inventory.actor_containers(actor.actor_context.id)
 sources.push_front(actor.actor_context.id+".gear")
 for container in sources:
  for row in session.inventory.entries(container):
   if row.definition!=definition_id or not preferred_uid.is_empty() and row.uid!=preferred_uid: continue
   _select(row.uid)
   var tile: Control=_tiles.get(row.uid)
   if tile:
    var parent:=tile.get_parent()
    while parent:
     if parent is ScrollContainer: parent.ensure_control_visible(tile)
     parent=parent.get_parent()
   return
 _message="这件实物已不在随身容器。"; _message_time=3
func resume() -> void:
 if _view_context.is_empty(): open(); return
 open(str(_view_context.mode))
 container_filter=str(_view_context.container); selected_slot=int(_view_context.slot)
 _search.text=str(_view_context.query)
 _grid_mode=bool(_view_context.get("grid",false)); _sort.select(int(_view_context.get("sort",0))); _grid_toggle.text="列表" if _grid_mode else "网格"; _layout()
 selected=str(_view_context.selected) if session.inventory.item(str(_view_context.selected)) else ""
 _refresh()
 _restore_scroll.call_deferred()
func _restore_scroll() -> void:
 _grid_scroll.scroll_vertical=int(_view_context.get("list_scroll",0))
 _detail_scroll.scroll_vertical=int(_view_context.get("detail_scroll",0))
func close() -> void:
 if visible: _view_context={"mode":mode,"container":container_filter,"slot":selected_slot,"query":_search.text,"selected":selected,"list_scroll":_grid_scroll.scroll_vertical,"detail_scroll":_detail_scroll.scroll_vertical,"grid":_grid_mode,"sort":_sort.selected}
 _view_generation+=1
 _popup.hide(); hide(); GameUIStyle.end_modal(self)
func _input(event: InputEvent) -> void:
 if visible and GameUIStyle.focus_navigation(self,event): return
 if not visible or not event is InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_ESCAPE: return
 if _damage_warning_time>0:
  close(); get_viewport().set_input_as_handled(); return
 if _binding_open:
  _binding_open=false; _detail_signature.clear(); _show_detail(); get_viewport().set_input_as_handled(); return
 # Escape dismisses a picker first; otherwise it always returns to combat,
 # including while a quantity/search field owns keyboard focus.
 if _popup.visible: return
 for picker in _details.find_children("*","OptionButton",true,false):
  if picker.get_popup().visible: return
 close(); get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
 if not visible or not event is InputEventKey or not event.pressed or event.echo: return
 if InputBindings.menu_key(event)==KEY_ESCAPE: close(); get_viewport().set_input_as_handled()
 elif InputBindings.menu_key(event)==KEY_O and not get_viewport().gui_get_focus_owner() is LineEdit:
  mode="equipment"; selected_slot=-1; _invalidate(); get_viewport().set_input_as_handled()
 elif InputBindings.menu_key(event)==KEY_N and not get_viewport().gui_get_focus_owner() is LineEdit:
  mode="supplies"; selected_slot=-1; _invalidate(); get_viewport().set_input_as_handled()
 elif InputBindings.menu_key(event) in [KEY_I,KEY_K,KEY_G,KEY_J,KEY_M] and not get_viewport().gui_get_focus_owner() is LineEdit:
  close()
  if InputBindings.menu_key(event)!=KEY_I and navigation_request.is_valid(): navigation_request.call(InputBindings.menu_key(event))
  get_viewport().set_input_as_handled()
func _build() -> void:
 var background:=ColorRect.new(); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.color=GameUIStyle.modal_backdrop(.55); add_child(background)
 _panel=PanelContainer.new(); _panel.name="InventoryMenu"; _panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 _panel.add_theme_stylebox_override("panel",GameUIStyle.menu_style()); background.add_child(_panel)
 var root:=VBoxContainer.new(); root.add_theme_constant_override("separation",10); _panel.add_child(root)
 _navigation=GameUIStyle.menu_header(root,"行囊","inventory",close,page_request)
 var ribbon:=HBoxContainer.new(); root.add_child(ribbon)
 _place_label=FoundationWidgets.label(_place_title(),12,true); ribbon.add_child(_place_label)
 _alert=FoundationWidgets.label("",12); _alert.modulate.a=0; ribbon.add_child(_alert)
 _clock_label=FoundationWidgets.label("",12,true); _clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; ribbon.add_child(_clock_label)
 for label in [_place_label,_alert,_clock_label]:
  label.autowrap_mode=TextServer.AUTOWRAP_OFF; label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 _columns=HBoxContainer.new(); _columns.add_theme_constant_override("separation",22); _columns.size_flags_vertical=Control.SIZE_EXPAND_FILL; root.add_child(_columns)
 _gear_scroll=ScrollContainer.new(); _gear_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; _gear_scroll.follow_focus=true
 _gear_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _gear_scroll.size_flags_stretch_ratio=.26
 _columns.add_child(_gear_scroll)
 var gear:=VBoxContainer.new(); _gear_column=gear; gear.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _gear_scroll.add_child(gear)
 gear.add_child(FoundationWidgets.label("当前穿戴",12,true))
 _portrait=PaperDollView.new(); _portrait.actor=actor; _portrait.select_slot=_select_slot; _portrait.equip_uid=_equip; gear.add_child(_portrait)
 _stats=FoundationWidgets.label("",12,true); gear.add_child(_stats)
 _needs_label=FoundationWidgets.label("",12,true); gear.add_child(_needs_label)
 if actor.survival: gear.add_child(FoundationWidgets.button("恢复与休整",actor.survival.show_rules))
 _columns.add_child(VSeparator.new())
 _bag=VBoxContainer.new(); _bag.add_theme_constant_override("separation",7); _bag.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _bag.size_flags_stretch_ratio=.34; _columns.add_child(_bag)
 var bag_heading:=HBoxContainer.new(); bag_heading.name="BagHeading"; _bag.add_child(bag_heading)
 bag_heading.add_child(FoundationWidgets.label("随身物品",16))
 _coins_label=FoundationWidgets.label("",14); _coins_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; _coins_label.add_theme_color_override("font_color",GameUIStyle.GOLD); bag_heading.add_child(_coins_label)
 var containers:=HBoxContainer.new(); _bag.add_child(containers)
 for pair in [["全部来源","all"],["口袋","pocket"],["背包","pack"],["地面","ground"]]:
  var button:=FoundationWidgets.button(pair[0],func(): container_filter=pair[1]; _invalidate())
  GameUIStyle.apply_tab(button,container_filter==pair[1]); _containers[pair[1]]=button; containers.add_child(button)
 var category:=HBoxContainer.new(); _bag.add_child(category)
 for pair in [["全部","all"],["装备","equipment"],["补给","supplies"],["材料","materials"]]:
  var button:=FoundationWidgets.button(pair[0],func(): mode=pair[1]; selected_slot=-1; _invalidate())
  GameUIStyle.apply_tab(button,mode==pair[1]); _categories[pair[1]]=button; category.add_child(button)
 var tools:=HBoxContainer.new(); _bag.add_child(tools)
 _search=LineEdit.new(); _search.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _search.clear_button_enabled=true; _search.placeholder_text="搜索名称…"
 _search.text_changed.connect(func(_text): _invalidate()); tools.add_child(_search)
 _grid_toggle=FoundationWidgets.button("网格",func(): _grid_mode=not _grid_mode; _grid_toggle.text="列表" if _grid_mode else "网格"; _layout(); _invalidate())
 _grid_toggle.size_flags_horizontal=Control.SIZE_SHRINK_END; tools.add_child(_grid_toggle)
 _sort=OptionButton.new(); _sort.name="InventorySort"
 for title in ["按类别","按名称","按总重","按参考总值"]: _sort.add_item(title)
 GameUIStyle.apply_font_size(_sort,12); _sort.item_selected.connect(func(_index): _invalidate()); _bag.add_child(_sort)
 _grid_scroll=ScrollContainer.new(); _grid_scroll.name="InventoryGridScroll"; _grid_scroll.follow_focus=true; _grid_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 _grid_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; _bag.add_child(_grid_scroll)
 _grid=GridContainer.new(); _grid.columns=1; _grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _grid.add_theme_constant_override("h_separation",6); _grid.add_theme_constant_override("v_separation",5); _grid_scroll.add_child(_grid)
 _summary=FoundationWidgets.label("",12,true); _bag.add_child(_summary)
 _columns.add_child(VSeparator.new())
 _detail_column=VBoxContainer.new(); _detail_column.name="DetailColumn"
 _detail_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _detail_column.size_flags_stretch_ratio=.40; _columns.add_child(_detail_column)
 _detail_scroll=ScrollContainer.new(); _detail_scroll.name="ItemReading"; _detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 _detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; _detail_scroll.follow_focus=true; _detail_column.add_child(_detail_scroll)
 _details=VBoxContainer.new(); _details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _details.add_theme_constant_override("separation",12); _detail_scroll.add_child(_details)
 _binding_host=VBoxContainer.new(); _binding_host.name="BindingPicker"; _binding_host.visible=false; _detail_column.add_child(_binding_host)
 _detail_column.add_child(HSeparator.new())
 _detail_actions=GridContainer.new(); _detail_actions.columns=2; _detail_actions.name="ItemActions"; _detail_actions.add_theme_constant_override("h_separation",6); _detail_actions.add_theme_constant_override("v_separation",6); _detail_column.add_child(_detail_actions)
 root.add_child(HSeparator.new())
 var footer:=HBoxContainer.new(); footer.add_theme_constant_override("separation",12); root.add_child(footer)
 footer.add_child(FoundationWidgets.label("双击 使用/穿戴 · 右键 更多 · Shift 比较",12,true))
 var drop_zone:=InventoryItemTile.new(); drop_zone.name="GroundDropZone"; drop_zone.text="拖放丢弃"
 GameUIStyle.apply_button(drop_zone,GameUIStyle.GOLD); drop_zone.tooltip_text="将实物拖到这里丢弃；保留在附近地面，可拾回。"
 drop_zone.accept_item=func(uid: String): return session.inventory.locate(uid) in session.inventory.actor_containers(actor.actor_context.id)+[actor.actor_context.id+".gear"]
 drop_zone.request_drop=func(uid: String): _select(uid); _drop_quantity(session.inventory.item(uid).quantity)
 footer.add_child(drop_zone)
 _mini_vitals=FoundationWidgets.label("",12); _mini_vitals.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; footer.add_child(_mini_vitals)
 _popup=PopupMenu.new(); add_child(_popup); _popup.id_pressed.connect(_context_action)
func _layout() -> void:
 if not _panel: return
 var viewport:=get_viewport().get_visible_rect().size
 var extent:=GameUIStyle.menu_extent(viewport)
 _panel.offset_left=-extent.x*.5; _panel.offset_right=extent.x*.5; _panel.offset_top=-extent.y*.5; _panel.offset_bottom=extent.y*.5
 _gear_scroll.custom_minimum_size.x=182 if viewport.x<1100 else 260
 _detail_column.custom_minimum_size.x=300
 _bag.custom_minimum_size.x=230
 _columns.add_theme_constant_override("separation",10 if viewport.x<1100 else 18)
 _grid.columns=2 if _grid_mode and viewport.x>=1200 else 1
 _bag.get_node("BagHeading").visible=viewport.y>=650
 _sort.visible=viewport.y>=650
 if _portrait and _portrait._preview: _portrait.set_compact(viewport.y<650)
 if is_instance_valid(_item_art): _item_art.custom_minimum_size.y=_art_height()
func _art_height() -> float:
 var height:=get_viewport().get_visible_rect().size.y
 return 96.0 if height<650 else 140.0 if height<800 else 180.0
func _place_title() -> String:
 var place:=session.catalog.regions.get(session.region.id) as ExplorationRegionData
 return place.title if place else "行装"
func _invalidate() -> void: _dirty=true
func _process(delta: float) -> void:
 if not visible: return
 if actor.health_component.is_dead: close(); return
 if not ground_id.is_empty() and not session.ground_available(actor,ground_id):
  ground_id=""; _invalidate(); _message="地面物资已不在附近。"; _message_time=3
 _refresh_time+=delta; _message_time=maxf(0,_message_time-delta); _damage_warning_time=maxf(0,_damage_warning_time-delta)
 if _dirty and _refresh_time>.1 and not get_viewport().gui_is_dragging() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _popup.visible: _refresh()
 var context:=actor.actor_context
 _summary.text="%.1f / %.0f负重 · %d / %d格%s"%[session.inventory.weight(context.id),context.rules.carry_limit+float(ActorProgression.values(actor).carry_bonus),session.inventory.occupied_slots(context.id+".pack"),context.rules.pack_capacity," · 背包已放下" if not session.inventory.is_attached(context.id+".pack") else ""]
 _summary.tooltip_text="口袋 %d/%d格 · 背包 %d/%d格"%[session.inventory.occupied_slots(context.id+".pocket"),context.rules.pocket_capacity,session.inventory.occupied_slots(context.id+".pack"),context.rules.pack_capacity]
 _coins_label.text="◉ %d"%session.inventory.count(context.id,"coin")
 _place_label.text=_place_title()
 _clock_label.text=WorldTime.instance.stamp() if WorldTime.instance else ""
 _mini_vitals.text="生命 %d/%d   体力 %.0f/%.0f"%[actor.health_component.hp,actor.health_component.max_hp,context.actions.stamina.current,context.actions.stamina.maximum]
 _alert.text=_message if _message_time>0 else ""; _alert.modulate.a=1 if _message_time>0 else 0; _alert.tooltip_text=_alert.text
 _refresh_stats()
 _detail_clock+=delta
 if _detail_clock>=.15:
  _detail_clock=0
  _show_detail()
 if is_instance_valid(_state_label) and _state_label.is_inside_tree():
  var item:=_selected_item()
  if item:
   var definition:=session.inventory.equipment_definition(item.uid) if session.inventory.definitions.get(item.definition_id) is EquipmentData else session.inventory.definitions.get(item.definition_id) as ItemData
   if definition: _state_label.text=_item_state_text(item,definition); _state_label.visible=not _state_label.text.is_empty()
func _health_changed(hp: int,_max_hp: int) -> void:
 if visible and hp<_last_health: _damage_warning_time=3; _message="遭到袭击 · Esc 合上行囊"; _message_time=3; _alert.add_theme_color_override("font_color",GameUIStyle.DANGER)
 _last_health=hp
func _rows() -> Array[Dictionary]:
 var rows: Array[Dictionary]=[]
 var context:=actor.actor_context
 var containers:=session.inventory.actor_containers(context.id)
 containers.append(context.id+".gear")
 if not ground_id.is_empty() and session.ground_available(actor,ground_id): containers.append(ground_id)
 for container in containers:
  var kind: String="ground" if container==ground_id else "pocket" if container.ends_with(".pocket") else "pack" if container.ends_with(".pack") else "gear"
  if container_filter!="all" and container_filter!=kind: continue
  for row in session.inventory.entries(container):
   var definition:=session.inventory.equipment_definition(row.uid) if session.inventory.definitions.get(row.definition) is EquipmentData else session.inventory.definitions.get(row.definition) as ItemData
   if not definition: continue
   var supply: bool=definition.use_profile!=null or SurvivalCatalog.FOODS.has(definition.id) or definition.item_type==ItemData.ItemType.CONSUMABLE
   if mode=="equipment" and not definition is EquipmentData or mode=="supplies" and not supply or mode=="materials" and (definition is EquipmentData or supply): continue
   if selected_slot>=0 and (not definition is EquipmentData or definition.slot_type!=selected_slot): continue
   if not _search.text.is_empty() and not (definition.display_name+definition.description).contains(_search.text): continue
   var record:=row.duplicate(true); record["container"]=container; record["place"]=kind; rows.append(record)
 if _sort.selected>0:
  rows.sort_custom(func(a: Dictionary,b: Dictionary):
   var left: ItemData=session.inventory.definitions[a.definition]; var right: ItemData=session.inventory.definitions[b.definition]
   var av: Variant=left.display_name if _sort.selected==1 else left.weight*a.quantity if _sort.selected==2 else left.sell_price*a.quantity
   var bv: Variant=right.display_name if _sort.selected==1 else right.weight*b.quantity if _sort.selected==2 else right.sell_price*b.quantity
   return str(a.uid)<str(b.uid) if av==bv else av<bv if _sort.selected==1 else av>bv)
 return rows
func _refresh() -> void:
 _dirty=false; _refresh_time=0
 for id in _categories: GameUIStyle.apply_tab(_categories[id],mode==id)
 for id in _containers: GameUIStyle.apply_tab(_containers[id],container_filter==id)
 var gear: Array=[session.inventory.entries(actor.actor_context.id+".gear"),session.inventory.is_attached(actor.actor_context.id+".pack"),PresentationPreferences.value("text_scale")]
 if gear!=_portrait_signature:
  _portrait_signature=gear.duplicate(true); _portrait.refresh()
 _refresh_stats()
 var rows:=_rows()
 var retained: Dictionary={}
 for index in range(rows.size()):
  var row: Dictionary=rows[index]
  var definition:=session.inventory.equipment_definition(row.uid) if session.inventory.definitions.get(row.definition) is EquipmentData else session.inventory.definitions.get(row.definition) as ItemData
  var tile:=_tiles.get(row.uid) as InventoryItemTile
  if not is_instance_valid(tile):
   tile=InventoryItemTile.new(); tile.item_uid=row.uid; tile.set_meta("ui_action","inventory_item"); tile.set_meta("item_uid",row.uid); tile.name="Item_"+row.uid.replace(".","_")
   tile.custom_minimum_size.x=0; tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tile.clip_text=true
   tile.pressed.connect(_select.bind(row.uid)); tile.activated.connect(_activate); tile.secondary_requested.connect(_context)
   _tiles[row.uid]=tile; _grid.add_child(tile)
  var subtitle: String={"pocket":"随身口袋","pack":"背包","gear":"已穿戴","ground":"地面"}[row.place]
  for source in QuickslotLoadout.SOURCES:
   var binding:=actor.skill_manager.shortcuts.binding(source)
   if binding.get("kind","")=="item" and binding.get("item_id","")==definition.id and (str(binding.get("uid","")).is_empty() or binding.uid==row.uid): subtitle+=" · 已绑定"; break
  if definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY:
   subtitle+=" · 瓶%s · %d剂"%[str(row.uid).trim_prefix("item."),int(session.inventory.item(row.uid).properties.get("doses",0))]
  tile.present(InterfaceIcons.item(definition),definition.display_name,subtitle,"×%d"%row.quantity,_grid_mode)
  tile.tooltip_text=definition.display_name+"\n"+session.inventory.state_text(row.uid)
  GameUIStyle.apply_button(tile,GameUIStyle.GOLD,selected==row.uid)
  if tile.get_index()!=index: _grid.move_child(tile,index)
  retained[row.uid]=true
 for uid in _tiles.keys():
  if retained.has(uid): continue
  var tile:=_tiles[uid] as InventoryItemTile
  _tiles.erase(uid)
  if is_instance_valid(tile):
   _grid.remove_child(tile); tile.queue_free()
 var placeholder:=_grid.get_node_or_null("EmptyInventory") as Label
 if rows.is_empty() and not placeholder:
  placeholder=FoundationWidgets.label("这里没有符合条件的实物。",14,true); placeholder.name="EmptyInventory"; placeholder.custom_minimum_size.x=220; _grid.add_child(placeholder)
 elif not rows.is_empty() and placeholder:
  _grid.remove_child(placeholder); placeholder.queue_free()
 _show_detail()
func _refresh_stats() -> void:
 if actor.survival:
  var needs:=actor.survival.needs
  _needs_label.text="旅途状态\n饱食 %.0f · 饮水 %.0f\n疲劳 %.0f"%[needs.nutrition,needs.hydration,needs.fatigue]
  _needs_label.tooltip_text=actor.survival.timers_line()
 var stats:=actor.stats_component
 _stats.text="力量 %d · 智力 %d\n敏捷 %d · 耐力 %d\n生命 %d · %s"%[stats.effective_stat("strength"),stats.effective_stat("intelligence"),stats.effective_stat("agility"),stats.effective_stat("endurance"),actor.health_component.max_hp,QuickslotView.magic_status(actor)]
func _select(uid: String) -> void:
 if uid!=selected:
  _view_generation+=1
  if is_instance_valid(_quantity): _quantity.value=1
  _binding_open=false; _compare_open=false; _more_open=false; _detail_scroll.scroll_vertical=0
 var previous:=selected
 selected=uid
 for key in [previous,uid]:
  if _tiles.has(key): GameUIStyle.apply_button(_tiles[key],GameUIStyle.GOLD,key==selected)
 _show_detail()
func _select_slot(slot: int) -> void:
 selected_slot=slot; mode="equipment"; container_filter="all"
 selected=str(session.inventory.equipped(actor.actor_context.id).get(str(slot),"")); _invalidate()
func _selected_item() -> ItemInstance: return session.inventory.item(selected)
func _item_state_text(item: ItemInstance,definition: ItemData) -> String:
 var text:=session.inventory.state_text(item.uid)
 if SurvivalCatalog.FOODS.has(definition.id):
  var food: Dictionary=SurvivalCatalog.FOODS[definition.id]
  text+="\n食用：饱食%+.0f · 饮水%+.0f · 疲劳%+.0f"%[food.nutrition,food.hydration,food.fatigue]
 return text
func _equipment_permission(item: ItemInstance) -> String:
 if not item: return ""
 var definition:=session.inventory.definitions.get(item.definition_id) as EquipmentData
 if not definition: return ""
 if session.inventory.locate(item.uid).ends_with(".gear"):
  return actions.unequip_reason(definition.slot_type)
 return actions.equip_reason(item.uid)
func _show_detail() -> void:
 var item:=_selected_item()
 var permission:=_equipment_permission(item)
 var signature: Dictionary={"permission":permission,"uid":selected,"item":item.snapshot() if item else {},"location":session.inventory.locate(selected),"gear":session.inventory.entries(actor.actor_context.id+".gear"),"accessible":session.inventory.actor_containers(actor.actor_context.id),"ground":ground_id,"shortcuts":actor.skill_manager.shortcuts.snapshot(),"binding":_binding_open,"compare":_compare_open or Input.is_key_pressed(KEY_SHIFT),"more":_more_open}
 if signature==_detail_signature: return
 var was_comparing: bool=_detail_signature.get("uid","")==selected and bool(_detail_signature.get("compare",false))
 var comparing:=bool(signature.compare)
 if comparing and not was_comparing: _compare_return_scroll=_detail_scroll.scroll_vertical
 _detail_signature=signature.duplicate(true)
 var focus:=get_viewport().gui_get_focus_owner()
 var focus_action: String=focus.text if focus is Button and (_details.is_ancestor_of(focus) or _detail_actions.is_ancestor_of(focus) or _binding_host.is_ancestor_of(focus)) else ""
 var old_quantity:=int(_quantity.value) if is_instance_valid(_quantity) else 1
 FoundationWidgets.clear(_details); FoundationWidgets.clear(_detail_actions); FoundationWidgets.clear(_binding_host); _binding_host.visible=false; _quantity=null; _state_label=null; _item_art=null
 if not item:
  var icon:=TextureRect.new(); icon.texture=GameUIStyle.icon("backpack"); icon.modulate=Color(GameUIStyle.GOLD,.45)
  icon.custom_minimum_size=Vector2(48,64); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  _details.add_child(icon)
  _details.add_child(FoundationWidgets.label("为下一程做好准备",20))
  _details.add_child(FoundationWidgets.label("清点随身物品，挑选下一程的行装。",14,true))
  FoundationWidgets.disclosure(_details,"行囊操作","双击使用或换装，右键管理。材料可查看已知用途；实物可直接绑定快捷槽。物品满载时，可丢弃到地面并随后拾回。")
  return
 var location:=session.inventory.locate(item.uid)
 var definition:=session.inventory.equipment_definition(item.uid) if session.inventory.definitions.get(item.definition_id) is EquipmentData else session.inventory.definitions.get(item.definition_id) as ItemData
 var item_heading:=HBoxContainer.new(); item_heading.add_theme_constant_override("separation",12); _details.add_child(item_heading)
 var words:=VBoxContainer.new(); words.size_flags_horizontal=Control.SIZE_EXPAND_FILL; item_heading.add_child(words)
 var kind: String="装备" if definition is EquipmentData else "补给" if definition.use_profile or SurvivalCatalog.FOODS.has(definition.id) else "材料"
 var eyebrow:=FoundationWidgets.label(kind+" / "+{"pocket":"口袋","pack":"背包","gear":"穿戴","ground":"地面"}.get("gear" if location.ends_with(".gear") else "pocket" if location.ends_with(".pocket") else "pack" if location.ends_with(".pack") else "ground",""),12,true)
 eyebrow.add_theme_color_override("font_color",GameUIStyle.GOLD); words.add_child(eyebrow)
 words.add_child(FoundationWidgets.label(definition.display_name,22))
 _item_art=ItemArtView.new(); _item_art.name="ItemArtwork"; _details.add_child(_item_art)
 _item_art.present(definition,item.uid); _item_art.custom_minimum_size.y=_art_height()
 _details.add_child(FoundationWidgets.label("重量 %.1f · 参考价值 %d币%s"%[definition.weight,definition.sell_price," · "+EquipmentManager.slot_name(definition.slot_type) if definition is EquipmentData else ""],12,true))
 if definition is EquipmentData: EquipmentStatView.render(_details,null,definition,false)

 _state_label=FoundationWidgets.label(_item_state_text(item,definition),13,true)
 _state_label.visible=not _state_label.text.is_empty(); _details.add_child(_state_label)
 if item.quantity>1:
  _quantity=SpinBox.new(); _quantity.prefix="数量 "; _quantity.min_value=1; _quantity.max_value=item.quantity; _quantity.step=1; _quantity.value=mini(old_quantity,item.quantity); _detail_actions.add_child(_quantity)
 if location==ground_id and not ground_id.is_empty():
  _action("取走所选数量",func(): _result(actions.take(ground_id,selected,_amount())))
  _action("尽量取走这一叠",func(): _result(actions.take(ground_id,selected,item.quantity)))
  return
 if location not in session.inventory.actor_containers(actor.actor_context.id)+[actor.actor_context.id+".gear"]:
  _details.add_child(FoundationWidgets.label("实物已不在随身容器。",14,true)); return
 if definition is EquipmentData:
  if location.ends_with(".gear"): _action("卸下装备",func(): _result(actions.unequip(definition.slot_type)),not permission.is_empty())
  else: _action("装备这件",_equip.bind(item.uid),not permission.is_empty())
  if not permission.is_empty(): _details.add_child(FoundationWidgets.label(permission,13,true))
 elif definition.use_profile or SurvivalCatalog.FOODS.has(definition.id):
  _action("选择这瓶喷剂" if definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY else "使用一份",_use.bind(item.uid))
 if definition is EquipmentData or definition.use_profile or SurvivalCatalog.FOODS.has(definition.id):
  _action("绑定快捷槽",func(): _binding_open=not _binding_open; _show_detail())
  if _binding_open: _binding_picker(item,definition)
 _action("更多",func(): _more_open=not _more_open; _show_detail())
 if definition is EquipmentData: _action("比较",func(): _compare_open=not _compare_open; _show_detail())
 # Main actions are outside the reading scroll; management stays deliberate.
 if _more_open:
  if not location.ends_with(".gear"):
   _details.add_child(FoundationWidgets.button("移至口袋" if location.ends_with(".pack") else "移至背包",_transfer_selected))
   if item.quantity>1: _details.add_child(FoundationWidgets.button("拆分所选数量",func(): _result(actions.split(selected,_amount()))))
  _details.add_child(FoundationWidgets.button("丢弃所选数量",func(): _drop_quantity(_amount())))
  _details.add_child(FoundationWidgets.button("丢弃整叠",_drop_quantity.bind(item.quantity)))
 if definition is EquipmentData:
  if _compare_open or Input.is_key_pressed(KEY_SHIFT):
   var current:=actor.get_node("EquipmentManager").get_equipment(definition.slot_type) as EquipmentData
   if location.ends_with(".gear"):
    var note:=FoundationWidgets.label("当前穿戴这件装备。",14,true); note.name="EquipmentComparison"; _details.add_child(note)
   else: EquipmentStatView.render(_details,current,definition,true)
  if definition.moveset: FoundationWidgets.disclosure(_details,"武器动作",definition.moveset.describe())
 else: _material_uses(definition)
 FoundationWidgets.disclosure(_details,"物品来历与说明",definition.description)
 if comparing!=was_comparing: _comparison_reading_after_layout.call_deferred(selected,comparing)
 if not focus_action.is_empty(): _restore_action_focus.call_deferred(focus_action,selected)
func _comparison_reading_after_layout(uid: String,reveal: bool) -> void:
 var owner_ref: WeakRef=weakref(self)
 var generation:=_view_generation
 await get_tree().process_frame
 var screen:=owner_ref.get_ref() as ActorInventoryScreen
 if not screen or not screen.visible or screen._view_generation!=generation or screen.selected!=uid or bool(screen._detail_signature.get("compare",false))!=reveal: return
 if not reveal:
  screen._detail_scroll.scroll_vertical=screen._compare_return_scroll
  return
 var comparison:=screen._details.find_child("EquipmentComparison",true,false) as Control
 if comparison:
  screen._detail_scroll.scroll_vertical+=roundi(comparison.global_position.y-screen._detail_scroll.global_position.y-8)
func _restore_action_focus(title: String, uid: String) -> void:
 if not visible or selected!=uid: return
 for host in [_details,_detail_actions,_binding_host]:
  for button in host.find_children("*","Button",true,false):
   if button.text==title and button.is_visible_in_tree() and not button.disabled: button.grab_focus(); return
 var tile:=_tiles.get(uid) as Control
 if is_instance_valid(tile): tile.grab_focus()
func _action(title: String,request: Callable,disabled := false) -> void:
 var button:=FoundationWidgets.button(title,request,disabled); button.clip_text=true
 for state in ["normal","hover","pressed","focus","disabled"]:
  var style:=button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
  style.content_margin_left=7; style.content_margin_right=7; button.add_theme_stylebox_override(state,style)
 _detail_actions.add_child(button)
 if _detail_actions.get_child_count()==1: GameUIStyle.primary(button)
func _amount() -> int: return int(_quantity.value) if is_instance_valid(_quantity) else 1
func _binding_picker(item: ItemInstance,definition: ItemData) -> void:
 _binding_host.visible=true
 _binding_host.add_child(FoundationWidgets.label("选择快捷键",12,true))
 var grid:=GridContainer.new(); grid.columns=7; grid.name="QuickBind"; _binding_host.add_child(grid)
 for source in QuickslotLoadout.SOURCES:
  var binding:=actor.skill_manager.shortcuts.binding(source)
  var active: bool=binding.get("kind","")=="item" and binding.get("item_id","")==definition.id and (binding.get("uid","").is_empty() or binding.get("uid","")==item.uid)
  var button:=Button.new(); button.text=InputBindings.label(InputBindings.action_for_source(source))
  button.name="Bind_"+source; button.tooltip_text="将这件实物绑定到 "+button.text
  GameUIStyle.apply_button(button,GameUIStyle.GOLD,active); button.custom_minimum_size=Vector2(40,40)
  for state in ["normal","hover","pressed","focus","disabled"]:
   var style:=button.get_theme_stylebox(state).duplicate() as StyleBoxFlat; style.content_margin_left=3; style.content_margin_right=3; button.add_theme_stylebox_override(state,style)
  button.pressed.connect(func():
   var uid:=item.uid if definition is EquipmentData or definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY else ""
   var ok:=actor.skill_manager.shortcuts.bind_item(source,definition.id,uid)
   _message="已绑定到 "+button.text if ok else "无法绑定。"; _message_time=3
   if ok and actions.save_request.is_valid(): actions.save_request.call()
   _binding_open=false; _show_detail())
  grid.add_child(button)
func _material_uses(definition: ItemData) -> void:
 var uses: Array[String]=[]
 for operation in SpellOperationCatalog.default_catalog().operations:
  var used:=false
  for payload in operation.payloads:
   if payload.material_id==definition.id: used=true; uses.append(operation.action.display_name+" · "+payload.title)
  if used and configure_request.is_valid():
   _details.add_child(FoundationWidgets.button("配置「"+operation.action.display_name+"」",configure_request.bind(operation.action),not actor.skill_manager.knows_action(operation.action)))
 var supplies:=actor.skill_manager.combinations.supplies
 for recipe_id in supplies.crafting_recipes:
  var recipe: CraftingRecipe=supplies.crafting_recipes[recipe_id]
  if recipe.inputs.has(definition.id) and supplies.knows_recipe(recipe_id): uses.append("制造 · "+actor.skill_manager.combinations.supplies.title(recipe.output_id))
 if not uses.is_empty(): FoundationWidgets.disclosure(_details,"用途与配方", "\n".join(uses))
func _result(result: OperationResult) -> void:
 _message="已完成 · %d件"%result.moved if result.accepted else _reason(result.reason)
 _message_time=3; _alert.add_theme_color_override("font_color",GameUIStyle.TEXT_MAIN if result.accepted else GameUIStyle.GOLD)
 _invalidate(); _show_detail()
func _reason(value: String) -> String:
 return {"capacity":"容器已满，物品保留原处。","invalid_quantity":"数量已变化，请重新选择。","stale_plan":"物品发生变化，请重试。","not_owned":"实物已不在身上。"}.get(value,value)
func _equip(uid: String) -> void: _result(actions.equip(uid))
func _drop_quantity(quantity: int) -> void: _result(actions.drop(selected,quantity))
func _transfer_selected() -> void:
 var location:=session.inventory.locate(selected)
 var destination:=actor.actor_context.id+(".pocket" if location.ends_with(".pack") else ".pack")
 _result(actions.transfer(selected,destination,_amount()))
func _use(uid: String) -> void:
 if not use_request.is_valid(): return
 close(); use_request.call(uid)
func _activate(uid: String) -> void:
 _select(uid)
 var item:=session.inventory.item(uid)
 if not item: return
 if session.inventory.locate(uid)==ground_id: _result(actions.take(ground_id,uid,item.quantity)); return
 var definition:=session.inventory.equipment_definition(item.uid) if session.inventory.definitions.get(item.definition_id) is EquipmentData else session.inventory.definitions.get(item.definition_id) as ItemData
 if definition is EquipmentData:
  if session.inventory.locate(uid).ends_with(".gear"): _result(actions.unequip(definition.slot_type))
  else: _equip(uid)
 elif definition.use_profile or SurvivalCatalog.FOODS.has(definition.id): _use(uid)
func _context(uid: String,point: Vector2) -> void:
 _select(uid); _popup.clear()
 var item:=_selected_item()
 if not item: return
 if session.inventory.locate(uid)==ground_id: _popup.add_item("取走这一叠",0)
 else:
  _popup.add_item("使用 / 穿戴",0)
  _popup.add_item("丢弃一件",1); _popup.add_item("丢弃整叠",2)
  if not session.inventory.locate(uid).ends_with(".gear"): _popup.add_item("移动所选数量",3)
 _popup.position=Vector2i(point if get_viewport().gui_embed_subwindows else get_viewport().get_screen_transform()*point); _popup.popup()
func _context_action(id: int) -> void:
 match id:
  0: _activate(selected)
  1: _drop_quantity(1)
  2:
   var item:=_selected_item()
   if item: _drop_quantity(item.quantity)
  3: _transfer_selected()
