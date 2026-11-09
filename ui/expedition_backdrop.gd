class_name ExpeditionBackdrop
extends Control
## Original cartographic ornament. No actor, world state or gameplay random calls.
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 resized.connect(queue_redraw)
func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),GameUIStyle.PANEL_BG_SOLID)
 # Quiet river contours leave the reading columns clear.
 for contour in range(10):
  var points:=PackedVector2Array()
  for step in range(55):
   var y:=size.y*step/54.0
   var x:=size.x*.86+sin(y*.008+contour*.14)*38+cos(y*.017)*12+contour*15
   points.append(Vector2(x,y))
  draw_polyline(points,Color(GameUIStyle.GOLD,.025+contour*.002),1,true)
 draw_line(Vector2(0,0),Vector2(size.x,0),Color(GameUIStyle.GOLD,.65),2)
 draw_line(Vector2(0,size.y-1),Vector2(size.x,size.y-1),Color(GameUIStyle.GOLD,.16),1)
