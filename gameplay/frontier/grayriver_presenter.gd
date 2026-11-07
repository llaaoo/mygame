class_name GrayriverPresenter
extends ExplorationPresenter
func show_arrival() -> void:
	var arrival: String = "旅程已恢复："+game.current_data.title+"。生命、补给与世界成果沿用存档。" if game.resuming_journey else "你来到灰河谷西南的河谷镇。先读镇中施法手册、领取口粮，再自行选路。"
	game.ui.show_panel("灰河谷 · 自由远征",arrival+"\n\n林地、矿道、湖岸、工区和湿地互相连通，旧监狱在东北。北桥和南侧浅滩始终开放，修复木桥可缩短往返。镇中艾妲记录你的发现与世界成果。\n\nF观察敌人或搜刮遗骸，物品取自真实穿戴和剩余行囊；取不下的留在原地，F打开战利品面板，E尽量取走全部。\n\nTab远征面板 · J委托 · I/O装备 · N补给 · G地图
7烤饼、8清水、9茶、0炖汤；仍需站定使用，受伤会打断。
普通基础动作默认按下即施放；可在操作设置切回按住预览、松开施放。
M本次材料 · K基础动作\n地图只记录亲自到过的地点。动作、材料和恩赐需要亲手组合，系统不会自动准备。F5存档，F9读档；独立旅程不覆盖监狱验证场。",[{"title":"开始河谷旅程","callback":game.ui.close_modal},{"title":"查看日志","callback":game.ui.show_journal}])
func _update_objective() -> void:
	if not game.current_data: return
	game.ui.heading.text = game.current_data.title + (" · 河谷镇" if game.is_at_base() else " · 野外" if game.region_id=="camp" else "")
	game.ui.objective.text = ("河谷镇 · 可以整备、烹饪、训练和交付" if game.is_at_base() else game.current_data.description)
	if game.is_at_base() and game.progress.claims.has("river.handbook") and game.progress.claims.has("river.pack") and not game.progress.claims.has("river.fire"):
		game.ui.objective.text = "北路通林地 · 东路通旧驿站 · G 行路图"
func journal_text() -> String:
	var text := "灰河谷旅程\nWASD移动，左键近战，右键格挡，R键火花，F调查；G地图、N补给、M本次素材、K基础动作、O手动装备。知识通过现场阅读学习；组合由当前地面、法阵、恩赐和素材产生。\n\n已发现地点\n"
	text += (game as GrayriverGame).discovered_places()
	text += "\n镇中委托\n"
	for quest in game.quests:
		text += quest.title+" · "+("已交付" if game.progress.claims.has("quest."+quest.id) else "可交付" if quest.is_complete(game.progress) else "进行中")+"\n"+quest.description+"\n"
	text += "\n已学制造配方\n"
	var supplies:=game.player.skill_manager.combinations.supplies
	for id in supplies.crafting_recipes:
		if supplies.knows_recipe(id):text+=supplies.title(id)+"\n"
	text += "\n永久成果\n"
	for pair in [["river.bridge_fixed","中部木桥"],["alchemy.pump_open","工区排污泵与湿地清水"],["river.outpost","驿站前哨"],["alchemy.repaired","镇中调和台"]]:
		text += ("✓ " if game.progress.claims.has(pair[0]) else "□ ")+pair[1]+"\n"
	text += "\n未取部件\n"
	for pair in [["alchemy.pump_open","alchemy.pump_taken","工区泵芯"],["alchemy.regulator_open","alchemy.regulator_taken","矿道调压器"]]:
		if game.progress.claims.has(pair[0]) and not game.progress.claims.has(pair[1]): text += pair[2]+"：已解封，靠近E取件\n"
	text += "\n未取战利品\n"
	for record: Dictionary in game.progress.loot_records.values():
		if record.equipment.is_empty() and record.materials.is_empty(): continue
		text += game.catalog.regions[record.region].title+" · "+record.title+"：装备%d种，物资%d种，靠近F搜刮。\n" % [record.equipment.size(),record.materials.size()]
	text += "\n发现记录\n"
	for note in game.progress.journal: text += "\n"+note.title+"\n"+note.text+"\n"
	return text

func _choose_world_event(entry: ExplorationWorldEventData, choice: ExplorationWorldChoiceData) -> void:
	if not game.progress_service.choose_world_event(entry,choice):return
	game.ui.close_modal()
	game.ui.notify("水路已调整："+choice.title+"。从下一次进入区域生效，已击败敌人和永久成果保留。")
