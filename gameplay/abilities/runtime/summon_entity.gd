class_name SummonEntity
extends CharacterBody2D
## 召唤物实体 — 指令型 AI，跟随玩家并按指令攻击
##
## 行为优先级:
##   1. 复仇: 伤害了玩家的敌人 → 追杀
##   2. 集火: 玩家正在攻击的目标 → 追杀
##   3. 跟随: 在玩家周围 follow_distance 内游走
##
## 生命周期:
##   - lifetime 倒计时 → 自动消失
##   - HP 归零 → 死亡消失
##   - 玩家死亡 → SummonManager.clear_all() → 消失

## ── 数据（由 setup() 注入） ──
var summon_data: SummonData = null
var summon_name: String = "召唤物"
var _max_hp: int = 30
var _damage: int = 8
var _move_speed: float = 120.0
var _attack_range: float = 40.0
var _attack_cooldown: float = 1.5
var _lifetime: float = 30.0
var _follow_distance: float = 80.0
var _leash_distance: float = 500.0
var _color: Color = Color.WHITE
var _scale: float = 0.3

## ── 引用 ──
var _player: Player = null
var _manager: SummonManager = null
var _health_component: HealthComponent = null
var _sprite: Sprite2D = null
var _attack_timer: float = 0.0
var _current_target: Node2D = null

## ── 预加载形状资源 ──
const BODY_SHAPE := preload("res://entities/enemy/enemy_body_shape.tres")


func _ready() -> void:
	# 在 setup() 调用之前，节点已经就位但数据未注入
	pass


## 由 SkillExecutor 调用，注入数据和引用
func setup(p_data: SummonData, p_player: Player, p_manager: SummonManager) -> void:
	summon_data = p_data
	_player = p_player
	_manager = p_manager

	# 从数据读取属性
	summon_name = p_data.summon_name
	_max_hp = p_data.max_hp
	_damage = p_data.damage
	_move_speed = p_data.speed
	_attack_range = p_data.attack_range
	_attack_cooldown = p_data.attack_cooldown
	_lifetime = p_data.lifetime
	_follow_distance = p_data.follow_distance
	_leash_distance = p_data.leash_distance
	_color = p_data.color
	_scale = p_data.scale

	# 碰撞层：与 Enemy 一致（ACTOR 层，碰撞 WORLD_STATIC + ACTOR）
	collision_layer = 2   # ACTOR
	collision_mask = 3    # WORLD_STATIC | ACTOR

	# 碰撞形状
	if $CollisionShape2D.shape == null:
		$CollisionShape2D.shape = BODY_SHAPE

	# 视觉
	_sprite = $Sprite2D
	if p_data.texture:
		_sprite.texture = p_data.texture
	else:
		# Fallback: 使用 icon.svg 作为占位
		_sprite.texture = preload("res://icon.svg")
	_sprite.modulate = _color
	_sprite.scale = Vector2(_scale, _scale)
	_sprite.z_index = 9

	# 生命值
	_health_component = $HealthComponent
	_health_component.max_hp = _max_hp
	_health_component.regen_rate = 0.0
	_health_component.setup($CollisionShape2D)
	_health_component.hp = _max_hp  # setup() 会用 max_hp 覆盖，再显式设置
	_health_component.died.connect(_on_died)

	# 注册到管理器
	_manager.register(self)

	# 加入 summon 组（供全局查询）
	add_to_group("summon")

	print("👻 [SummonEntity] %s 被召唤 (HP=%d, 伤害=%d, 寿命=%.0fs)" % [summon_name, _max_hp, _damage, _lifetime])


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player) or _player.health_component.is_dead:
		return

	# 生命周期倒计时
	if _lifetime > 0:
		_lifetime -= delta
		if _lifetime <= 0:
			_on_expired()
			return

	# 攻击冷却
	_attack_timer += delta

	# 确定当前目标
	_current_target = _manager.get_priority_target()

	if is_instance_valid(_current_target):
		_chase_and_attack_target(delta)
	else:
		_follow_player(delta)


## ── 行为: 追杀目标 ──

func _chase_and_attack_target(delta: float) -> void:
	var dist := global_position.distance_to(_current_target.global_position)

	# 脱战检查：目标太远 → 放弃
	if dist > _leash_distance:
		_current_target = null
		return

	# 目标死亡检查（由管理器 _clear_dead_target 处理，这里是防御性检查）
	if _current_target.has_method("is_dead") and _current_target.is_dead():
		_current_target = null
		return

	# 在攻击范围内 → 攻击
	if dist <= _attack_range:
		velocity = Vector2.ZERO
		if _attack_timer >= _attack_cooldown:
			_do_attack()
			_attack_timer = 0.0
	else:
		# 移向目标
		var dir := (_current_target.global_position - global_position).normalized()
		velocity = dir * _move_speed

	move_and_slide()


## ── 行为: 跟随玩家 ──

func _follow_player(_delta: float) -> void:
	var dist := global_position.distance_to(_player.global_position)

	if dist > _follow_distance:
		var dir := (_player.global_position - global_position).normalized()
		velocity = dir * _move_speed
	else:
		# 在跟随范围内 → 微调位置（轻推，避免完全静止看起来太僵硬）
		velocity = velocity.move_toward(Vector2.ZERO, _move_speed * 2.0)

	move_and_slide()


## ── 攻击 ──

func _do_attack() -> void:
	if not is_instance_valid(_current_target):
		return

	# 通过 CombatExecutor 统一伤害入口
	CombatExecutor.report_hit(self, _current_target, _damage, _current_target.global_position, null, ["summon", "melee"])


## ── 受伤 / 死亡 ──

func take_damage(amount: int) -> void:
	if not _health_component:
		return
	_flash_damage()
	_health_component.take_damage(amount)


func _flash_damage() -> void:
	if not _sprite:
		return
	_sprite.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_callback(func(): _sprite.modulate = _color).set_delay(0.1)


func _on_died() -> void:
	print("💀 [SummonEntity] %s 被击败" % summon_name)
	_manager.unregister(self)
	queue_free()


func _on_expired() -> void:
	print("⏰ [SummonEntity] %s 持续时间结束" % summon_name)
	_manager.unregister(self)
	queue_free()


func is_dead() -> bool:
	return not is_inside_tree()
