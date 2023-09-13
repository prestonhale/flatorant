extends Node2D
var hitspot 
var character_location

func _draw():
	if hitspot:
		draw_circle(to_local(hitspot), 10, Color.ORANGE)
		draw_line(to_local(character_location), to_local(hitspot), Color.RED, 2)
#		get_tree.timer

func draw_hit(in_hitspot, in_character_location):
	hitspot = in_hitspot
	character_location = in_character_location
	queue_redraw()
#
#
#func _on_cleanup_timer():
#
