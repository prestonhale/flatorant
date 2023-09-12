extends Node2D

const SPAWN_RANDOM = 5.0

@onready var debug_drawer = $DebugDrawer

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
	character.hit_something.connect(_on_player_hit_something)
	
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

func del_player(id: int):
	if not $Players.has_node(str(id)):
		return
	$Players.get_node(str(id)).queue_free()

func _on_player_hit_something(global_player_pos: Vector2, hitspot: Vector2):
	debug_drawer.draw_hit(hitspot, global_player_pos)
	
