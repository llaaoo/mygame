extends "res://tests/support/input_scene_probe.gd"
## Controlled town stock/position fixture; real input with normal AI and simulation.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var trade_facts: Array[Dictionary]=[]
var lesson_facts: Array[Dictionary]=[]
func market_identity(action: String,uid := "") -> Dictionary:
	var identity: Dictionary={"ui_action":action,"actor_id":game.town_services.market.actor_id}
	if not uid.is_empty(): identity["item_uid"]=uid
	return identity
func buy_tab_identity() -> Dictionary:
	var identity:=market_identity("market_tab")
	identity["trade_mode"]="buy"
	return identity
func trade_checkpoint(uid: String,buying: bool) -> Dictionary:
	var store:=game.session.inventory
	var buyer: String="player" if buying else game.town_services.market.actor_id
	var seller: String=game.town_services.market.actor_id if buying else "player"
	var definition: String=store.item(uid).definition_id
	# Read the domain price independently of the caption used by the UI.
	var price:=game.town_services.total_price(uid,buying,1)
	check(price>0 and game.town_services.preview_trade(uid,not buying,1).accepted,"Trade checkpoint was not affordable/available")
	return {"uid":uid,"buyer":buyer,"seller":seller,"definition":definition,"price":price,"buyer_coin":store.count(buyer,"coin"),"seller_coin":store.count(seller,"coin"),"buyer_items":store.count(buyer,definition),"seller_items":store.count(seller,definition),"facts":trade_facts.size()}
func check_trade(before: Dictionary) -> void:
	var store:=game.session.inventory
	check(store.count(before.buyer,"coin")==before.buyer_coin-before.price and store.count(before.seller,"coin")==before.seller_coin+before.price,"Mouse trade did not transfer the exact domain price between both owners")
	check(store.count(before.buyer,before.definition)==before.buyer_items+1 and store.count(before.seller,before.definition)==before.seller_items-1,"Mouse trade did not transfer exactly one item between both inventories")
	check(trade_facts.size()==before.facts+1,"Mouse trade must commit exactly once")
	if trade_facts.size()!=before.facts+1: return
	var fact: Dictionary=trade_facts.back()
	check(fact.source==before.buyer and fact.data.partner==before.seller and fact.data.uid==before.uid and fact.data.quantity==1 and fact.data.price==before.price,"Trade fact did not identify the selected UID, parties, quantity and price")
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self)
	game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player
	var store:=game.session.inventory
	game.session.facts.committed.connect(func(fact: Dictionary):
		if fact.kind=="trade_committed": trade_facts.append(fact.duplicate(true))
		if fact.kind=="technique_learned": lesson_facts.append(fact.duplicate(true)))
	store.receive("player","river_sabre",1); store.receive("player","metal_scrap",8); store.receive("player","coin",60)
	var uid:=store.find_owned("player","river_sabre")
	actor.position=TownServices.POINT+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
	await key(KEY_F,true); await key(KEY_F,false)
	check(is_instance_valid(game.ui.modal) and not paused,"F failed to open the live town workshop")
	await click_identity(market_identity("market_item",uid))
	var upgrade_cost:=store.upgrade_cost("player",uid).duplicate()
	var upgrade_stock: Dictionary={}
	var merchant_stock: Dictionary={}
	for id in upgrade_cost:
		upgrade_stock[id]=store.count("player",id)
		merchant_stock[id]=store.count(TownServices.MERCHANT,id)
	var upgrade_button:=button_by_identity(market_identity("upgrade",uid))
	if upgrade_button: upgrade_button.text="整修当前实物（动态文案定位回归）"
	await click_identity(market_identity("upgrade",uid))
	check(store.item(uid).properties.get("upgrade_level",0)==1,"Mouse upgrade did not modify the actual instance")
	for id in upgrade_cost:
		check(store.count("player",id)==upgrade_stock[id]-upgrade_cost[id],"Upgrade did not pay the exact "+str(id)+" cost")
		check(store.count(TownServices.MERCHANT,id)==merchant_stock[id],"Upgrade unexpectedly changed the merchant's "+str(id)+" stock")
	await click_identity(market_identity("market_item",uid))
	await capture("depth-workshop")
	var sale:=trade_checkpoint(uid,false)
	await click_identity(market_identity("sell_item",uid))
	check_trade(sale)
	check(store.locate(uid)==TownServices.MERCHANT+".pack","Mouse sale lost the selected UID")
	await click_identity(buy_tab_identity())
	var repurchase_row:=button_by_identity(market_identity("market_item",uid))
	if repurchase_row: repurchase_row.text="所选回购物品（名称与价格文案可变）"
	await click_identity(market_identity("market_item",uid))
	var repurchase:=trade_checkpoint(uid,true)
	await click_identity(market_identity("buy_item",uid))
	check_trade(repurchase)
	check(store.locate(uid)=="player.pack" and store.item(uid).properties.upgrade_level==1,"Mouse buy changed upgrade identity")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	# Teaching and combo selection are ordinary UI/input operations.
	var npc:=game.session.actor_for_id("river.enemy.service.trainer") as ServiceNPC
	actor.position=npc.position+Vector2(0,40); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
	await key(KEY_F,true); await key(KEY_F,false)
	var trainer_id: String=game.town_services.training.actor_id
	await click_identity({"ui_action":"npc_topic","actor_id":trainer_id,"topic":"training"})
	var offer:=game.town_services.training.offer("blade_breaker")
	var course_identity: Dictionary={"ui_action":"learn_technique","actor_id":trainer_id,"course_id":offer.id}
	var student_before: Dictionary={}
	var teacher_before: Dictionary={}
	for id in offer.costs:
		student_before[id]=store.count("player",id)
		teacher_before[id]=store.count(trainer_id,id)
	var course_button:=button_by_identity(course_identity)
	if course_button: course_button.text="学习所选课程（价格文案可变）"
	await click_identity(course_identity)
	check(actor.actor_context.martial.learned.has("blade_breaker"),"Trainer mouse service did not unlock martial knowledge")
	for id in offer.costs:
		check(store.count("player",id)==student_before[id]-offer.costs[id] and store.count(trainer_id,id)==teacher_before[id]+offer.costs[id],"Course did not transfer the exact "+str(id)+" payment to its teacher")
	check(lesson_facts.size()==1,"Course mouse input must learn exactly once")
	if lesson_facts.size()==1:
		var lesson: Dictionary=lesson_facts[0]
		check(lesson.source=="player" and lesson.data.id==offer.technique.id and lesson.data.course==offer.id and lesson.data.source==trainer_id,"Learning fact lost the actual course or teacher identity")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	store.equip("player",uid)
	await key(KEY_K,true); await key(KEY_K,false)
	await click_identity({"ui_action":"loadout_tab","loadout_page":"techniques"})
	await click_identity({"ui_action":"select_technique","technique_id":"blade_breaker"})
	check(actor.actor_context.martial.route_slots("blade:light/heavy").size()==2,"Training did not equip the bounded combo loadout")
	await capture("depth-martial-binder")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing()
	await frames(5); await aim_world(actor.position+Vector2(150,0))
	var mp:=actor.mana_component.mp
	var attacks:=actor.actor_context.actions._attack_sequence
	await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false)
	await create_timer(1.0).timeout
	await pointer_button(MOUSE_BUTTON_LEFT,true); await create_timer(.37).timeout; await pointer_button(MOUSE_BUTTON_LEFT,false)
	for i in range(130):
		if actor.actor_context.actions.mode=="idle": break
		await frames(1)
	await key(KEY_CTRL,true); await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false); await key(KEY_CTRL,false)
	check(actor.actor_context.actions._attack_sequence==attacks+3 and actor.mana_component.mp==mp,"Combo did not execute exactly one earned physical technique without MP")
	await create_timer(1.5).timeout
	# Rest is selected by mouse and advances the persistent world clock on completion.
	var rest: ExplorationInteractable
	for node in game.region_root.get_children():
		if node is ExplorationInteractable and node.get_meta("survival_rest",false): rest=node
	store.receive("player","ration",4); store.receive("player","clean_water",4)
	actor.position=rest.position+Vector2(0,30); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
	await key(KEY_F,true); await key(KEY_F,false)
	var work:=actor.field_work
	check(work.panel.visible and not paused,"Rest did not expose live hour selection")
	await capture("depth-rest-hours")
	await point_click(work.panel.start_button.get_global_rect().get_center())
	check(work.is_busy(),"Mouse rest did not start interruptible preparation")
	var before:=store.clock_seconds
	await create_timer(3.0).timeout
	check(store.clock_seconds-before>60 and store.clock_seconds-before<65 and not work.is_busy(),"One-hour rest did not advance the shared clock once")
	await capture("depth-rest-complete")
	# Potion is a real item shortcut, separate from the learned combo configuration.
	store.receive("player","guard_tonic",1)
	actor.skill_manager.shortcuts.bind_item("slot_0","guard_tonic")
	await key(KEY_1,true); await key(KEY_1,false); await create_timer(1.3).timeout
	check(actor.get_node("BuffManager").has_buff("guard_tonic") and store.count("player","guard_tonic")==0,"1 did not consume the real potion through normal timed input")
	check(actor.actor_context.martial.route_equipped("blade_breaker","power"),"Potion shortcut replaced combo equipment")
	await capture("depth-provisions")
	# A bow bought through the service uses LMB, actual arrows and no spell mana.
	actor.position=TownServices.POINT+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
	await key(KEY_F,true); await key(KEY_F,false)
	var bow_uid:=store.find_owned(TownServices.MERCHANT,"river_bow")
	check(not bow_uid.is_empty(),"Controlled merchant fixture has no actual bow UID")
	await click_identity(buy_tab_identity())
	await click_identity(market_identity("market_item",bow_uid))
	var bow_purchase:=trade_checkpoint(bow_uid,true)
	await click_identity(market_identity("buy_item",bow_uid))
	check_trade(bow_purchase)
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(store.locate(bow_uid)=="player.pack" and store.equip("player",bow_uid).accepted,"Purchased bow could not equip its actual instance")
	store.receive_into("player.pocket","arrow",2)
	await frames(8)
	var ammunition:=store.count("player","arrow")
	mp=actor.mana_component.mp
	var sequence:=actor.actor_context.actions._attack_sequence
	var point:=Vector2(710,320)
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
	Input.parse_input_event(motion); await frames(2)
	var press:=InputEventMouseButton.new(); press.position=point; press.global_position=point; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true
	Input.parse_input_event(press); await frames(2)
	press=press.duplicate(); press.pressed=false; Input.parse_input_event(press)
	await create_timer(.7).timeout
	check(actor.actor_context.actions._attack_sequence==sequence+1 and store.count("player","arrow")==ammunition-1 and actor.mana_component.mp==mp,"Real LMB did not fire exactly one actual arrow without MP")
	await capture("depth-bow")
	await fixture.close()
	if failures.is_empty(): print("PASS depth input: identity-located real mouse UID upgrade/sell/buy and courses despite changed captions, exact bilateral trade/course payments, K martial loadout, independent item slots, hourly rest, potion and LMB bow; normal AI/simulation, controlled stock and positions")
	quit(0 if failures.is_empty() else 1)
