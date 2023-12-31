# https://github.com/samsface/godot-tutorials/blob/master/camera/camera.gd
extends Camera2D

var current_player: Player

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not current_player:
		return
	var mouse_position = get_global_mouse_position() - offset
	var direction_to_mouse =  mouse_position - global_position
	var distance_to_mouse = min(current_player.PLAYER_VISION_LIMIT/2, global_position.distance_to(mouse_position))
		
	var lean = direction_to_mouse.normalized() * distance_to_mouse
	$Debug.text = "direction_to_mouse:%.2f, %.2f" % [direction_to_mouse.x, direction_to_mouse.y]
	$Debug.text += "\ndistance_to_mouse:%.2f" % distance_to_mouse
	$Debug.text += "\nlean:%.2f, %.2f" % [lean.x, lean.y]
	offset = lean
	
	position = current_player.position
