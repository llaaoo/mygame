class_name InventoryActions
extends RefCounted
## Domain boundary for actor-owned inventory operations and real ground pickup.
var actor: Player
var session: CampaignSession
var equip_request: Callable
var unequip_request: Callable
var management_reason: Callable
var removal_reason: Callable
var save_request: Callable
func _init(owner: Player,world_session: CampaignSession) -> void:
 actor=owner; session=world_session
func _available() -> bool:
 return is_instance_valid(actor) and not actor.health_component.is_dead and session.region.available()
func _finish(result: OperationResult) -> OperationResult:
 if result.accepted:
  session.refresh_ground()
  if save_request.is_valid(): save_request.call()
 return result
func drop(uid: String,quantity: int) -> OperationResult:
 if not _available(): return OperationResult.reject("当前无法丢弃。")
 var item:=session.inventory.item(uid)
 if not item: return OperationResult.reject("物品已经不在这里。")
 if actor.actor_context.actions.busy(): return OperationResult.reject("先结束当前动作。")
 if session.inventory.locate(uid)==actor.actor_context.id+".gear":
  var data:=session.inventory.definitions.get(item.definition_id) as EquipmentData
  var reason: String=str(removal_reason.call(data.slot_type)) if data else "无法卸下。"
  if not reason.is_empty(): return OperationResult.reject(reason)
 # Place beside the actor, without adding blocking collision or hidden loot grants.
 return _finish(session.inventory.drop_item(actor.actor_context.id,uid,quantity,session.region.id,actor.global_position))
func transfer(uid: String,destination: String,quantity: int) -> OperationResult:
 if not _available(): return OperationResult.reject("当前无法整理。")
 var store:=session.inventory
 var source:=store.locate(uid)
 var own:=store.actor_containers(actor.actor_context.id)
 if source not in own or destination not in own: return OperationResult.reject("先拾回背包，且只能整理随身物品。")
 var reason:=str(management_reason.call())
 if not reason.is_empty(): return OperationResult.reject(reason)
 return _finish(store.commit(store.preview(source,destination,uid,quantity)))
func split(uid: String,quantity: int) -> OperationResult:
 if not _available(): return OperationResult.reject("当前无法拆分。")
 var reason:=str(management_reason.call())
 if not reason.is_empty(): return OperationResult.reject(reason)
 return _finish(session.inventory.split_stack(actor.actor_context.id,uid,quantity))
func equip(uid: String) -> OperationResult:
 if not _available(): return OperationResult.reject("当前无法换装。")
 var item:=session.inventory.item(uid)
 if not item: return OperationResult.reject("物品已经不在这里。")
 var reason:=str(management_reason.call())
 if not reason.is_empty(): return OperationResult.reject(reason)
 return _finish(OperationResult.success(1) if equip_request.call(item.definition_id,uid) else OperationResult.reject("无法换装：检查穿戴条件与容器空间。"))
func unequip(slot: int) -> OperationResult:
 if not _available(): return OperationResult.reject("当前无法换装。")
 var reason:=str(removal_reason.call(slot))
 if not reason.is_empty(): return OperationResult.reject(reason)
 return _finish(OperationResult.success(1) if unequip_request.call(slot) else OperationResult.reject("背包没有足够空间，装备仍在身上。"))
func take(container: String,uid: String,quantity: int) -> OperationResult:
 if not _available() or not session.ground_available(actor,container) or session.inventory.locate(uid)!=container: return OperationResult.reject("物资已不在附近。")
 var item:=session.inventory.item(uid)
 if not item: return OperationResult.reject("物品已被取走。")
 var definition:=session.inventory.definitions.get(item.definition_id) as ItemData
 var destinations:=session.inventory.actor_containers(actor.actor_context.id)
 if definition is EquipmentData:
  destinations.clear()
  if session.inventory.is_attached(actor.actor_context.id+".pack"): destinations.append(actor.actor_context.id+".pack")
 var remaining:=quantity; var total:=0
 if quantity<1 or quantity>item.quantity: return OperationResult.reject("数量已变化。")
 for destination in destinations:
  var result:=session.inventory.commit(session.inventory.preview(container,destination,uid,remaining,true))
  if result.accepted:
   total+=result.moved; remaining-=result.moved
  if remaining==0: break
 return _finish(OperationResult.success(total) if total>0 else OperationResult.reject("口袋或背包没有空间，物品留在地上。"))
