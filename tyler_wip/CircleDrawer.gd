extends Node2D
var hitspot 

func _draw():
	if hitspot:
		draw_circle(to_local(hitspot), 10, Color.RED)

func draw_hitspot(in_hitspot):
	hitspot=in_hitspot
	queue_redraw()
	
