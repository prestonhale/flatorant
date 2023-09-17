extends Node2D

@onready var ray = $RayCast2D

var bullet_scn = preload("res://player/shot/shot.tscn")

# TODO:
# Currently this MUST BE CALLED ONLY FROM THE SERVER because of the take_hit rpc
func shoot() -> Vector2:
	var shot_pos = ray.get_collision_point()
	# TODO: is_class is hacky
	var collision = ray.get_collider()
	if collision:
		if collision.name == "Torso":
			var player = collision.owner as Player
			# Exclude the torse, check again to see if our shot passesd through
			# the head
			ray.add_exception(collision)
			ray.force_raycast_update()
			ray.clear_exceptions()
			if ray.is_colliding() and ray.get_collider().name == "Head":
				# Headshot! Update the hit location.
				shot_pos = ray.get_collision_point()
#				print("Headshot!")
				player.take_hit.rpc(shot_pos, Health.DamageLocation.head)
			else:
				# No head shot, so this is a regular torso shot
#				print("Hit torso!")
				player.take_hit.rpc(shot_pos, Health.DamageLocation.shoulder)
					
	return shot_pos
