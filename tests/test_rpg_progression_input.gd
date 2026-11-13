extends "res://tests/support/input_scene_probe.gd"
## Normal world/AI; controlled earned XP, practice, recipe knowledge and stock.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
var starts := 0
func run() -> void:
 root.size=Vector2i(1152,648)
 var fixture:=Fixture.new(self); game=await fixture.boot(true)
 GameRuntime.instance.set_process(true)
 for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
 var actor:=game.player; var manager:=actor.mastery_manager; var stats:=actor.stats_component
 var store:=game.session.inventory
 actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 game.session.facts.committed.connect(func(fact):
  if fact.kind=="physical_action_started" and fact.source=="player": starts+=1)
 CombatExecutor.report_exp_bonus(actor,100)
 check(stats.level==2 and stats.attribute_points==3 and manager.get_available_perk_points()==1 and not actor.ui_blocked,"Level-up failed or forced an unsafe modal")
 await key(KEY_P,true); await key(KEY_P,false)
 check(is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("character_progression",false) and not paused,"P did not open the live progression page")
 # Script classes are queried through the mounted view, without bypassing its input.
 var view: CharacterProgressionScreen
 for node in game.ui.modal.find_children("*","VBoxContainer",true,false):
  if node is CharacterProgressionScreen: view=node; break
 check(view!=null and view._branch_buttons.size()==6 and not view._legacy_button.visible,"Fresh progression still exposes nine old schools or unowned legacy perks")
 await click("铭阵与调谐"); await click("稳固铭阵")
 check(view._perk_reason.text.contains("觉醒") and view._learn_button.disabled,"Magic tree permits an ordinary traveler to buy spell perks")
 await capture("rune-tree-unawakened")
 await click("属性与派生"); await click("耐力 +1")
 check(stats.endurance==11 and actor.actor_context.actions.stamina.maximum==102 and stats.attribute_points==2,"Real attribute button did not improve actual stamina")
 await capture("stamina-investment")
 await click("武器与武技"); await click("战斗调息"); await click("学习：战斗调息")
 check(manager.has_perk("battle_conditioning") and manager.get_available_perk_points()==0 and actor.actor_context.actions.stamina.maximum==117,"Real graph purchase did not apply its actual stamina/perk budget")
 await click("连段节能"); await click("学习：连段节能")
 check(not manager.has_perk("economical_strokes") and manager.get_available_perk_points()==0,"Locked graph button spent points or bypassed requirements")
 await capture("weapon-tree-requirements")
 var clock:=store.clock_seconds
 await frames(20)
 check(store.clock_seconds>clock and not paused,"Progression tree paused or slowed the simulation to zero")
 await key(KEY_P,true); await key(KEY_P,false)
 check(not actor.ui_blocked,"P did not close the progression page")
 await key(KEY_F5,true); await key(KEY_F5,false); await key(KEY_F9,true); await key(KEY_F9,false)
 check(manager.has_perk("battle_conditioning") and stats.endurance==11 and manager.get_available_perk_points()==0,"F5/F9 lost a learned perk or gave its spent point back")
 # Earned-XP/practice fixture makes the craft branch available; all subsequent inputs are actual UI.
 CombatExecutor.report_exp_bonus(actor,500000)
 manager.record_activity("recipe_crafted",40)
 await key(KEY_P,true); await key(KEY_P,false)
 await click("属性与派生"); await click("敏捷 +1"); await click("敏捷 +1")
 await click("制造与整修"); await click("工具熟习"); await click("学习：工具熟习")
 await click("箭簇整备"); await click("学习：箭簇整备")
 check(manager.has_perk("arrow_fletcher") and stats.agility==12,"Craft branch did not use actual practice/base-attribute prerequisites")
 await capture("craft-tree")
 GameUIStyle.set_text_scale(1.25,root)
 root.size=Vector2i(960,600); await frames(6)
 await click("野外与补给"); await click("识草")
 await capture("survival-tree-small")
 await click("猎材精取")
 for node in game.ui.modal.find_children("*","VBoxContainer",true,false):
  if node is CharacterProgressionScreen: view=node; break
 check(view._selected=="careful_harvester" and view._perk_reason.text.contains("剥皮"),"Small-window final row is unreachable or professional knowledge gate is missing")
 await key(KEY_TAB,true); await key(KEY_TAB,false)
 check(root.gui_get_focus_owner()!=null and game.ui.modal.is_ancestor_of(root.gui_get_focus_owner()),"Perk page focus escaped the live modal")
 await capture("harvest-tree-small")
 check(not paused and starts==0,"Progression clicks leaked physical attacks or paused the world")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 actor.position=Vector2(-3100,1835); actor.get_node("Camera2D").reset_smoothing()
 store.receive("player","charcoal",3); store.receive("player","metal_scrap",3)
 var supplies:=actor.skill_manager.combinations.supplies
 supplies.known_recipes.arrows=true
 var arrows:=store.count("player","arrow"); var metal:=store.count("player","metal_scrap")
 await frames(8); await key(KEY_F,true); await key(KEY_F,false)
 await click(supplies.title("arrow")); await capture("ammo-output-preview")
 await click("加工："+supplies.title("arrow"))
 check(store.count("player","arrow")==arrows+7 and store.count("player","metal_scrap")==metal-1,"Actual workshop click disagreed with perk output/payment preview")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 var saved:=manager.serialize_state(); var arrow_count:=store.count("player","arrow")
 game._save_progress(); await fixture.close()
 fixture=Fixture.new(self); game=await fixture.boot(true)
 check(game.player.mastery_manager.serialize_state()==saved and game.session.inventory.count("player","arrow")==arrow_count and game.player.stats_component.endurance==11,"New scene re-entry lost progression or refilled crafted items")
 GameRuntime.instance.set_process(true)
 for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
 game.player.position=Vector2(-4000,800); game.player.get_node("Camera2D").reset_smoothing(); await frames(6)
 # Legacy-save fixture keeps its real paid identity/benefit; UI offers no new legacy purchase.
 var inherited:=game.player.mastery_manager.serialize_state()
 inherited.unlocked_perks["0"]=["destruction_scorch"]
 game.player.mastery_manager.restore_state(inherited)
 await key(KEY_P,true); await key(KEY_P,false); await click("既有传承 · 1")
 var inherited_view: CharacterProgressionScreen
 for node in game.ui.modal.find_children("*","VBoxContainer",true,false):
  if node is CharacterProgressionScreen: inherited_view=node; break
 check(inherited_view!=null and inherited_view._legacy_view and not inherited_view._learn_button.visible and game.player.mastery_manager.has_perk("destruction_scorch"),"Inherited perk was lost, remained in active branches or offers a purchase button")
 await capture("legacy-inherited")
 # Explicit awakening/knowledge/practice fixture; the actual purchases remain mouse input.
 check(Awake.awaken(game.player),"Positive magic route fixture could not establish awakening")
 game.progress.actions.inscribe=true; game._apply_knowledge()
 game.player.mastery_manager.on_deal_damage(SkillMastery.School.ALTERATION,200)
 await click("属性与派生"); await click("智力 +1"); await click("智力 +1")
 await click("铭阵与调谐"); await click("稳固铭阵"); await click("学习：稳固铭阵")
 await click("阵能整流"); await click("学习：阵能整流")
 check(game.player.mastery_manager.has_perk("sigil_foundations") and game.player.mastery_manager.has_perk("sigil_economy"),"Qualified current rune nodes could not be purchased by real UI")
 await capture("rune-tree-learned")
 await fixture.close()
 if failures.is_empty(): print("PASS RPG input: actual P live tree, endurance/stamina investment, earned-budget purchase and locked nodes, F5/F9, qualified craft branch, small-window mouse graph/scroll, real seven-arrow craft/payment and actual save/re-entry; controlled XP/practice/stock")
 quit(0 if failures.is_empty() else 1)
