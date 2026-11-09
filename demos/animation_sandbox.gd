class_name AnimationSandbox
extends GrayriverGame
## Actual Grayriver actors and rules; only the save repository and starting kit are isolated.
@export_enum("combat","casting") var demo_mode := "combat"
var demo_ready := false
var _demo_panel: PanelContainer
var _view: Label
var _duel_started := false
class MemoryRepository extends SaveRepository:
	var snapshots: Dictionary={}
	func read(path: String) -> SaveRepository.ReadResult:
		return SaveRepository.ReadResult.new(Status.VALID,snapshots[path].duplicate(true)) if snapshots.has(path) else SaveRepository.ReadResult.new(Status.MISSING)
	func write(path: String,data: Dictionary) -> bool:
		snapshots[path]=data.duplicate(true); return true
	func start_new(path: String,fresh: Dictionary,_current: Dictionary) -> String:
		snapshots[path]=fresh.duplicate(true); return "memory://previous-animation-demo"
func _ready() -> void:
	persistence_enabled=false
	SaveManager.instance.repository=MemoryRepository.new()
	super._ready()
	call_deferred("_prepare_demo")
func _prepare_demo() -> void:
	while not ready_for_play: await get_tree().process_frame
	ui.close_modal()
	player.cancel_active_input("开始独立动画演示")
	player.position=Vector2(-4000,800)
	player.get_node("Camera2D").zoom=Vector2(1.65,1.65)
	player.get_node("Camera2D").reset_smoothing()
	var store:=session.inventory
	for id in ["river_sabre","river_spear","river_staff","river_bow"]: store.receive("player",id,1)
	for pair in [["arrow",24],["fire_rag",3],["fire_stone",4],["venom_bottle",3]]: store.receive_into("player.pocket",pair[0],pair[1])
	store.equip("player",store.find_owned("player","river_sabre"))
	for id in MartialArts.IDS: player.actor_context.martial.learn(id)
	var manager:=player.skill_manager
	progress.actions.merge({"inscribe":true,"ignite":true,"pulse":true},true)
	progress.spell_rules["fire_sigil_fireball"]=true
	_apply_knowledge()
	manager.shortcuts.equip_skill("left",manager.pool.get_skill("inscribe"),{"payload":"ember","modifier":""})
	manager.shortcuts.equip_skill("quick_e",manager.pool.get_skill("ignite"))
	manager.shortcuts.equip_skill("right",manager.pool.get_skill("pulse"))
	manager.shortcuts.bind_item("slot_0","fire_rag"); manager.shortcuts.bind_item("slot_1","venom_bottle")
	_build_demo_controls()
	demo_ready=true
func _build_demo_controls() -> void:
	var layer:=CanvasLayer.new(); layer.layer=130; add_child(layer)
	_demo_panel=PanelContainer.new(); _demo_panel.name="AnimationDemoPanel"; _demo_panel.position=Vector2(235,8); _demo_panel.size=Vector2(680,150)
	_demo_panel.add_theme_stylebox_override("panel",GameUIStyle.panel_style(.96)); layer.add_child(_demo_panel)
	var box:=VBoxContainer.new(); _demo_panel.add_child(box)
	box.add_child(FoundationWidgets.label("02 武器与连招" if demo_mode=="combat" else "03 法阵、施法与取消",18))
	box.add_child(FoundationWidgets.label("独立内存沙盒 · 正常AI与真实资源 · F5/F9只读写本次演示内存",12,true))
	box.add_child(FoundationWidgets.label("短按/长按左键轻重击 → Ctrl+左键武技；1火抹布 → Ctrl+Shift+左键释放附魔。" if demo_mode=="combat" else "Q亲手铭刻火石阵 → 阵内E火花发火球；R震荡，2按住瞄准投掷；移动/闪避可取消未完成准备。",12,true))
	var weapons:=HBoxContainer.new(); box.add_child(weapons)
	for id in ["river_sabre","river_spear","river_staff","river_bow"]:
		weapons.add_child(FoundationWidgets.button({"river_sabre":"刀剑","river_spear":"长矛","river_staff":"战杖","river_bow":"弓"}[id],func():
			player.cancel_active_input("演示切换实物武器"); player.actor_context.actions.cancel("demo_weapon")
			session.inventory.equip("player",session.inventory.find_owned("player",id))))
	weapons.add_child(FoundationWidgets.button("开始对练（正常AI）",_start_duel))
	var routes:=HBoxContainer.new(); box.add_child(routes)
	routes.add_child(FoundationWidgets.button("素材浏览",func(): get_tree().change_scene_to_file("res://demos/animation_gallery.tscn")))
	routes.add_child(FoundationWidgets.button("重置本演示",func(): get_tree().reload_current_scene()))
	routes.add_child(FoundationWidgets.button("返回正式旅程",func(): get_tree().change_scene_to_file("res://grayriver.tscn")))
	var diagnostic:=CheckButton.new(); diagnostic.text="显示动画阶段"; routes.add_child(diagnostic)
	_view=FoundationWidgets.label("",12,true); _view.visible=false; box.add_child(_view); diagnostic.toggled.connect(func(value: bool): _view.visible=value)
func _start_duel() -> void:
	if _duel_started: return
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or enemy.health_component.is_dead or enemy.story_truce: continue
		enemy.position=player.position+Vector2(185,0); enemy._home_position=enemy.position
		_duel_started=true; return
func _process(delta: float) -> void:
	super._process(delta)
	if not demo_ready or not is_instance_valid(_view) or not _view.visible: return
	var visual:=player.get_node("EquipmentVisual") as ActorEquipmentVisual
	var view:=visual.animator.current
	_view.text="%s → %s · %s %.0f%% · %s · 第%d帧"%[str(view.get("state","")),str(view.get("resolved","")),str(view.get("phase","")),float(view.get("progress",0))*100,ActorAnimationProfile.DIRECTIONS[int(view.get("direction",0))],int(view.get("frame",0))+1]
