class_name ItemArtView
extends Control
## A stable inspection area for authored artwork, with the existing item image as fallback.
var texture: Texture2D
var uses_illustration := false
var item_id := ""
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 clip_contents=true
 custom_minimum_size.y=180
 resized.connect(queue_redraw)
func present(definition: ItemData,uid: String) -> void:
 item_id=definition.id; set_meta("item_uid",uid)
 texture=null
 texture=definition.illustration_texture()
 uses_illustration=texture!=null
 if not uses_illustration: texture=InterfaceIcons.item(definition)
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR if uses_illustration or not texture is AtlasTexture else CanvasItem.TEXTURE_FILTER_NEAREST
 queue_redraw()
func _draw() -> void:
 var frame:=GameUIStyle.surface_style()
 frame.bg_color=Color(GameUIStyle.SURFACE,.38); frame.border_color=GameUIStyle.PANEL_BORDER; frame.set_corner_radius_all(0)
 draw_style_box(frame,Rect2(Vector2.ZERO,size))
 if not texture: return
 var available:=size-Vector2(32,24)
 if available.x<=0 or available.y<=0: return
 var image_size:=texture.get_size()
 if image_size.x<=0 or image_size.y<=0: return
 var fit:=minf(available.x/image_size.x,available.y/image_size.y)
 if not uses_illustration: fit=minf(fit,112.0/maxf(image_size.x,image_size.y))
 var extent:=image_size*fit
 draw_texture_rect(texture,Rect2((size-extent)*.5,extent),false)
