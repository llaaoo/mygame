extends RefCounted
## Isolated authored-content extension. Never mutate an existing definition in place.
const MERCHANT := "fixture.merchant"
const TRAINER := "fixture.trainer"
var original: NpcCatalog
func install(game: GrayriverGame) -> void:
	original=NpcCatalog.default_catalog()
	var catalog:=NpcCatalog.new(); catalog.profiles.assign(original.profiles)
	var merchant:=NpcProfile.new(); merchant.actor_id=MERCHANT; merchant.role="验证独立实物商店"
	merchant.character=ActorCharacterData.new(); merchant.character.id=MERCHANT; merchant.character.title="行商岚"
	merchant.work_position=Vector2(-4200,900); merchant.rest_position=Vector2(-4200,1250)
	merchant.schedule=original.profiles[0].daily_schedule(); merchant.greeting="这批货归我自己持有。"
	merchant.market=MarketDefinition.new(); merchant.market.actor_id=MERCHANT; merchant.market.position=merchant.work_position
	merchant.market.initial_stock={"coin":30,"arrow":6,"herb":2}
	var topic:=NpcTopic.new(); topic.id="trade"; topic.title="查看行商货物"; topic.response="只交易我的实物。"; topic.kind=NpcTopic.Kind.SERVICE; topic.service="trade"; merchant.topics=[topic]
	var trainer:=NpcProfile.new(); trainer.actor_id=TRAINER; trainer.role="验证独立课程"
	trainer.character=ActorCharacterData.new(); trainer.character.id=TRAINER; trainer.character.title="旅人教习"
	trainer.training=TrainingCatalog.new(); trainer.training.actor_id=TRAINER
	trainer.training.work_position=Vector2(-3950,900); trainer.training.rest_position=Vector2(-3950,1250)
	trainer.training.schedule=original.profiles[0].daily_schedule(); trainer.training.offers=[TrainingCatalog.default_catalog().offer("blade_breaker")]
	trainer.greeting="我只教一门破势斩，学费归我的行囊。"
	topic=NpcTopic.new(); topic.id="training"; topic.title="学习旅人课程"; topic.response="查看我的课程。"; topic.kind=NpcTopic.Kind.SERVICE; topic.service="training"; trainer.topics=[topic]
	catalog.profiles.append(merchant); catalog.profiles.append(trainer)
	NpcCatalog._default=catalog
	game.session.conversations.catalog=catalog; game.residents.mount()
func release() -> void:
	NpcCatalog._default=original
