@tool
class_name MapFurniture
extends Node2D
## Visual and collision footprint are edited together. Layout owns runtime bodies.
@export_enum("wall", "table", "bed", "shelf", "chest", "hearth", "rug", "window", "door", "house", "bench", "anvil") var form := "table":
	set(value): form=value; queue_redraw()
@export var footprint := Vector2(100,50):
	set(value): footprint=value; queue_redraw()
@export var solid := true:
	set(value): solid=value; queue_redraw()
@export var tint := Color("927459"):
	set(value): tint=value; queue_redraw()
@export var caption := "":
	set(value): caption=value; queue_redraw()
@export var texture: Texture2D:
	set(value): texture=value; queue_redraw()
@export var visual_size := Vector2.ZERO:
	set(value): visual_size=value; queue_redraw()
@export var visual_offset := Vector2.ZERO:
	set(value): visual_offset=value; queue_redraw()
func _draw() -> void:
	var r:=Rect2(-footprint*.5,footprint)
	if form=="house":
		FrontierArt.house(self,Vector2.ZERO)
	elif texture:
		if solid: draw_rect(Rect2(r.position+Vector2(6,9),r.size),Color(0,0,0,.23))
		var extent:=visual_size if visual_size!=Vector2.ZERO else footprint
		draw_texture_rect(texture,Rect2(visual_offset-extent*.5,extent),false)
	else:
		if form not in ["rug","window","door"]: draw_rect(Rect2(r.position+Vector2(6,9),r.size),Color(0,0,0,.23))
		draw_rect(r,tint)
		draw_rect(r,tint.lightened(.2),false,2)
		match form:
			"wall":
				for x in range(int(r.position.x)+16,int(r.end.x),48): draw_line(Vector2(x,r.position.y),Vector2(x,r.end.y),tint.darkened(.35),2)
			"table","bench":
				for y in range(int(r.position.y)+8,int(r.end.y),12): draw_line(Vector2(r.position.x+4,y),Vector2(r.end.x-4,y),tint.darkened(.25),1)
				if form=="table":
					draw_circle(Vector2(-footprint.x*.2,0),9,Color("b9aa84"))
					draw_circle(Vector2(footprint.x*.22,-3),7,Color("c3a16c"))
			"bed":
				draw_rect(r.grow(-7),Color("675e58"))
				draw_rect(Rect2(r.position+Vector2(9,9),Vector2(footprint.x-18,25)),Color("c0b8a0"))
				draw_rect(Rect2(r.position+Vector2(9,41),Vector2(footprint.x-18,footprint.y-50)),Color("69817a"))
			"shelf":
				for x in range(int(r.position.x)+6,int(r.end.x)-5,11):
					var c:=Color("aa8055") if posmod(x,3)==0 else Color("64766e") if posmod(x,2)==0 else Color("9c8d6a")
					draw_rect(Rect2(x,r.position.y+7,8,footprint.y-14),c)
			"chest":
				draw_line(Vector2(r.position.x,0),Vector2(r.end.x,0),Color("d1b278"),3)
				for x in [-footprint.x*.3,footprint.x*.3]: draw_line(Vector2(x,r.position.y),Vector2(x,r.end.y),Color("4d514b"),5)
				draw_rect(Rect2(-4,-4,8,12),Color("d0b47d"))
			"hearth":
				draw_rect(r.grow(-8),Color("302e29"))
				draw_circle(Vector2.ZERO,minf(footprint.x,footprint.y)*.27,Color("b87940"))
				draw_circle(Vector2(0,-3),minf(footprint.x,footprint.y)*.14,Color("e2b269"))
			"rug": draw_rect(r.grow(-8),tint.lightened(.35),false,2)
			"window":
				draw_rect(r.grow(-4),Color("a6bec1"))
				draw_line(Vector2(0,r.position.y),Vector2(0,r.end.y),Color("4d514b"),5)
			"door":
				for x in range(int(r.position.x)+8,int(r.end.x),12): draw_line(Vector2(x,r.position.y),Vector2(x,r.end.y),Color("463f34"),2)
				draw_circle(Vector2(footprint.x*.3,0),3,Color("d1b278"))
			"anvil": draw_colored_polygon(PackedVector2Array([Vector2(-30,-12),Vector2(34,-12),Vector2(18,1),Vector2(8,1),Vector2(14,16),Vector2(-15,16),Vector2(-10,1),Vector2(-27,-2)]),Color("b1b4a5"))
	if not caption.is_empty(): draw_string(GameUIStyle.font(),Vector2(-120,-footprint.y*.5-15),caption,HORIZONTAL_ALIGNMENT_CENTER,240,15,Color("e0d4b4"))
	if Engine.is_editor_hint() and solid: draw_rect(r,Color(.9,.4,.25,.65),false,1)
