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
			ItemUseDefinition.Kind.COATING: result.detail+="\n使用抹布涂附当前武器，完成才消费。"
	return result
