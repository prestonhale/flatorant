extends Node2D

@onready var ray = $RayCast2D

# Captured by server
signal fired_shot

var bullet_scn = preload("res://player/shot/shot.tscn")

func shoot() -> Vector2:
	var shot_pos = ray.get_collision_point()
	# TODO: is_class is hacky
	fired_shot.emit(position, shot_pos)
	
	# Everything after this point is just what the CLIENT thinks happened, the server will verify
	var collision = ray.get_collider()
	if collision:
		if collision.name == "Torso":
			var player = collision.owner as Player
			# Exclude the torso, check again to see if our shot passesd through
			# the head
			ray.add_exception(collision)
			ray.force_raycast_update()
			ray.clear_exceptions()
			if ray.is_colliding() and ray.get_collider().name == "Head":
				# Headshot! Update the hit location.
				shot_pos = ray.get_collision_point()
#				print("Client says 'Headshot'!")
				return shot_pos
			# No head shot, so this is a regular torso shot
			# print("Client says 'Torsoshot'!")
	return shot_pos
