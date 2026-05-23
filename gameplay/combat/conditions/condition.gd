class_name Condition
extends Resource
## 条件 — 纯判定节点，回答"是否满足"
## 
## 每个子类覆写 evaluate(ctx) 返回 bool
## 条件之间通过 Array 顺序执行（AND 逻辑），遇 false 即停
## 
## 这是"盲目触发 → 智能判断"的关键跃迁

## ── 反转（NOT 逻辑） ──
@export var invert: bool = false                  ## true = 条件取反


## 核心判定（子类覆写）
func evaluate(ctx: Dictionary) -> bool:
	return true


## 带反转的最终判定
func check(ctx: Dictionary) -> bool:
	var result := evaluate(ctx)
	return not result if invert else result
