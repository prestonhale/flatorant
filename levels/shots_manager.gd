extends Node2D

@onready var splashes = $Splashes

var shot_scn = preload("res://effects/shot/shot.tscn")
var splash_index = 0

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
	var hit_player
	var dmg_location
	if collision:
		hit_player = collision.get_parent() as Player
		if collision.name == "Head":
			shot_pos = ray.get_collision_point()
			dmg_location = Health.DamageLocation.head
			print("Hit Head!")
		elif collision.name == "Torso":
			# Exclude the torso, check again to see if our shot passesd through
			# the head
			ray.add_exception(collision)
			ray.force_raycast_update()
			ray.clear_exceptions()
			if ray.is_colliding() and ray.get_collider().name == "Head":
				# Headshot! Update the hit location.
				shot_pos = ray.get_collision_point()
				dmg_location = Health.DamageLocation.head
				print("Hit Head!")
			# No head shot, so this is a regular torso shot
			else:
				dmg_location = Health.DamageLocation.shoulder
				print("Hit: Torso!")
	
	draw_hit_splash.rpc(shot_pos)
	draw_tracer.rpc(player.position, shot_pos)
	
	# ==== Server Section ====
	if multiplayer.is_server():
		# Hits must be confirmed on the server to be valid
		if hit_player:
			hit_player.take_hit.rpc(shot_pos, dmg_location)


@rpc("call_local")
func draw_hit_splash(shot_pos: Vector2):
	print("draw_hit_splash")
	
	var splash = splashes.get_child(splash_index)
	splash.global_position = shot_pos
	add_child(splash)
	splash.restart()
	splash.emitting = true
	
	# Move index up, restart if needed
	splash_index += 1
	if splash_index > splashes.get_child_count() - 1:
		splash_index = 0


@rpc("call_local")
func draw_tracer(start: Vector2, end: Vector2):
	print("draw_tracer")
	var shot = shot_scn.instantiate()
	shot.add_point(start)
	shot.add_point(end)
	add_child(shot)
