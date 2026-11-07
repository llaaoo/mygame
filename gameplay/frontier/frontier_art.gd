class_name FrontierArt
extends RefCounted
## Presentation only: atlas cells never create items, collision, or world facts.
const ATLAS: Texture2D=preload("res://content/art/third_party/kenney/tiny_town.png")
static func tile(canvas: CanvasItem, cell: Vector2i, destination: Rect2, tint:=Color.WHITE) -> void:
 region(canvas,Rect2(Vector2(cell)*16,Vector2.ONE*16),destination,tint)
static func region(canvas: CanvasItem, source: Rect2, destination: Rect2, tint:=Color.WHITE) -> void:
 canvas.draw_texture_rect_region(ATLAS,destination,source,tint)
static func house(canvas: CanvasItem, point: Vector2) -> void:
 canvas.draw_rect(Rect2(point-Vector2(130,130),Vector2(272,230)),Color(0,0,0,.20))
 for x in range(5):
  var column:=0 if x==0 else 2 if x==4 else 1
  for y in range(2): tile(canvas,Vector2i(column+4,4+y),Rect2(point+Vector2(x*48-120,y*48-144),Vector2.ONE*48),Color("b7b4a0"))
  for y in range(2):
   var wall:=4 if x==0 else 7 if x==4 else 5
   if y==1: wall=5 if x==2 else 4
   tile(canvas,Vector2i(wall,6+y),Rect2(point+Vector2(x*48-120,y*48-48),Vector2.ONE*48),Color("bab6a2"))
