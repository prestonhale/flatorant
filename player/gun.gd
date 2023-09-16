extends Node2D

@onready var ray = $RayCast2D

var bullet_scn = preload("res://player/shot/shot.tscn")

func shoot() -> Vector2:
	var collision = ray.get_collider()
	var shot_pos = ray.get_collision_point()
	if collision:
		# TODO: More damage for headshot
		if collision.name == "Torso" or collision.name == "Head":
			var player = collision.owner as Player
			player.take_hit.rpc(shot_pos)
	return shot_pos
	
