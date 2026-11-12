class_name ExpeditionNavigation
extends HBoxContainer
## Shared presentation and menu input; injected routes open existing game views.
const PAGES := [
 {"id":"actions","title":"整备","key":KEY_TAB,"caption":"Tab","icon":"anvil"},
 {"id":"inventory","title":"行囊","key":KEY_I,"caption":"I","icon":"backpack"},
 {"id":"loadout","title":"技艺","key":KEY_K,"caption":"K","icon":"sparkles"},
 {"id":"quests","title":"手札","key":KEY_J,"caption":"J","icon":"book-open"},
 {"id":"progression","title":"角色","key":KEY_P,"caption":"P","icon":"sparkles"},
 {"id":"map","title":"行路图","key":KEY_M,"caption":"M","icon":"compass"},
]
var current_page := ""
var navigate: Callable
var _page_buttons: Dictionary={}
var _binding_revision := -1
func _ready() -> void:
 name="ExpeditionNavigation"
 size_flags_horizontal=Control.SIZE_EXPAND_FILL
 add_theme_constant_override("separation",4)
 for page in PAGES:
  var button:=Button.new(); button.name="Route_"+page.id
  button.text=page.title
  button.set_meta("ui_action","menu_route"); button.set_meta("page",page.id)
  button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
  _page_buttons[page.id]=button
  button.clip_text=false; button.alignment=HORIZONTAL_ALIGNMENT_CENTER
  button.add_theme_color_override("icon_normal_color",GameUIStyle.GOLD if page.id==current_page else GameUIStyle.TEXT_MUTED)
  GameUIStyle.apply_tab(button,page.id==current_page)
  button.pressed.connect(func(): if navigate.is_valid(): navigate.call(page.id))
  add_child(button)
 _refresh_binding_hints()
func _process(_delta: float) -> void:
 if _binding_revision!=InputBindings.revision: _refresh_binding_hints()
func _refresh_binding_hints() -> void:
 _binding_revision=InputBindings.revision
 for page in PAGES:
  _page_buttons[page.id].tooltip_text=InputBindings.menu_label(page.key)+" · "+page.title
  _page_buttons[page.id].text=page.title+" "+InputBindings.menu_label(page.key)
func _unhandled_input(event: InputEvent) -> void:
 if not is_visible_in_tree() or not navigate.is_valid() or not event is InputEventKey or not event.pressed or event.echo: return
 var focus:=get_viewport().gui_get_focus_owner()
 if focus is LineEdit or focus is TextEdit: return
 for page in PAGES:
  if page.key==KEY_TAB: continue # In a page, Tab belongs to focus navigation.
  if InputBindings.menu_key(event)!=page.key or current_page==page.id: continue
  navigate.call(page.id); get_viewport().set_input_as_handled(); return
 if InputBindings.menu_key(event) in [KEY_O,KEY_N] and current_page!="inventory":
  navigate.call("equipment" if InputBindings.menu_key(event)==KEY_O else "supplies")
  get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
 if not is_visible_in_tree(): return
 var scope: Node=self
 while scope.get_parent() and not scope is CanvasLayer: scope=scope.get_parent()
 if scope is CanvasLayer: GameUIStyle.focus_navigation(scope,event)
