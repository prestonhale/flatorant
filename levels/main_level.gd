extends Node2D

class_name MainLevel

const SPAWN_RANDOM = 5.0

@export var death_timer = 2.0

var gun = preload("res://content/gun.gd")
var content = preload("res://content/content.gd")
var shot_scn = preload("res://effects/shot/shot.tscn")

@onready var players := $Players
@onready var ray := $RayCast2D
@onready var shots_manager := $ShotsManager
@onready var fog_of_war := $FogOfWar

@onready var simulation := $Simulation

var map: Map = null

var ready_to_simulate = false

var current_character: Player # The character representing our client's player

var PLAYER_COLORS = [
	Color.RED,
	Color.GREEN,
	Color.BLUE,
	Color.PURPLE,
	Color.ORANGE,
	Color.YELLOW
]

var circle_pos = Vector2.ZERO
var line_pos_a = Vector2.ZERO
var line_pos_b = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready():
	# Process after player nodes
	process_priority = 30

	simulation.main_level = self
	
	map = random_map()

	for player in MultiplayerLobby.players.values():
		add_player(player["id"])
	
	MultiplayerLobby.player_connected.connect(_on_player_connected)
	MultiplayerLobby.player_disconnected.connect(_on_player_disconnected)
#
	ready_to_simulate = true
	

func _on_player_connected(new_player_id: int, new_player_info: Dictionary):
	print("Added peer: %d" % new_player_id)
	add_player(new_player_id)

func _on_player_disconnected(player_id: int):
	print("Removed peer: %d" % player_id)
	del_player(player_id)

@rpc("reliable", "call_local")
func add_player(id: int):
	print("add_player: %d" % id)
	var position = _get_start_pos().global_position
	
	var player = simulation.add_simulated_player(id, position, 0, Vector2.ZERO)

	# Fog of war follows only our character
	if id == multiplayer.get_unique_id():
		current_character = player as Player
		fog_of_war.tracked_player = current_character

	var small_gun = gun.new()
	small_gun.gun_type = content.gun_types.pistol
	player.pickup_gun(small_gun)
	
	var large_gun = gun.new()
	large_gun.gun_type = content.gun_types.rapid
	player.pickup_gun(large_gun)
	
	player.server_acknowledge.rpc_id(player.player)

@rpc("reliable", "call_local")
func del_player(id: int):
	if not $Players.has_node(str(id)):
		return
	
	var player = $Players.get_node(str(id))
	
	if simulation:
		simulation.remove_simulated_player(player)

# State should not change here, this function is about DISPLAYING the state
func _physics_process(delta: float):
	if not ready_to_simulate:
		return 

	var player_ids = []
	for player in players.get_children():
		player_ids.append(int(str(player.name)))
	
	# Filter out things the player can't see
	# TODO: This should be server-side eventually but that's a hard problem to solve
	set_player_visibility()
	set_tracer_visibility()
	set_hit_marker_visibility()

func set_player_visibility():
	for player_node in players.get_children():
		var other_player: Player = player_node as Player
		if current_character.can_see(other_player):
			other_player.show()
		else:
			other_player.hide()

func set_tracer_visibility():
	pass

func set_hit_marker_visibility():
	pass
		
	
	
# Hook up the player to all the systems that track their actions
func _track_new_player(player: Player):
	if player.player == multiplayer.get_unique_id():
		current_character = player
		fog_of_war.tracked_player = current_character

func _on_character_fired_shot(player_pos: Vector2, shot_pos: Vector2):
	# Cast rays to get entry aand exit points of all view cones it passes through
	var cones = {} # PlayerId -> [EntryVec, ExitVec]
	
	# Cast ray forwards to get entry points
	ray.position = player_pos
	ray.target_position = shot_pos - player_pos
	ray.force_raycast_update()
	while ray.is_colliding():
		var collider = ray.get_collider()
		cones[collider] = [ray.get_collision_point()]
		ray.add_exception(collider) # Don't hit this cone again
		ray.force_raycast_update()
	
	ray.clear_exceptions()
	
	# Cast ray backwards to get exit pointsda
	ray.position = shot_pos
	ray.target_position = player_pos - shot_pos
	ray.force_raycast_update()
	while ray.is_colliding():
		var collider = ray.get_collider()
		cones[collider].append(ray.get_collision_point())
		ray.add_exception(collider) # Don't hit this cone again
		ray.force_raycast_update()
	
	ray.clear_exceptions()

	for c in cones:
		var p = cones[c]
		var p_id = c.get_parent().get_parent().player
		_draw_shot_tracer.rpc_id(p_id, p[0], p[1])
			
func _on_player_died(player: Player):
	print("_on_player_died")
	player._on_died.rpc()
	get_tree().create_timer(death_timer).timeout.connect(
		func (): _on_character_death_timer_expired(player)
	)

func _on_character_death_timer_expired(player: Player):
	print("Respawn")
	player.respawn.rpc()
	player.position = _get_start_pos().position

func debug_print(a, b):
	var shot = shot_scn.instantiate()
	shot.add_point(a)
	shot.add_point(b)
	add_child(shot)

func _draw_shot_tracer(point1: Vector2, point2: Vector2):
	var shot = shot_scn.instantiate()
	shot.add_point(to_local(point1))
	shot.add_point(to_local(point2))
	add_child(shot)
	
func _get_start_pos() -> Node2D:
	return map.start_positions.get_child(randi_range(0, (map.start_positions.get_child_count()-1)))
	
func random_map():
	var rlevel = [preload("res://levels/vanilla_level.tscn")]
#	var rlevel = [preload("res://levels/crab_level.tscn"),preload("res://levels/vanilla_level.tscn")]
	var i = randi_range(0,rlevel.size()-1)
	var newlevelr = rlevel[i].instantiate()
	add_child(newlevelr)
	move_child(newlevelr,0)
	return newlevelr
	
func _unhandled_input(_event: InputEvent):
	if Input.is_action_just_pressed("exit"):
		get_tree().quit()
	
