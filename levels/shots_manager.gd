extends Node2D

var shot_scn = preload("res://shot/shot.tscn")

func _ready():
	var player_spawner = $"../PlayerSpawner"
	player_spawner.spawned.connect(track_player)

func track_player(player: Player):
	player.fired_shot.connect(on_player_fired_shot)

# TODO: Include more details about the shot like "what gun"
func on_player_fired_shot(player: Player):
#	print("on_player_fired_shot")
	var ray = player.get_node("Gun").get_node("RayCast2D")
	var shot_pos = ray.get_collision_point()

	var collision = ray.get_collider()
	if collision:
		if collision.name == "Torso":
			# Exclude the torso, check again to see if our shot passesd through
			# the head
			ray.add_exception(collision)
			ray.force_raycast_update()
			ray.clear_exceptions()
			if ray.is_colliding() and ray.get_collider().name == "Head":
				# Headshot! Update the hit location.
				shot_pos = ray.get_collision_point()
				print("Hit Head!")
			# No head shot, so this is a regular torso shot
			else:
				print("Hit: Torso!")

	draw_tracer.rpc(player.position, shot_pos)
	
	if multiplayer.is_server():
		# TODO: Draw the tracers that can be seen in vision cones
		pass

@rpc("call_local")
func draw_tracer(start: Vector2, end: Vector2):
	print("draw_tracer")
	var shot = shot_scn.instantiate()
	shot.add_point(start)
	shot.add_point(end)
	add_child(shot)
