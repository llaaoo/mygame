class_name FrontierScenery
extends Node2D
## Decorative ground detail has no gameplay grants or invisible collision.
var game: GrayriverGame
func _ready() -> void:
 z_index=-90
func _draw() -> void:
 var rng:=RandomNumberGenerator.new()
 rng.seed=60816
 if game.region_id!="camp":
  for i in range(180):
   var p:=Vector2(rng.randf_range(-900,900),rng.randf_range(-480,480))
   draw_line(p,p+Vector2(rng.randf_range(8,35),0),Color(0,0,0,.1),1)
  if game.region_id=="river_mine":
   for p in [Vector2(-560,-300),Vector2(260,310),Vector2(500,-310)]:
    _rails(p)
    _crates(p+Vector2(70,20))
  elif game.region_id=="river_prison":
   for p in [Vector2(-700,-440),Vector2(440,400),Vector2(850,-400)]:
    for x in range(-50,60,20): draw_line(p+Vector2(x,0),p+Vector2(x,60),Color("595a53"),5)
    draw_line(p,p+Vector2(0,60),Color("a28758"),3)
  else:
   for p in [Vector2(-460,-350),Vector2(300,280)]:
    for i in range(5):
     draw_rect(Rect2(p+Vector2(i*20,0),Vector2(15,28)),Color("645546"))
     draw_line(p+Vector2(i*20+3,2),p+Vector2(i*20+3,26),Color("ac9970"),2)
  return
 # Fine grasses, stones and flecks break up the large authored biomes.
 for i in range(4200):
  var p:=Vector2(rng.randf_range(-4750,4750),rng.randf_range(-3550,3550))
  if absf(p.x-300)<155 or ((p-Vector2(650,-2800))/Vector2(700,420)).length()<1: continue
  var c:=Color("829066") if p.x<0 else Color("968273")
  c.a=rng.randf_range(.10,.27)
  draw_line(p,p+Vector2(0,-rng.randf_range(2,6)),c,1)
  if i%4==0: draw_line(p+Vector2(-3,0),p+Vector2(-5,-4),c,1)
 for road in game.definition.roads:
  for i in range(road.size()-1):
   var a:=GrayriverDefinition.vector(road[i])
   var b:=GrayriverDefinition.vector(road[i+1])
   var length:=int(a.distance_to(b)/42)
   for j in range(length):
    var p:=a.lerp(b,float(j)/maxi(length,1))+Vector2(rng.randf_range(-35,35),rng.randf_range(-35,35))
    draw_rect(Rect2(p,Vector2(rng.randf_range(9,18),4)),Color(0,0,0,.1))
 # Lake ripples, reeds and a worn jetty, with an open walking area on the shore.
 for i in range(65):
  var angle:=rng.randf_range(0,TAU)
  var p:=Vector2(650,-2800)+Vector2(cos(angle),sin(angle))*Vector2(700,420)*rng.randf_range(.2,.9)
  draw_line(p,p+Vector2(18,0),Color(.6,.8,.8,.13),1)
 for i in range(32):
  var p:=Vector2(650,-2800)+Vector2(cos(i*TAU/32),sin(i*TAU/32))*Vector2(755,455)
  for j in range(3): draw_line(p+Vector2(j*4,0),p+Vector2(j*6-3,-20-j*3),Color("788867"),2)
 _platform(Vector2(1120,-2160),Vector2(220,148))
 _brazier(Vector2(1120,-2208),game.progress.claims.has("river.north_beacon"))
 _shelter(Vector2(1435,-2170),Color("827657"))
 _crates(Vector2(1330,-2275))
 _sign(Vector2(1035,-1990),"矿道 / 湖岸")
 # Mine portal, a visible cart, ore workings and rails.
 var mine:=Vector2(-1300,-2800)
 draw_circle(mine+Vector2(0,-24),110,Color("676a60"))
 draw_circle(mine+Vector2(0,-18),75,Color("252e2d"))
 draw_rect(Rect2(mine+Vector2(-62,-82),Vector2(16,126)),Color("887550"))
 draw_rect(Rect2(mine+Vector2(46,-82),Vector2(16,126)),Color("887550"))
 draw_line(mine+Vector2(-70,-80),mine+Vector2(70,-80),Color("a18a5e"),16)
 _rails(mine+Vector2(0,90))
 _crates(mine+Vector2(130,60))
 _sign(mine+Vector2(-155,95),"山脚矿道")
 # Town paving, stall awnings, wood piles and washing lines.
 _platform(Vector2(-3300,2100),Vector2(360,190))
 _shelter(Vector2(-3100,1705),Color("597b77"))
 _shelter(Vector2(-2860,2330),Color("9a7353"))
 _crates(Vector2(-3010,1810))
 _sign(Vector2(-3620,2240),"河谷镇")
 draw_line(Vector2(-4210,1570),Vector2(-3970,1570),Color("5e5b46"),2)
 for i in range(4): draw_rect(Rect2(-4190+i*52,1570,30,36),Color("a39b7a"))
 # The ruined caravan and an open-sided guard shelter tell the road story.
 _platform(Vector2(-1940,950),Vector2(200,120))
 draw_set_transform(Vector2(-1940,960),-.22)
 draw_rect(Rect2(-46,-35,92,54),Color("604c35"))
 for x in [-43,43]:
  draw_circle(Vector2(x,20),21,Color("292d28"))
  draw_arc(Vector2(x,20),17,0,TAU,16,Color("a2916b"),3)
 draw_line(Vector2(40,-22),Vector2(105,-10),Color("8f7852"),6)
 draw_set_transform(Vector2.ZERO)
 _crates(Vector2(-1835,1020))
 _shelter(Vector2(-1690,525),Color("74694f"))
 _sign(Vector2(-1790,780),"旧驿路")
 # Waterworks has a recessed wheel and stone apron; entrances remain open.
 _platform(Vector2(2760,700),Vector2(330,210))
 for radius in [64,46]: draw_arc(Vector2(2890,680),radius,0,TAU,32,Color("7d7960"),6)
 for i in range(8):
  var v:=Vector2.from_angle(i*TAU/8)*61
  draw_line(Vector2(2890,680)-v,Vector2(2890,680)+v,Color("514e40"),4)
 _sign(Vector2(2570,825),"废弃水工区")
 # Prison forecourt: broken stonework flanks the real passage.
 _platform(Vector2(3300,-1570),Vector2(360,220))
 for x in [-185,185]:
  var p:=Vector2(3300+x,-1690)
  draw_rect(Rect2(p-Vector2(32,54),Vector2(64,108)),Color("343c38"))
  for y in range(-40,50,22): draw_line(p+Vector2(-30,y),p+Vector2(30,y),Color("717365"),2)
 _sign(Vector2(3100,-1440),"余烬旧监狱")
func _platform(p: Vector2, size: Vector2) -> void:
 draw_rect(Rect2(p-size*.5,size),Color(0,0,0,.12))
 for x in range(int(-size.x/2),int(size.x/2),32):
  for y in range(int(-size.y/2),int(size.y/2),24): draw_rect(Rect2(p+Vector2(x+2,y+2),Vector2(28,19)),Color("696b58"))
func _rails(p: Vector2) -> void:
 for y in range(-100,130,20): draw_line(p+Vector2(-29,y),p+Vector2(29,y),Color("78684d"),7)
 for x in [-20,20]: draw_line(p+Vector2(x,-110),p+Vector2(x,130),Color("9b9e91"),3)
func _crates(p: Vector2) -> void:
 for offset in [Vector2.ZERO,Vector2(35,16)]:
  draw_rect(Rect2(p+offset-Vector2(16,14),Vector2(32,28)),Color("5d4832"))
  draw_rect(Rect2(p+offset-Vector2(16,14),Vector2(32,28)),Color("a38c60"),false,2)
  draw_line(p+offset-Vector2(13,11),p+offset+Vector2(13,11),Color("88704b"),3)
func _shelter(p: Vector2, color: Color) -> void:
 for x in [-60,60]: draw_line(p+Vector2(x,-8),p+Vector2(x,35),Color("756047"),5)
 draw_colored_polygon(PackedVector2Array([p+Vector2(-82,-5),p+Vector2(0,-65),p+Vector2(82,-5)]),color.darkened(.25))
 draw_colored_polygon(PackedVector2Array([p+Vector2(-82,-5),p+Vector2(0,-65),p+Vector2(0,-5)]),color)
 draw_line(p+Vector2(0,-65),p+Vector2(0,-5),color.lightened(.2),2)
func _brazier(p: Vector2, lit: bool) -> void:
 for x in [-18,18]: draw_line(p+Vector2(x,-5),p+Vector2(x*1.4,28),Color("46473f"),5)
 draw_rect(Rect2(p-Vector2(30,17),Vector2(60,24)),Color("373e3b"))
 draw_arc(p-Vector2(0,9),29,0,PI,20,Color("a18a65"),4)
 if lit:
  draw_circle(p-Vector2(0,22),38,Color(1,.6,.15,.13))
  draw_colored_polygon(PackedVector2Array([p+Vector2(-18,-11),p+Vector2(-7,-46),p+Vector2(4,-30),p+Vector2(15,-51),p+Vector2(20,-11)]),Color("e39844"))
func _sign(p: Vector2, title: String) -> void:
 draw_line(p,p+Vector2(0,35),Color("574a34"),5)
 draw_rect(Rect2(p-Vector2(50,15),Vector2(100,26)),Color("504a37"))
 draw_string(ThemeDB.fallback_font,p+Vector2(-45,3),title,HORIZONTAL_ALIGNMENT_LEFT,90,12,Color("cabd92"))
