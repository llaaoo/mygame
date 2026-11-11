extends "res://tests/support/input_scene_probe.gd"
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
func run() -> void:
 root.size=Vector2i(1152,648)
 var fixture:=Fixture.new(self); game=await fixture.boot()
 check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
 var actor:=game.player; var manager:=actor.skill_manager; var store:=game.session.inventory
 for id in ["focus","water_call","inscribe","project"]: game.progress.actions[id]=true
 for rule in manager.combinations.rules: game.progress.spell_rules[rule.id]=true
 game._apply_knowledge()
 var focus:=SpellOperationCatalog.default_catalog().operation("attune").action
 var water:=manager.pool.get_skill("water_call")
 manager.equip_source("left",water,{"payload":"","modifier":"","uid":""})
 manager.equip_source("quick_e",focus,{"mode":"auto"})
 actor.position=Vector2(-3500,2300)
 check(manager.use_source("left",actor,CastContext.at_position(actor,actor.position,water)),"Actual water creation refused")
 manager.combinations.tick(1); await frames()
 var plan:=manager.preview_source("quick_e",true)
 check(manager.spell_forms.affinity=="water" and plan.ready and plan.rule_id=="terrain_water_focus" and plan.cost==8,"Intelligent mode still blocks actual water-to-flow combination")
 check(not manager.preview_source("quick_e",false).ready,"Terrain form fell back to a free ordinary buff without Shift")
 var context:=CastContext.simple(actor,Vector2.RIGHT,focus); context.empower=true
 check(manager.use_source("quick_e",actor,context),"Intelligent water attunement refused")
 manager.combinations.tick(1)
 check(actor.get_node("BuffManager").has_buff("flow_attunement"),"Intelligent flow status not applied")
 manager.combinations.cooldowns.clear()
 check(not manager.preview_source("quick_e",true).ready,"Consumed ground silently became basic attunement")
 # Every authored terrain form requires its real existing combination, not its base effect.
 for row in [["fire","burning"],["water","wet"],["frost","frozen"],["storm","electrified"],["poison","poisoned"]]:
  manager.combinations.reset_session(); actor.get_node("BuffManager").clear_temporary(); actor.mana_component.mp=60
  manager.shortcuts.set_selection("quick_e",{"payload":"terrain_"+row[0],"modifier":"","uid":""})
  SurfaceManager.instance.force_set_surface(SurfaceManager.cell_at(actor.position),row[1],20)
  var ready:=manager.preview_source("quick_e",true)
  check(ready.ready and ready.rule_id.begins_with("terrain_"),"Terrain form missing existing rule: "+row[0])
  var before:=actor.mana_component.mp
  context=CastContext.simple(actor,Vector2.RIGHT,focus); context.empower=true
  check(manager.use_source("quick_e",actor,context),"Terrain preparation refused: "+row[0])
  SurfaceManager.instance.force_set_surface(SurfaceManager.cell_at(actor.position),"dry",0)
  manager.combinations.tick(1)
  check(actor.mana_component.mp==before,"Changing terrain during preparation spent MP: "+row[0])
 # Duplicate actual form is skipped without spending, rebuilding or changing shared cooldown.
 manager.equip_source("quick_e",SpellOperationCatalog.default_catalog().operation("project").action,{"mode":"auto"})
 manager.combinations.reset_session(); actor.get_node("BuffManager").clear_temporary(); actor.mana_component.mp=60
 var fire:=manager.pool.get_skill("inscribe")
 manager.equip_source("slot_4",fire,{"payload":"ember","modifier":"","uid":""})
 store.receive("player","fire_stone",2); store.receive("player","resin",1)
 context=CastContext.simple(actor,Vector2.RIGHT,fire)
 check(manager.use_source("slot_4",actor,context),"Context-setting fire rune refused: "+manager.preview_source("slot_4").reason)
 manager.combinations.tick(1)
 var stock:=store.snapshot(); var mana:=actor.mana_component.mp; var inst:=manager.get_instance("quick_e")
 check(QuickslotMaterials.cycle(actor,"quick_e",1) and manager.selection_for_source("quick_e").get("payload")=="cinder_volley","First notch repeated the auto form")
 check(store.snapshot()==stock and actor.mana_component.mp==mana and manager.get_instance("quick_e")==inst,"Form cycling mutated resource/skill state")
 var rows:=QuickslotMaterials.options(actor,"quick_e")
 check(rows.any(func(entry: Dictionary): return entry.variant_id=="cinder_volley" and entry.detail.contains("口袋") and entry.detail.contains("火阵")),"Source hint hid material count")
 manager.combinations.cooldowns.clear()
 # Rebind through the real binding authority, then exercise an actual world wheel event.
 actor.input_controller.last_spell_source="quick_e"; actor.material_wheel.remember_source("slot_4")
 manager.shortcuts.bind_item("quick_e","clean_water")
 check(actor.input_controller.scroll_source()=="slot_4","Invalid old binding masks a valid material selector")
 GameRuntime.instance.set_process(true)
 var motion:=InputEventMouseMotion.new(); motion.position=Vector2(550,300); root.push_input(motion,true); await frames()
 var event:=InputEventMouseButton.new(); event.position=motion.position; event.button_index=MOUSE_BUTTON_WHEEL_DOWN; event.pressed=true
 root.push_input(event,true); await frames()
 event=event.duplicate(); event.pressed=false; root.push_input(event,true); await frames()
 check(manager.selection_for_source("slot_4").get("payload")=="arcane","Actual wheel did not skip unavailable materials after rebinding")
 # Trade previews are read-only and report the actual shortfall, commit remains atomic.
 actor.position=TownServices.POINT+Vector2(0,35)
 var uid:=store.find_owned(TownServices.MERCHANT,"charcoal")
 var snapshot:=store.snapshot()
 check(game.town_services.preview_trade(uid,false,3).reason=="currency" and store.snapshot()==snapshot,"Trade preview lacks specific reason or changes inventory")
 check(not game.town_services.transact(uid,false,3).accepted and store.snapshot()==snapshot,"Rejected quantity trade altered stock/payment")
 game.town_services.show(false); await frames()
 await click("炭屑 ×6 · 2币")
 var quantity:=game.town_services._trade_quantity
 var arrow:=quantity.get_global_rect().position+Vector2(quantity.size.x-8,8)
 await point_click(arrow); await point_click(arrow)
 check(int(quantity.value)==3,"Actual quantity arrows did not select three")
 var details:=game.town_services._screen.detail
 check(details.find_children("*","Label",true,false).any(func(n): return n.text.contains("总价6币") and n.text.contains("缺少6币")),"Quantity UI lacks total/shortfall")
 check(details.find_children("*","Button",true,false).filter(func(n): return n.text.begins_with("购买")).all(func(n): return n.disabled),"Unaffordable purchase button remains enabled")
 await click("购买所选数量")
 check(store.snapshot()==snapshot,"Disabled real purchase click changed inventory")
 await capture("followup-trade-total")
 await fixture.close()
 if failures.is_empty(): print("PASS followup fixes: actual intelligent flow, terrain/Shift/source invalidation matrix, distinct scrolling, preserved costs/instances, invalid-binding recovery, complete source detail and atomic read-only trade preview")
 quit(0 if failures.is_empty() else 1)
