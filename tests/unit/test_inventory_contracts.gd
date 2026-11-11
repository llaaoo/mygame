extends GutTest
## Fast domain checks: no world boot, physics waits, AI overrides or formal saves.
var store: InventoryService
var blade: EquipmentData

func test_occupancy_counts_real_stacks_without_cloning_or_mutation() -> void:
	store.receive("a",blade.id,2);store.receive("a","test_coin",8)
	var before:=store.snapshot()
	assert_eq(store.occupied_slots("a.pack"),3)
	assert_eq(store.occupied_slots("missing"),0)
	assert_eq(store.snapshot(),before)
	assert_true(store.pay("a",{"test_coin":8}))
	assert_eq(store.occupied_slots("a.pack"),2)

func before_each() -> void:
	store=InventoryService.new()
	blade=EquipmentData.new();blade.id="test_blade";blade.slot_type=EquipmentData.SlotType.RIGHT_HAND
	store.register_definition(blade)
	var coin:=ItemData.new();coin.id="test_coin";coin.stackable=true;coin.max_stack=100
	store.register_definition(coin)
	store.ensure_actor("a");store.ensure_actor("b")

func test_stale_transfer_has_no_partial_write_or_notification() -> void:
	store.receive("a",blade.id,1)
	var uid:=store.find_owned("a",blade.id)
	var plan:=store.preview("a.pack","b.pack",uid,1)
	store.receive("b","test_coin",1)
	var before:=store.snapshot()
	watch_signals(store)
	assert_false(store.commit(plan).accepted)
	assert_eq(store.snapshot(),before,"Rejected plans preserve UID, ownership, revisions and quantities")
	assert_signal_not_emitted(store,"changed")

func test_equipped_item_transfer_preserves_identity_and_clears_slot() -> void:
	store.receive("a",blade.id,1)
	var uid:=store.find_owned("a",blade.id)
	assert_true(store.equip("a",uid).accepted)
	assert_true(store.commit(store.preview("a.gear","b.pack",uid,1)).accepted)
	assert_eq(store.locate(uid),"b.pack")
	assert_true(store.equipped("a").is_empty())
	assert_eq(store.item(uid).quantity,1)
	assert_eq(store.count("a",blade.id,true)+store.count("b",blade.id,true),1)

func test_failed_exchange_preserves_both_inventories() -> void:
	store.receive("a","test_coin",2);store.receive("b",blade.id,1)
	var before:=store.snapshot()
	watch_signals(store)
	assert_false(store.exchange("a","b",{"test_coin":3},{"test_blade":1}).accepted)
	assert_eq(store.snapshot(),before)
	assert_signal_not_emitted(store,"changed")

func test_full_containers_can_swap_real_items_atomically() -> void:
	var compact:=InventoryService.new();compact.register_definition(blade)
	for actor in ["a","b"]:
		compact.ensure_container(actor+".pack",actor,"pack",1);compact.ensure_actor(actor)
		compact.receive(actor,blade.id,1)
	var first:=compact.find_owned("a",blade.id)
	var second:=compact.find_owned("b",blade.id)
	assert_true(compact.exchange("a","b",{"test_blade":1},{"test_blade":1},second).accepted)
	assert_eq(compact.locate(first),"b.pack")
	assert_eq(compact.locate(second),"a.pack")
	assert_eq(compact.entries("a.pack").size(),1)
	assert_eq(compact.entries("b.pack").size(),1)

func test_detached_pack_invalidates_plan_and_does_not_refill() -> void:
	store.receive("a",blade.id,1)
	var uid:=store.find_owned("a",blade.id)
	var plan:=store.preview("a.pack","b.pack",uid,1)
	assert_true(store.drop_pack("a","camp",Vector2(10,20)))
	assert_false(store.commit(plan).accepted)
	var restored:=InventoryService.new();restored.register_definition(blade);restored.restore(store.snapshot())
	assert_false(restored.is_attached("a.pack"))
	assert_eq(restored.dropped_pack_position("a.pack"),Vector2(10,20))
	assert_true(restored.recover_pack("a","a.pack"))
	assert_eq(restored.locate(uid),"a.pack")
	assert_eq(restored.count("a",blade.id),1)

func test_query_copies_cannot_mutate_authoritative_inventory() -> void:
	store.receive("a",blade.id,1)
	var uid:=store.find_owned("a",blade.id)
	var before:=store.snapshot()
	store.item(uid).properties["enchantment"]={"element":"fire","remaining":99}
	var rows:=store.entries("a.pack");rows[0].quantity=99
	assert_eq(store.snapshot(),before)
	assert_true(blade.stat_modifiers.is_empty(),"Runtime edits never mutate shared definitions")
