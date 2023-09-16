extends Node2D

const SPAWN_RANDOM = 5.0

var shot_scn = preload("res://player/shot/shot.tscn")

@onready var players = $Players
@onready var debug_drawer = $DebugDrawer
@onready var ray: RayCast2D = $RayCast2D

# Called when the node enters the scene tree for the first time.
func _ready():
	if not multiplayer.is_server():
		return
	
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(del_player)
	
	# Spawn already connected players
	for id in multiplayer.get_peers():
		add_player(id)
	
	# Spawn a local player unless this is dedicated server
	if not OS.has_feature("dedicated_server"):
		add_player(1)

func _exit_tree():
	if not multiplayer.is_server():
		return
	multiplayer.peer_connected.disconnect(add_player)
	multiplayer.peer_disconnected.disconnect(del_player)
	
func add_player(id: int):
	print("add_player")
	var character = preload("res://player/player.tscn").instantiate()
	character.player = id
	character.position = $StartPosition.position
	character.name = str(id)
	$Players.add_child(character, true)
	character.fired_shot.connect(_on_character_fired_shot)
	
	# These lambda make sure that _on_vision_cone_body_entered etc. ALSO 
	# get the character
	character.vision_cone_area.body_entered.connect(
		func(other_player: Node2D): _on_vision_cone_body_entered(character, other_player)
	)
	character.vision_cone_area.body_exited.connect(
		func(other_player: Node2D): _on_vision_cone_body_exited(character, other_player)
	)
	
# Make the entering player visible to this player
func _on_vision_cone_body_entered(player: Player, other_player: Node2D):
	other_player = other_player as Player
#	print("Enter %s" % other_player.player)
	other_player.set_visible_to(player.player)

# Make the exiting player invisible to this player
func _on_vision_cone_body_exited(player: Player, other_player: Node2D):
	other_player = other_player as Player
#	print("Exit %s" % other_player.player)
	other_player.set_invisible_to(player.player)

func _on_character_fired_shot(player_pos: Vector2, shot_pos: Vector2):
	print("shoot")
	# Cast rays to get entry and exit points of all view cones it passes through
	var cones = {} # PlayerId -> [EntryVec, ExitVec]
	var points = []
	
	debug_print(ray.position, ray.target_position)

	# Raycast "forwards" through all the vision cones until we hit a wall. 
	# This gives a dict of Collider -> [EntryPoint]
#	ray.clear_exceptions()
#	ray.force_raycast_update()
#	while ray.is_colliding():
#		var collider = ray.get_collider()
#		# Don't collide with this thing again when we recast
#
#		cones[collider] = [ray.get_collision_point()]
#
#		ray.add_exception(collider) # Don't collide with this cone again
#		ray.force_raycast_update()
	

	# Now raycast backwards from the shot. If we find a collider
	# that needs an exit point add it.
	# Reverse the raycase
	ray.position = shot_pos
	ray.target_position = to_global(player_pos)
	ray.force_raycast_update()
	ray.clear_exceptions()
#	debug_print(ray.position, ray.get_collision_point())
	while ray.is_colliding():
		var collider = ray.get_collider()
		print(collider)
		# Don't collide with this thing again when we recast
		ray.add_exception(collider)

		if cones.get(collider):
			cones[collider].append(ray.get_collision_point())
		ray.force_raycast_update()
	ray.clear_exceptions()
	
	print(cones)
	for c in cones:
		if cones[c].size() != 2:
			print("fuck")

	for c in cones:
		var shot = shot_scn.instantiate()
		shot.add_point(cones[c][0])
		shot.add_point(cones[c][1])
		add_child(shot)
			
	# Render rays made up of EntryVec, ExitVec to specific players

func debug_print(a, b):
	var shot = shot_scn.instantiate()
	shot.add_point(a)
	shot.add_point(b)
	add_child(shot)


@rpc("call_local")
func _draw_shot_tracer(player_pos: Vector2, shot_pos: Vector2):
	var shot = shot_scn.instantiate()
	shot.add_point(player_pos)
	shot.add_point(shot_pos)
	add_child(shot)
	

func del_player(id: int):
	if not $Players.has_node(str(id)):
		return
	$Players.get_node(str(id)).queue_free()
	
