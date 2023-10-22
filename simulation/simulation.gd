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
var hit_scn = preload("res://simulation/simulated_hit/simulated_hit.tscn")

# The current frame on the server
var current_frame = 0

# The difference between the client "current_frame" and server "current_frame"
# If the client sends "current_frame = 0" when the server is on frame 230 the
# offset if 230
var player_input_frame_offsets := {}

# Player inputs to process
# See "Minimizing Simulation Divergence" here
# https://technology.riotgames.com/news/peeking-valorants-netcode
# And this: https://www.gabrielgambetta.com/entity-interpolation.html
var player_input_frame_map := {}
var player_input_size = 20
var reconcile_tail_size # Keep this many frames to reconcile against (~160ms)
var player_inputs: Array[Dictionary] = []

# The most recent server frame to reconcile agains
var reconcile_frame: Dictionary = {}

# A ring buffer that represents the server's history for "rewinding" to check 
# whether shots fired in the past hit.
# Contains 20 frames. At 128 frames/ticks per second this is 156 ms
var buffer_size = 20
var frame_buffer = []

var desired_frame_time: float = 16.67 # Slow server for testing

# A reference to the main_level which is responsible to displaying the snapshot
var main_level: MainLevel

var delay_processing_by = 3 # Number of frames to buffer

@export var player_speed = 4

# THE SIMULATION

# Simulated players; player_id -> player
var simulated_players = {}
@onready var simulated_tracers = $SimulatedTracers
@onready var simulated_hits = $SimulatedHit

func _ready():
	frame_buffer.resize(20)
	frame_buffer.fill([])
	
	player_inputs.resize(player_input_size)
	player_inputs.fill({})
	
func _physics_process(delta: float):
	process_priority = 1 # Always run the simulation after input
	
	# The simulation doesn't start until the player input begins
	# This ensures that "current_frame" here and in player_input.gd are the same
	if multiplayer.get_unique_id() not in player_input_frame_offsets:
		return 

	if delta * 1000 > desired_frame_time:
		print("ERROR: Slow simulation frame took %dms" % (delta * 1000))
	
	# Get the inputs for the current frame
	var player_input_head = current_frame % player_input_size
	var inputs = player_inputs[player_input_head]

	if not multiplayer.is_server() and reconcile_frame:
		reconcile()
#
	# This is kind of neat if you think about it, the game only needs two things 
	# fully simulate: the amount of time that's passed and the player inputs
#	print("DEBUG: Initial simulate of frame: %d" % current_frame)
	var snapshot = simulate(inputs, delta)
	
#	print("INFO: At frame %d, player was located at %s" % [current_frame, simulated_players[multiplayer.get_unique_id()].position])
	
#	print("INFO: Simulated frame %s (buffer idx %d)" % [current_frame, current_frame % player_input_size])

	# Server: Send snapshots to clients for them to reconcile against
	if multiplayer.is_server():
		for player_id in simulated_players:
			if player_id == 1: continue # Skip the server
			var filtered_snapshot = filter_snapshot_for_client(player_id, snapshot)
			set_reconcile.rpc_id(player_id, filtered_snapshot)
	# Clients: Reconcile against the most recent snapshot you were sent
	
	# IMPORTANT: Wipe out the player input that is now too old to matter > 166.667ms
	player_inputs[(current_frame - 10) % player_input_size] = {}
	
	current_frame += 1

# ========== Filtering ===========
# Filters the entire game state into things this client needs to know about
# For example, this ensures that:
# - players aren't sent the positions of players they can't see
# - players are only sent the parts of bullet tracers they can see
func filter_snapshot_for_client(player_id: int, snapshot: Dictionary) -> Dictionary:
	var snapshot_copy = snapshot.duplicate(true)
	# IMPORTANT: Use snapshot_copy from here out. It will be modified and modify "snapshot" would be BAD.
	
	# Set sanapshot frames to the local frame number for each client (back out the offset)
	snapshot_copy.frame = current_frame - player_input_frame_offsets[player_id]
	
	filter_snapshot_player_data(player_id, snapshot_copy["players"])
	
	return snapshot_copy
	
	
func filter_snapshot_player_data(player_id: int, player_snapshot_data: Dictionary):
	pass
	# TODO: Exclude players you can't see

@rpc("unreliable")
func set_reconcile(snapshot: Dictionary):
	# Update frame to reconcile to if newer
	if snapshot["frame"] > reconcile_frame.get("frame", 0):
		reconcile_frame = snapshot
	

# Update the state of the simulation to match a given snapshot
func reconcile():
	var snapshot := reconcile_frame
	if not snapshot:
		return
	
	var player_pos = snapshot.players[multiplayer.get_unique_id()].position
#	print("Reconcile for frame %d has player at %s" % [snapshot.frame, player_pos])
	
	var frames_in_the_past = current_frame - snapshot["frame"]
#	print("INFO: Player %d Received %d FRAME reconcile from server frame %d local frame %d" % [multiplayer.get_unique_id(), frames_in_the_past, snapshot.frame, current_frame])
	# Put ourself in the state represented by this snapshot at its frame
	reconcile_players(snapshot["players"])
	reconcile_tracers(snapshot["tracers"])
	reconcile_hits(snapshot["hits"])

#	print("Before reconcile %s" % simulated_players[multiplayer.get_unique_id()].position)
	# Replay requested inputs on top of our state to catch back up to current frame
	if frames_in_the_past < 0:
#		print("ERROR: Player %d got a reconcile from the future (local frame: %d, reconcile frame %d)" % [snapshot.player_id, current_frame, snapshot.frame])
		return
	for frame_in_the_past in range(frames_in_the_past, 0, -1):
		var player_input_head = (current_frame - frame_in_the_past) % player_input_size
		var past_input = player_inputs[player_input_head]
#		print(past_input)

		# Resimulate previous frames
#		print("INFO: Reconcile simulate of frame: %d" % (current_frame - frame_in_the_past))
		simulate(past_input, 16.666667) # TODO: Do we even need delta?
	
#	print("After reconcile %s" % simulated_players[multiplayer.get_unique_id()].position)
	
	reconcile_frame = {}

# =========== Hit ==========
func add_simulated_hit(hit_id: String, position: Vector2):
	var hit = hit_scn.instantiate()
	if hit_id == "":
		hit.name = str(hit.get_instance_id())
	else:
		hit.name = hit_id
	hit.position = position
	simulated_hits.add_child(hit)
	hit.emitting = true

func reconcile_hits(hit_snapshot_data: Dictionary):
	for hit_id in hit_snapshot_data.keys():
		if not simulated_hits.get_node_or_null(hit_id):
			var hit_data = hit_snapshot_data[hit_id]
			add_simulated_hit(hit_data["id"], hit_data["position"])

# ========== Tracer ==========
func reconcile_tracers(tracer_snapshot_data: Dictionary):
	for tracer_id in tracer_snapshot_data.keys():
	# Add
<<<<<<< HEAD
		var tracer_data = tracer_snapshot_data[tracer_id]
		if not simulated_tracers.get_node(tracer_id) \
		and tracer_data["player_id"] != str(multiplayer.get_unique_id()): # Don't reconcile our personal tracers
			add_simulated_tracer(tracer_id, tracer_data["player_id"], tracer_data["start"], tracer_data["end"])
=======
		if not simulated_tracers.get_node_or_null(tracer_id):
			var tracer_data = tracer_snapshot_data[tracer_id]
			add_simulated_tracer(tracer_id, tracer_data["start"], tracer_data["end"])
>>>>>>> 2f2b0b929f6626e665cbe0fbbd30f24d1c00c258
	# Reconcile: We don't reconcile existing tracers, they're very ephemeral
	# Remove: See above
			
func add_simulated_tracer(tracer_id: String, player_id: String, start: Vector2, end: Vector2):
	var tracer = tracer_scn.instantiate()
	if tracer_id == "":
		tracer_id = str(tracer.get_instance_id())
	tracer.name = tracer_id
	tracer.id = tracer_id
	tracer.player_id = player_id
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
	player.frames_since_last_shot = player_data.frames_since_last_shot

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
		offset = (current_frame - player_input.current_frame)
		player_input_frame_offsets[player_input.player_id] = offset
		print("INFO: Got first input for player %s: offset frames %d" % [player_input.player_id, offset])
	
	var player_frame_in_server_time = player_input.current_frame + offset
	# If this input for the frame we are just about to simulate, this is 0
	# Large numbers here mean the server is running slowly or something is wrong client-side
	var frames_into_future = player_frame_in_server_time - current_frame 
	if frames_into_future >= 8:
		print("WARN: Received an input frame in the distant future (%d frames) from %d local frame %d server frame %d; discarding" % [frames_into_future, player_input.player_id, player_input.current_frame + offset, current_frame])
		return
	
	# This input arrived too late, the server has moved on :(
	# Should only happen when the player has -significant- lag
	# This allows for (~10 frames * 16.6667ms per frame) = 166.667ms of lag
	if frames_into_future < -10:
		print("WARN: Received input from player %s behind the server, discarding" % player_input.player_id)
		# Reset their offset so once they send packets again it can catch up
		player_input_frame_offsets.erase(player_input.player_id)
		return
	
	var input_idx = (player_frame_in_server_time + delay_processing_by)  % player_input_size
	# Sanity check do we already have input for this frame, should be impossible
	if player_inputs[input_idx].get(player_input.player_id, null) != null:
		print(player_inputs[input_idx])
		print("WARN: Already have input for player %s at server frame %s (local frame %d, offset %d, buffer_idx %s)" % [player_input.player_id, player_frame_in_server_time, player_input.current_frame, offset, input_idx])
		return
	
#	print("INFO: Assigning player input to buffer index %d" % input_idx)

	player_inputs[input_idx][player_input.player_id] = player_input

func handle_direction_input(input: Dictionary):
	var direction = Vector2(
		input.direction.x,
		input.direction.y
	).normalized()
	var player = simulated_players[input.player_id]
	player.velocity.x = direction.x * player_speed
	player.velocity.y = direction.y * player_speed
	player.move_and_collide(Vector2(player.velocity.x, player.velocity.y))

func handle_rotation_input(input: Dictionary):
	var player = simulated_players[input.player_id]
	player.rotation = input.rotation

func handle_fire_gun(input: Dictionary):
	if input.fired:
		var player: Player = simulated_players[input.player_id]
		
		if player.frames_since_last_shot < 25:
			return
		
		player.frames_since_last_shot = 0
		
		# Raycast from player to collision
		var start_of_ray = player.global_position
		# Line extending in direction player is facing
		var end_of_ray = player.global_position + (Vector2.from_angle(player.rotation) * 5000)
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(start_of_ray, end_of_ray, 2)
		var result = space_state.intersect_ray(query)
		
		if result: # But if it hits something, use that
			end_of_ray = result.position
			var hit = result.collider
			
			# Only servers can validate hits
			if multiplayer.is_server():
				if hit.is_in_group("player"):
					add_simulated_hit("", result.position)
		
		add_simulated_tracer("", str(player.player), start_of_ray, end_of_ray)

func simulate(inputs: Dictionary, _delta: float):
#	print("INFO: Simulating server frame: %d (input buffer idx: %d)" % [current_frame, player_input_head])
	
	# Hits are only sent in a single frame
	
	# Check if we have everyone's input when processing server
	if multiplayer.is_server():
		for player_id in simulated_players:
			if player_id not in inputs:
				print("WARN: Frame %d don't have input for %s" % [current_frame, player_id])
		
	for player_id in inputs:
		var input = inputs[player_id]
		apply_input_to_simulation(input)
	
	# Time-based simulation advancement
	# Tick up "time since last shot"
	for player in simulated_players.values():
		player.frames_since_last_shot += 1
	
	# The current, full, state of the server simulation
	var snapshot = {}
	
	snapshot["frame"] = current_frame # The frame this snapshot represents
	
	snapshot["players"] = {}
	for player_id in simulated_players:
		var player = simulated_players[player_id]
		snapshot["players"][player_id] = {
			"position": player.position,
			"rotation": player.rotation,
			# TODO: Filter so its only sent to the player who shot
			"frames_since_last_shot": player.frames_since_last_shot,
		}
	
	# TODO: Don't display your own tracers
	snapshot["tracers"] = {}
	for tracer in $SimulatedTracers.get_children():
		snapshot["tracers"][tracer.name] = {
			"player_id": tracer.player_id,
			# Global positions
			"start": tracer.start,
			"end": tracer.end,
		}
	
	snapshot["hits"] = {}
	for hit in simulated_hits.get_children():
		snapshot["hits"][hit.name] = {
			"position": hit.position,
			"id": hit.name
		}
	
	return snapshot
	
func apply_input_to_simulation(input: Dictionary):
	# Shots must happen before the player's move so they're accurate to what the player saw last frame
	handle_fire_gun(input)
	handle_direction_input(input)
	handle_rotation_input(input)
