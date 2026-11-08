class_name QuickslotView
extends RefCounted
## Read-only presentation shared by the bar, binder and item buttons.
static func item_state(actor: Node2D,binding: Dictionary) -> Dictionary:
	var id:=str(binding.get("item_id",""))
	var definition:=ItemCatalog.default_catalog().definition(id)
	var result: Dictionary={"title":definition.display_name if definition else "空槽","count":0,"detail":"","ready":false,"icon":definition.get_icon_texture() if definition is EquipmentData else definition.icon if definition else null}
	if not definition or not "actor_context" in actor or not actor.actor_context: return result
	var context: ActorContext=actor.actor_context
	var uid:=str(binding.get("uid",""))
	if not uid.is_empty():
		var item:=context.items.item(uid)
		if not item or item.definition_id!=id or context.items.locate(uid) not in context.items.actor_containers(context.id)+[context.id+".gear"]:
			result.detail="绑定的实物已不在可访问库存；不会替换另一件。"; return result
		result.count=int(item.properties.get("doses",0)) if definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY else item.quantity
		result.ready=context.items.locate(uid)==context.id+".pocket" or definition is EquipmentData
		result.detail=context.items.state_text(uid)+(" · 已装备" if uid in context.items.equipped(context.id).values() else "")
	else:
		result.count=context.items.count(context.id,id,false,true)
		result.ready=result.count>0
	if not result.ready: result.detail+="\n口袋中没有可用物品；先整理或重新绑定。"
	if definition is EquipmentData: result.detail+="\n快捷装备同一件实物，仍遵循当前换装限制。"
	elif SurvivalCatalog.FOODS.has(id): result.detail+="\n站定使用，移动或受伤中断；完成才消费。"
	elif definition.use_profile:
		match definition.use_profile.kind:
			ItemUseDefinition.Kind.SPRAY: result.detail+="\n按住喷洒、松开停止；逐剂支付物品与法力，空瓶停止。"
			ItemUseDefinition.Kind.THROWABLE: result.detail+="\n按住瞄准、松开投掷；右键或Esc取消。"
			ItemUseDefinition.Kind.CONSUMABLE: result.detail+="\n站定饮用，完成才消费；药效按类别互斥，剩余时长保存。"
			ItemUseDefinition.Kind.BOOK: result.detail+="\n站定阅读，学会才消费；已学会不会浪费。"
			ItemUseDefinition.Kind.COATING:
				result.detail+="\n使用抹布涂附当前武器，完成才消费。"
				if definition.use_profile.enchantment: result.detail+="\n"+definition.use_profile.enchantment.describe()
	return result

static func technique_state(actor: Node2D,binding: Dictionary) -> Dictionary:
	var id:=str(binding.get("technique_id",""))
	var data:=MartialArts.definition(id)
	var context:=actor.get("actor_context") as ActorContext
	if not data or not context: return {"title":"未学习武技","ready":false,"detail":"","remaining":0.0,"cost":0.0}
	var reason:=context.martial.reason(id,context)
	var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	var coating:=context.items.coating(uid)
	var detail:=data.description+"\n"+reason
	if coating and coating.enchantment: detail+="\n"+context.items.state_text(uid)+"\nShift+武技：消耗整层附魔，释放距离%.0f / 扇面%.0f°。"%[data.release_reach,data.release_angle]
	else: detail+="\n涂附后可按Shift+武技释放元素；当前没有可用附魔。"
	return {"title":data.title,"ready":reason.is_empty(),"detail":detail,"element":coating.enchantment.title if coating and coating.enchantment else "","remaining":maxf(0,float(context.martial.ready_at.get(id,0))-context.items.clock_seconds),"cost":data.profile.stamina_cost}
