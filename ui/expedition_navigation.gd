class_name ExpeditionNavigation
extends HBoxContainer
## Shared presentation and menu input; injected routes open existing game views.
const PAGES := [
 {"id":"actions","title":"整备与制作","key":KEY_TAB,"caption":"Tab","icon":"anvil"},
 {"id":"inventory","title":"行囊","key":KEY_I,"caption":"I","icon":"backpack"},
 {"id":"loadout","title":"技法","key":KEY_K,"caption":"K","icon":"sparkles"},
 {"id":"quests","title":"委托与旅程","key":KEY_J,"caption":"J","icon":"book-open"},
 {"id":"progression","title":"角色成长","key":KEY_P,"caption":"P","icon":"sparkles"},
 {"id":"map","title":"行路图","key":KEY_G,"caption":"G","icon":"compass"},
]
var current_page := ""
var navigate: Callable
func _ready() -> void:
 name="ExpeditionNavigation"
 size_flags_horizontal=Control.SIZE_EXPAND_FILL
 add_theme_constant_override("separation",4)
 for page in PAGES:
  var button:=Button.new(); button.name="Route_"+page.id
  button.text=page.title; button.icon=GameUIStyle.icon(page.icon)
  button.expand_icon=true; button.add_theme_constant_override("icon_max_width",16)
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.tooltip_text=page.caption+" · "+page.title
  button.clip_text=true; button.alignment=HORIZONTAL_ALIGNMENT_LEFT
  button.add_theme_color_override("icon_normal_color",GameUIStyle.GOLD if page.id==current_page else GameUIStyle.TEXT_MUTED)
  GameUIStyle.apply_tab(button,page.id==current_page)
  button.pressed.connect(func(): if navigate.is_valid(): navigate.call(page.id))
  add_child(button)
func _unhandled_input(event: InputEvent) -> void:
 if not is_visible_in_tree() or not navigate.is_valid() or not event is InputEventKey or not event.pressed or event.echo: return
 var focus:=get_viewport().gui_get_focus_owner()
 if focus is LineEdit or focus is TextEdit: return
 for page in PAGES:
  if event.keycode!=page.key or current_page==page.id: continue
  navigate.call(page.id); get_viewport().set_input_as_handled(); return
 if event.keycode in [KEY_O,KEY_N] and current_page!="inventory":
  navigate.call("equipment" if event.keycode==KEY_O else "supplies")
  get_viewport().set_input_as_handled()
