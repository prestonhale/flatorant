extends Node

class_name Simulation

# As the players send inputs up those inputs are placed in the buffer to be 
# processed by the game simulation.
# As the simulation runs, it pulls down the inputs for a frame, simulates them
# and then sends updates to the players
# The server is perpetually BEHIND the client view by the length of the buffer.
# This is to give players inputs time to reach the server and be processed.

var tracer_scn = preload("res://simulation/simulated_tracer/simulated_tracer.tscn")
var player_scn = preload("res://player/player.tscn")

# The current frame on the server
var current_frame = 0

# Player inputs to process
var player_inputs = []

# A ring buffer that represents the server's history for "rewinding" to check 
# whether shots fired in the past hit.
# Contains 20 frames. At 128 frames/ticks per second this is 156 ms
var buffer_size = 20
var frame_buffer = []
var frame_buffer_head = 0

# Accrued time since we last simulated
var frame_time: float = 0
#var desired_frame_time: float = 100 # Slow server for testing
var desired_frame_time: float = 16.66 # 1000ms / 60 ticks

# A reference to the main_level which is responsible to displaying the snapshot
var main_level: MainLevel

@export var player_speed = 200

# THE SIMULATION

# Simulated players; player_id -> player
var simulated_players = {}
@onready var simulated_tracers = $SimulatedTracers

func _ready():
	frame_buffer.resize(20)
	frame_buffer.fill([])
	
func _physics_process(delta: float):
	process_priority = 0 # Always run the simulation first
	
	frame_time += (delta * 1000)
	
	var snapshot = simulate(delta)
	
	# Only save and send the snapshot on server ticks
	if multiplayer.is_server():
		update_client_snapshots(delta, snapshot)

func update_client_snapshots(delta: float, snapshot: Dictionary):
	# TODO: Filter how much of the sim state is sent to each client
	# e.g. don't send the whole tracer if you can only see part of it
	frame_time += (delta * 1000)
	if frame_time > desired_frame_time:
#		print("snap send")
		reconcile.rpc(snapshot)
		
		frame_time = frame_time - desired_frame_time
		current_frame += 1

# Update the state of the simulation to match a given snapshot
@rpc("unreliable")
func reconcile(snapshot: Dictionary):
	reconcile_players(snapshot["players"])
	
	# Brute force recreate tracers
	for tracer in simulated_tracers.get_children():
		remove_simulated_tracer(tracer)
	for tracer in snapshot["tracers"]:
		add_simulated_tracer(tracer["start"], tracer["end"])


# ========== Tracer ==========
func add_simulated_tracer(start: Vector2, end: Vector2):
	var tracer = tracer_scn.instantiate()
	tracer.start = start
	tracer.end = end
	simulated_tracers.add_child(tracer)

func remove_simulated_tracer(tracer: SimulatedTracer):
	tracer.queue_free()
	simulated_tracers.remove_child(tracer)


# ========== Player ==========
# Brings the server and client simulated players into sync
func reconcile_players(player_snapshot_data: Dictionary): 
#	for player_id in simulated_players.keys():
#		if player_id not in player_snapshot_data.keys():
#			remove_simulated_player(simulated_players[player_id])
			
	for player_id in player_snapshot_data.keys():
		if player_id not in simulated_players.keys():
			var player_data = player_snapshot_data[player_id]
			add_simulated_player(player_id, player_data.position, player_data.rotation)
		
	for player_id in player_snapshot_data:
		var player = simulated_players[player_id]
		reconcile_player(player, player_snapshot_data[player_id])

func reconcile_player(player: Player, player_data: Dictionary):
	player.position = player_data.position
	player.rotation = player_data.rotation

func add_simulated_player(player_id: int, position: Vector2, rotation: float) -> Player:
	print("Adding player to simulation %d" % player_id)
	var player = player_scn.instantiate()
	simulated_players[player_id] = player
	player.position = position
	player.rotation = rotation
	player.player = player_id
	player.name = str(player_id)
	main_level.players.add_child(player)
	player.input.simulation = self
	return player

func remove_simulated_player(player: Player):
	print("Removing player from simulation %d" % player.player)
	simulated_players.erase(player.player)
	main_level.players.remove_child(player)
	player.queue_free()


# =========== Player Input ===========
@rpc("unreliable", "any_peer")
func accept_player_input(player_input: Dictionary):
#	print("Input from %d" % player_input.player_id)
	player_inputs.append(player_input)

func handle_direction_input(input: Dictionary, delta: float):
	var direction = Vector2(
		input.direction.x,
		input.direction.y
	).normalized() * delta * player_speed
	var player = simulated_players[input.player_id]
	player.velocity.x = direction.x * 400
	player.velocity.y = direction.y * 400
	player.move_and_slide()

func handle_rotation_input(input: Dictionary):
	var player = simulated_players[input.player_id]
	player.rotation = input.rotation

func handle_fire_gun(input: Dictionary):
	if input.fired:
		var player: Player = simulated_players[input.player_id]
		
		# Get location bullet strikes
		var ray = player.get_node("Gun").get_node("RayCast2D")
		ray.enabled = true
		ray.force_raycast_update()
		var collision_point = ray.get_collision_point()
		ray.enabled = false
		
		add_simulated_tracer(player.position, collision_point)

func simulate(delta: float):
	# Process all player inputs (updating the simulation as we go) in order received
	var input_size = player_inputs.size()
	var inputs_this_frame = player_inputs.duplicate()
	player_inputs = []
	
#	print("Processing frame: %d (%d inputs)" % [current_frame, input_size])
	
	for i in range(input_size):
		# We need to reverse through the array to get inputs in the order they were received
		var cur_input: Dictionary = inputs_this_frame[input_size-i-1]
		
		# Skip players who have since disconnected
		if cur_input["player_id"] not in simulated_players:
			continue
		
		apply_input_to_simulation(cur_input, delta)
	
	# The current, full, state of the server simulation
	var snapshot = {}
	
	snapshot["players"] = {}
	for player_id in simulated_players:
		var player = simulated_players[player_id]
		snapshot["players"][player_id] = {
			"position": player.position,
			"rotation": player.rotation
		}
	
	snapshot["tracers"] = []
	for tracer in $SimulatedTracers.get_children():
		# Simulated tracers is a already a dictionary so just add
		snapshot["tracers"].append({
			"start": tracer.start,
			"end": tracer.end,
	
		})
	
	return snapshot
	
func apply_input_to_simulation(input: Dictionary, delta: float):
	# Shots must happen before the player's move
	handle_fire_gun(input)
	handle_direction_input(input, delta)
	handle_rotation_input(input)
