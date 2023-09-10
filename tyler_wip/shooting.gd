extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
		if Input.is_action_just_pressed("fire"):
			print("shoot")
			if ray.is_colliding():
				print("hit") 
				hitspot = ray.get_collision_point()
				print(hitspot)
				queue_redraw()
			

func _draw():
	if hitspot:
		draw_circle(to_local(hitspot), 10, Color.RED)
	pass
