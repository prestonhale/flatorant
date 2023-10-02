extends Node2D

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

# The difference between the client "current_frame" and server "current_frame"
# If the client sends "current_frame = 0" when the server is on frame 230 the
# offset if 230
var player_input_frame_offsets := {}

# Player inputs to process
# See "Minimizing Simulation Divergence" here
# https://technology.riotgames.com/news/peeking-valorants-netcode
var player_input_frame_map := {}
var player_input_size = 20
var player_inputs: Array[Dictionary] = []

# A ring buffer that represents the server's history for "rewinding" to check 
# whether shots fired in the past hit.
# Contains 20 frames. At 128 frames/ticks per second this is 156 ms
var buffer_size = 20
var frame_buffer = []

var desired_frame_time: float = 16.67 # Slow server for testing

# A reference to the main_level which is responsible to displaying the snapshot
var main_level: MainLevel

var delay_processing_by = 1 # Number of frames to buffer

@export var player_speed = 2

# THE SIMULATION

# Simulated players; player_id -> player
var simulated_players = {}
@onready var simulated_tracers = $SimulatedTracers

func _ready():
	frame_buffer.resize(20)
	frame_buffer.fill([])
	
	player_inputs.resize(player_input_size)
	player_inputs.fill([])
	
func _physics_process(delta: float):
	process_priority = 1 # Always run the simulation after input
	

	if delta * 1000 > desired_frame_time:
		print("ERROR: Slow simulation frame took %dms" % (delta * 1000))

	var snapshot = simulate(delta)
	
#	print("INFO: Simulated frame %s (buffer idx %d)" % [current_frame, current_frame % player_input_size])

	# Send snapshots to clients for them to reconcile against
	if multiplayer.is_server():
		for player_id in simulated_players:
			if player_id == 1: continue # Skip the server
			var filtered_snapshot = filter_snapshot_for_client(player_id, snapshot)
			reconcile.rpc_id(player_id, filtered_snapshot)
	
	# IMPORTANT: Clear player inputs from this frame in the ring buffer
	player_inputs[current_frame % player_input_size] = {}
	
	current_frame += 1

# ========== Filtering ===========
# Filters the entire game state into things this client needs to know about
# For example, this ensures that:
# - players aren't sent the positions of players they can't see
# - players are only sent the parts of bullet tracers they can see
func filter_snapshot_for_client(player_id: int, snapshot: Dictionary) -> Dictionary:
	var snapshot_copy = snapshot.duplicate(true)
	# IMPORTANT: Use snapshot_copy from here out. It will be modified and modify "snapshot" would be BAD.
	filter_snapshot_player_data(player_id, snapshot_copy["players"])
	return snapshot_copy
	
	
func filter_snapshot_player_data(player_id: int, player_snapshot_data: Dictionary):
	# TEMPORARY: Players do not reconcile against their own data
	for player_id_in_snapshot in player_snapshot_data:
		if player_id == player_id_in_snapshot:
			player_snapshot_data.erase(player_id)
			return
	

# Update the state of the simulation to match a given snapshot
@rpc("unreliable")
func reconcile(snapshot: Dictionary):
	reconcile_players(snapshot["players"])
	reconcile_tracers(snapshot["tracers"])


# ========== Tracer ==========
func reconcile_tracers(tracer_snapshot_data: Dictionary):
	for tracer_id in tracer_snapshot_data.keys():
	# Add
		if not simulated_tracers.get_node(tracer_id):
			var tracer_data = tracer_snapshot_data[tracer_id]
			add_simulated_tracer(tracer_id, tracer_data["start"], tracer_data["end"])
	# Reconcile: We don't reconcile existing tracers, they're very ephemeral
	# Remove: See above
			
func add_simulated_tracer(tracer_id: String, start: Vector2, end: Vector2):
	var tracer = tracer_scn.instantiate()
	if tracer_id == "":
		tracer_id = str(tracer.get_instance_id())
	tracer.name = tracer_id
	tracer.start = start
	tracer.end = end
	simulated_tracers.add_child(tracer)

# ========== Player ==========
# Brings the server and client simulated players into sync
func reconcile_players(player_snapshot_data: Dictionary): 
	for player_id in player_snapshot_data.keys():
		# Add
		if player_id not in simulated_players.keys():
			var player_data = player_snapshot_data[player_id]
			add_simulated_player(player_id, player_data.position, player_data.rotation)
		
		# Reconcile
		var player = simulated_players[player_id]
		reconcile_player(player, player_snapshot_data[player_id])
		
		# Remove: TODO

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

	var offset = player_input_frame_offsets.get(player_input.player_id, null)
	
	# This is the first input we've received for this player, add to offset map
	if offset == null:
		offset = 2 + (current_frame - player_input.current_frame)
		player_input_frame_offsets[player_input.player_id] = offset
		print("INFO: Got first input for player %s: offset frames %d" % [player_input.player_id, offset])
	
	var player_frame_in_server_time = player_input.current_frame + offset
	# If this input for the frame we are just about to simulate, this is 0
	# Large numbers here mean the server is running slowly or something is wrong client-side
	var frames_into_future = player_frame_in_server_time - current_frame 
	if frames_into_future >= 2 + delay_processing_by:
		print("WARN: Received an input frame in the distant future (%d frames) from %d local frame %d server frame %d" % [frames_into_future, player_input.player_id, player_input.current_frame + offset, current_frame])
	
	# This input arrived too late, the server has moved on :(
	# Should only happen when the player has significant lag
	if frames_into_future < 0:
		print("WARN: Received input from player %s behind the server, discarding" % player_input.player_id)
		return
	
	var input_idx = player_frame_in_server_time  % player_input_size
	# Sanity check do we already have input for this frame, should be impossible
	if player_inputs[input_idx].get(player_input.player_id, null) != null:
		print(player_inputs[input_idx])
		print("WARN: Already have input for player %s at server frame %s (local frame %d, offset %d, buffer_idx %s)" % [player_input.player_id, player_frame_in_server_time, player_input.current_frame, offset, input_idx])
		return
	
#	player_inputs.append(player_input)
#	print("INFO: Assigning player input to buffer index %d" % input_idx)
	player_inputs[input_idx][player_input.player_id] = player_input

func handle_direction_input(input: Dictionary):
	var direction = Vector2(
		input.direction.x,
		input.direction.y
	).normalized() * player_speed
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
		
		# Raycast from player to collision
		var start_of_ray = player.global_position
		# Line extending in direction player is facing
		var end_of_ray = player.global_position + (Vector2.from_angle(player.rotation) * 5000)
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(start_of_ray, end_of_ray)
		var result = space_state.intersect_ray(query)
		
		var collision_point = end_of_ray # If the shot hits nothing show it ending off-screen
		if result: # But if it hits something, use that
			collision_point = result.position
		
		add_simulated_tracer("", player.global_position, collision_point)

func simulate(delta: float):
	# Process all player inputs (updating the simulation as we go) in order received
	
	var player_input_head = current_frame % player_input_size
#	print("INFO: Simulating server frame: %d (input buffer idx: %d)" % [current_frame, player_input_head])
	
	var inputs = player_inputs[player_input_head]
	
	for player_id in inputs:
		var input = inputs[player_id]
		apply_input_to_simulation(input)
	
	# The current, full, state of the server simulation
	var snapshot = {}
	
	snapshot["players"] = {}
	for player_id in simulated_players:
		var player = simulated_players[player_id]
		snapshot["players"][player_id] = {
			"position": player.position,
			"rotation": player.rotation
		}
	
	snapshot["tracers"] = {}
	for tracer in $SimulatedTracers.get_children():
		# Simulated tracers is a already a dictionary so just add
		snapshot["tracers"][tracer.name] = {
			# Global positions
			"start": tracer.start,
			"end": tracer.end,
		}
	
	return snapshot
	
func apply_input_to_simulation(input: Dictionary):
	# Shots must happen before the player's move so they're accurate to what the player saw last frame
	handle_fire_gun(input)
	handle_direction_input(input)
	handle_rotation_input(input)
