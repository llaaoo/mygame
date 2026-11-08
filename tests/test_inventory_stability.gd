extends "res://tests/support/input_scene_probe.gd"
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
func mouse(held: bool,point: Vector2) -> void:
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=held
	root.push_input(event,true); Input.flush_buffered_events(); await frames(2)
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self)
	game=await fixture.boot(true)
	var actor:=game.player; var stock:=game.session.inventory
	stock.receive("player","river_sabre",1); stock.receive("player","charcoal",5)
	var uid:=stock.find_owned("player","river_sabre")
	var other:=game.active_enemies[0].actor_context.id
	GameRuntime.instance.set_process(true)
	# Repeated unrelated inventory notifications while the pointer is stationary.
	await key(KEY_I,true); await key(KEY_I,false)
	var screen:=game.inventory_screen
	var tile:=screen._grid.get_node("Item_"+uid.replace(".","_")) as Control
	(screen._grid.get_parent() as ScrollContainer).ensure_control_visible(tile); await frames(8)
	var identity:=tile.get_instance_id()
	var point:=tile.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
	root.push_input(motion,true); await frames(2)
	stock.receive(other,"cloth",1); await frames(12)
	check(is_instance_valid(tile) and tile.get_instance_id()==identity,"Unrelated stock update destroyed a hovered item tile")
	await mouse(true,point)
	stock.receive(other,"cloth",1); await frames(12)
	await mouse(false,point)
	check(screen.selected==uid and is_instance_valid(tile) and tile.get_instance_id()==identity,"Notification between pointer/press/release lost the intended UID")
	await capture("inventory-stable-selection")
	# Quantity field, focus and scroll survive updates that do not alter this item.
	var charcoal:=stock.find_owned("player","charcoal")
	var material:=screen._grid.get_node("Item_"+charcoal.replace(".","_")) as Control
	(screen._grid.get_parent() as ScrollContainer).ensure_control_visible(material); await frames(6)
	await point_click(material.get_global_rect().get_center())
	check(screen.selected==charcoal,"Actual material selection failed")
	var quantity:=screen._quantity
	var line:=quantity.get_line_edit()
	await point_click(line.get_global_rect().get_center())
	var focus:=root.gui_get_focus_owner()
	var scroll: int=(screen._grid.get_parent() as ScrollContainer).scroll_vertical
	stock.receive(other,"cloth",1); await frames(12)
	check(screen._quantity==quantity and root.gui_get_focus_owner()==focus and (screen._grid.get_parent() as ScrollContainer).scroll_vertical==scroll,"Unrelated change reset quantity editor, focus or scroll")
	# Switching actual quantities preserves the tile and revalidates its action.
	stock.receive("player","charcoal",1); await frames(12)
	check(screen.selected==charcoal and screen._quantity.max_value==stock.item(charcoal).quantity,"Real quantity mutation left stale selected actions")
	# Small viewport keeps actual items reachable by scrolling and selecting.
	root.size=Vector2i(960,600); await frames(10)
	tile=screen._grid.get_node("Item_"+uid.replace(".","_")) as Control
	(screen._grid.get_parent() as ScrollContainer).ensure_control_visible(tile); await frames(8)
	await point_click(tile.get_global_rect().get_center())
	check(screen.selected==uid and not paused,"Small-window scrolling selected a different item or paused the world")
	await capture("inventory-stable-small")
	check(game.session.drop_pack("player"),"Could not drop attached pack")
	await frames(12)
	check(not screen._portrait._visual.preview_pack,"Stable portrait retained a dropped backpack")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(not screen.visible and not actor.ui_blocked,"Escape left stale input ownership")
	await fixture.close()
	if failures.is_empty(): print("PASS inventory stability: real hover/press/release amid stock changes, UID/control identity, quantity focus/scroll, actual mutations and small window")
	quit(0 if failures.is_empty() else 1)
