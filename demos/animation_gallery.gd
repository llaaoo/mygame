class_name AnimationGallery
extends Control
## Pure asset preview, deliberately separate from the real-inventory combat demos.
var rigs: Array[ActorAnimationController]=[]
var captions: Array[Label]=[]
var state := "idle"
var phase := "whole"
var direction := 0
var progress := 0.0
var autoplay := true
var speed := 1.0
var scrub: HSlider
var diagnostic: Label
func _ready() -> void:
	GameUIStyle.install_theme(get_window())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background:=ColorRect.new(); background.color=Color("111b21"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin:=MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,24)
	add_child(margin)
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; margin.add_child(scroll)
	var page:=VBoxContainer.new(); page.size_flags_horizontal=Control.SIZE_EXPAND_FILL; page.add_theme_constant_override("separation",10); scroll.add_child(page)
	page.add_child(FoundationWidgets.label("动画试验室",28))
	page.add_child(FoundationWidgets.label("01 素材与方向 · 原始攻击帧含绘制武器，仅供参考；正式角色使用无武器身体帧＋实际装备。",14,true))
	var previews:=HBoxContainer.new(); previews.add_theme_constant_override("separation",16); page.add_child(previews)
	for resource in ["puny_body","puny_reference","puny_mage"]:
		var profile:=load("res://content/animations/"+resource+".tres") as ActorAnimationProfile
		var card:=PanelContainer.new(); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; card.add_theme_stylebox_override("panel",GameUIStyle.panel_style()); previews.add_child(card)
		var box:=VBoxContainer.new(); card.add_child(box); box.add_child(FoundationWidgets.label(profile.title,13,true))
		var stage:=Control.new(); stage.custom_minimum_size=Vector2(210,155); stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL; stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; box.add_child(stage)
		var rig: ActorAnimationController=load("res://gameplay/presentation/actors/actor_animation_rig.tscn").instantiate(); rig.profile=profile; rig.scale=Vector2(2.2,2.2); stage.add_child(rig)
		stage.resized.connect(func(): if is_instance_valid(rig): rig.position=Vector2(stage.size.x*.5,100))
		rig.position=Vector2(105,100); rigs.append(rig)
		var caption:=FoundationWidgets.label("",12,true); box.add_child(caption); captions.append(caption)
	var controls:=HBoxContainer.new(); page.add_child(controls)
	var play:=CheckButton.new(); play.text="自动播放"; play.button_pressed=true; play.toggled.connect(func(value: bool): autoplay=value); controls.add_child(play)
	var speed_button:=FoundationWidgets.button("速度 1×",func(): pass)
	var speeds: Array[float]=[.25,.5,1.0,1.5]
	speed_button.pressed.connect(func(): speed=speeds[(speeds.find(speed)+1)%speeds.size()]; speed_button.text="速度 %g×"%speed)
	controls.add_child(speed_button)
	var phases:=ButtonGroup.new()
	for pair in [["全段","whole"],["前摇","windup"],["挥出","active"],["收招","recovery"]]:
		var button:=FoundationWidgets.button(pair[0],func(): phase=pair[1]); button.toggle_mode=true; button.button_group=phases; button.button_pressed=pair[1]=="whole"; controls.add_child(button)
	var grid:=GridContainer.new(); grid.name="AnimationActions"; grid.columns=6; grid.add_theme_constant_override("h_separation",6); grid.add_theme_constant_override("v_separation",4); page.add_child(grid)
	var keys: Array[String]=["idle","walk","slash","slash_reverse","slash_heavy","thrust","sweep","shot","shot_heavy","cast","throw","use","guard","charge","dodge","hurt","death"]
	var titles: Array[String]=["待机","移动","轻斩","返刃","重斩","突刺","横扫","射击","重射","施法","投掷","物品准备","格挡","蓄力","闪避","受击","死亡"]
	keys.append_array(["work_gather","work_craft","work_rest"]); titles.append_array(["采集作业","制作作业","休息姿态"])
	var group:=ButtonGroup.new()
	for index in keys.size():
		var button:=FoundationWidgets.button(titles[index],func(): state=keys[index]; progress=0); button.toggle_mode=true; button.button_group=group; button.button_pressed=index==0; grid.add_child(button)
	var compass:=HBoxContainer.new(); page.add_child(compass)
	for index in range(8):
		var button:=FoundationWidgets.button(["南","西南","西","西北","北","东北","东","东南"][index],func(): direction=index)
		compass.add_child(button)
	scrub=HSlider.new(); scrub.name="AnimationScrub"; scrub.min_value=0; scrub.max_value=1; scrub.step=.001
	scrub.drag_started.connect(func(): play.button_pressed=false)
	scrub.value_changed.connect(func(value: float): progress=value)
	page.add_child(scrub)
	diagnostic=FoundationWidgets.label("",12,true); page.add_child(diagnostic)
	var routes:=HBoxContainer.new(); page.add_child(routes)
	routes.add_child(FoundationWidgets.button("04 整体游戏表现",func(): get_tree().change_scene_to_file("res://demos/presentation_lab.tscn")))
	routes.add_child(FoundationWidgets.button("02 武器与连招实战",func(): get_tree().change_scene_to_file("res://demos/animation_combat.tscn")))
	routes.add_child(FoundationWidgets.button("03 施法与取消实战",func(): get_tree().change_scene_to_file("res://demos/animation_casting.tscn")))
	routes.add_child(FoundationWidgets.button("返回灰河谷",func(): get_tree().change_scene_to_file("res://grayriver.tscn")))
	page.add_child(FoundationWidgets.label("素材：Puny Characters · Shade · CC0，可商业使用。三组均来自原始PNG；灰河谷实战只使用已登记的无武器身体配置。此页调速与拖动仅影响预览。",12,true))
func _process(delta: float) -> void:
	if not is_instance_valid(scrub): return
	if autoplay: progress=fposmod(progress+delta*speed*.65,1); scrub.set_value_no_signal(progress)
	var facing:=Vector2.DOWN.rotated(direction*PI/4)
	for index in rigs.size():
		rigs[index].preview={"state":state,"phase":phase,"progress":progress,"direction":facing,"token":"gallery"}
		var view:=rigs[index].current
		captions[index].text="%s → %s · 第%d帧"%[state,str(view.get("resolved","—")),int(view.get("frame",0))+1]
	diagnostic.text="方向 %s · %s %.0f%% · 可暂停并拖动时间轴，查看起手／挥出／收招的相位映射。"%[ActorAnimationProfile.DIRECTIONS[direction].to_upper(),phase,progress*100]
