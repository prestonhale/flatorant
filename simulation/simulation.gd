extends Node2D

class_name Simulation

# ========== Debug ==========
var debug = false
# Note: This even applies "latency" to the server!
var fake_additional_player_latency_ms = 100

# As the players send inputs up those inputs are placed in the buffer to be 
# processed by the game simulation.
# As the simulation runs, it pulls down the inputs for a frame, simulates them
# and then sends updates to the players
# The server is perpetually BEHIND the client view by the length of the buffer.
# This is to give players inputs time to reach the server and be processed.

var tracer_scn = preload("res://simulation/simulated_tracer/simulated_tracer.tscn")
var player_scn = preload("res://player/player.tscn")
var debug_player_scn = preload("res://player/debug_player.tscn")
var hit_scn = preload("res://simulation/simulated_hit/simulated_hit.tscn")

# The assumed time of a frame in ms
var default_frame_time = 16.66667 # 60fps

# Debug options
var show_debug_visualization = true

# The current frame on the server
var current_frame = 0

# The difference between the client "current_frame" and server "current_frame"
# If the client sends "current_frame = 0" when the server is on frame 230 the
# offset if 230
var player_input_frame_offsets := {}

# The difference between the client "get_ticks_msec" and server "get_ticks_msec"
var player_input_msec_offsets := {}

# Every X frames we reconcile the players position with the server
# Can result in rubberbanding if the server and player disagree on position
var frames_between_self_reconcile = 1

# Player inputs to process
# See "Minimizing Simulation Divergence" here
# https://technology.riotgames.com/news/peeking-valorants-netcode
# And this: https://www.gabrielgambetta.com/entity-interpolation.html
var player_input_frame_map := {}
var player_input_size = 30
var reconcile_tail_size # Keep this many frames to reconcile against (~160ms)
var player_inputs: Array[Dictionary] = []

# Player clock times
# player_id -> []pings_in_ms
var player_pings = {}

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

@export var player_speed = 5

# THE SIMULATION
var previous_frame_time = 0

# Simulated players; player_id -> player
var simulated_players = {}
@onready var debug_players = $DebugPlayers
@onready var simulated_tracers = $SimulatedTracers
@onready var simulated_hits = $SimulatedHit

func get_server_time():
	return Time.get_unix_time_from_system() * 1000

func _ready():
	frame_buffer.resize(20)
	frame_buffer.fill([])
	
	player_inputs.resize(player_input_size)
	for i in range(player_input_size):
		player_inputs[i] = {}

var time_since = 0
var prev_tick: int = 0
var accrued_frame_time: float = 0
	
	
func _physics_process(delta: float):
	#print("==Simulating frame %d==" % current_frame)
#	print((Time.get_ticks_usec() - previous_frame_time)/1000)
	previous_frame_time = Time.get_ticks_usec()
	process_priority = 1 # Always run the simulation after input
	
	# The simulation doesn't start until the player input begins
	# This ensures that "current_frame" here and in player_input.gd are the same
#	if multiplayer.get_unique_id() not in player_input_frame_offsets:
#		return 

	# Clients: Reconcile against the most recent snapshot you were sent
	if not multiplayer.is_server() and reconcile_frame:
		#print("DEBUG: Reconciling to frame " + str(reconcile_frame["frame"]))
		reconcile()
#
	# Get the inputs for the current frame
	var player_input_head = current_frame % player_input_size
	var inputs = player_inputs[player_input_head]
	
	# This is kind of neat if you think about it, the game only needs two things 
	# fully simulate: the amount of time that's passed and the player inputs
#	print("DEBUG: Initial simulate of frame: %d" % current_frame)
#	print("DEBUG: Input %s" % inputs)
	var snapshot = simulate(inputs)
	
#	print("INFO: At frame %d, player was located at %s" % [current_frame, simulated_players[multiplayer.get_unique_id()].position])
	
	#print("INFO: Simulated frame %s (buffer idx %d)" % [current_frame, current_frame % player_input_size])

	# Server: Send snapshots to clients for them to reconcile against
	if multiplayer.is_server():
		#var snapshot = simulate(inputs)
		for player_id in simulated_players:
			if player_id == 1: continue # Skip the server
			if not player_input_frame_offsets.get(player_id, null): continue # Skip the first frame 
			var filtered_snapshot = filter_snapshot_for_client(player_id, snapshot)
			
			# Include current timestamp for purposes of ping
			filtered_snapshot["time"] = Time.get_unix_time_from_system() * 1000 # To ms
			
			set_reconcile.rpc_id(player_id, filtered_snapshot)
	
	current_frame += 1
	#print("===Frame Finished %d===" % (current_frame - 1))

# ========== Filtering ===========
# Filters the entire game state into things this client needs to know about
# For example, this ensures that:
# - players aren't sent the positions of players they can't see
# - players are only sent the parts of bullet tracers they can see
func filter_snapshot_for_client(player_id: int, snapshot: Dictionary) -> Dictionary:
	var snapshot_copy = snapshot.duplicate(true)
	# IMPORTANT: Use snapshot_copy from here out. It will be modified and modify "snapshot" would be BAD.
	
	# Set snapshot frames to the local frame number for each client (back out the offset)
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
	#print("DEBUG Reconciling. Our current frame: %d. The server's frame: %d." % [current_frame, reconcile_frame.frame])
	
	if show_debug_visualization:
		reconcile_debug_players(snapshot["players"])
	
	var player_pos = snapshot.players[multiplayer.get_unique_id()].position
#	print("Reconcile for frame %d has player at %s" % [snapshot.frame, player_pos])
	# Put ourself in the state represented by this snapshot at its frame
	reconcile_players(snapshot["players"])
	reconcile_tracers(snapshot["tracers"])
	reconcile_hits(snapshot["hits"])
#	print("DEBUG: Reconciled to snapshot at frame: %d" % snapshot["frame"])

	if current_frame % frames_between_self_reconcile == 0:
		var simulate_from_frame = snapshot["frame"] + 1 # We reconciled to snapshot.frame so don't rerun it
		var simulate_to_frame = current_frame # We don't want to include "current_frame" but the range below is not inclusive so its fine
		print("INFO: Player %d reconcile from server frame %d -> local %d" % [multiplayer.get_unique_id(), simulate_from_frame, simulate_to_frame])
		# print("Before reconcile %s" % simulated_players[multiplayer.get_unique_id()].position)
		# Replay requested inputs on top of our state to catch back up to current frame
		for frame_in_the_past in range(simulate_from_frame, simulate_to_frame):
			var player_input_head = frame_in_the_past % player_input_size
			var past_input = player_inputs[player_input_head]

			#Resimulate presvious frames
			print("DEBUG: Past input for frame %d (buffer idx %d) %s" % [frame_in_the_past, player_input_head, past_input])
			simulate(past_input)
			var physics_server = PhysicsServer2D
			var player = simulated_players[1]
			var space_rid = physics_server.body_get_space(player.get_rid())
			#PhysicsServer2D.space_step(space_rid, 16.667)
		
#	print("After reconcile %s" % simulated_players[multiplayer.get_unique_id()].position)
	
	reconcile_frame = {}

# =========== Hit ==========
func add_simulated_hit(hit_id: String, hit_position: Vector2):
	var hit = hit_scn.instantiate()
	if hit_id == "":
		hit.name = str(hit.get_instance_id())
	else:
		hit.name = hit_id
	hit.position = hit_position
	simulated_hits.add_child(hit)
	hit.emitting = true

func reconcile_hits(hit_snapshot_data: Dictionary):
	for hit_id in hit_snapshot_data.keys():
		if not simulated_hits.get_node_or_null(hit_id):
			var hit_data = hit_snapshot_data[hit_id]
			add_simulated_hit(hit_data["id"], hit_data["position"])
	# Reconcile: We don't reconcile existing tracers, they're very ephemeral
	# Remove: See above

# ========== Tracer ==========
func reconcile_tracers(tracer_snapshot_data: Dictionary):
	for tracer_id in tracer_snapshot_data.keys():
	# Add
		var tracer_data = tracer_snapshot_data[tracer_id]
		if not simulated_tracers.get_node(tracer_id) \
		and tracer_data["player_id"] != str(multiplayer.get_unique_id()): # Don't reconcile our personal tracers
			add_simulated_tracer(tracer_id, tracer_data["player_id"], tracer_data["start"], tracer_data["end"])
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

# ========== Debug Rewound Players ==========
# Brings the server and client simulated players into sync
func reconcile_debug_players(player_snapshot_data: Dictionary): 
	for player_id in player_snapshot_data.keys():
		var player_data = player_snapshot_data[player_id]
		
		player_id = str(player_id) + "_debug"
		var player = debug_players.get_node(str(player_id))
		
		# Add
		if not player:
			player = add_debug_player(player_id, player_data.position, player_data.rotation)
		
		# Reconcile
		reconcile_debug_player(player, player_data)

func add_debug_player(player_id: String, player_position: Vector2, rotation: float) -> CharacterBody2D:
	print("DEBUG: Adding DEBUG player to simulation %d" % player_id)
	var player = debug_player_scn.instantiate()
	debug_players.add_child(player)
	player.position = player_position
	player.rotation = rotation
	player.name = player_id
	return player

func reconcile_debug_player(player: CharacterBody2D, player_data: Dictionary):
	player.position = player_data.position
	player.rotation = player_data.rotation

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
		if not player.is_current_player() or current_frame % frames_between_self_reconcile == 0:
			reconcile_player(player, player_snapshot_data[player_id])
		
		# Remove: TODO

func reconcile_player(player: Player, player_data: Dictionary):
	player.health = player_data.health
	player.position = player_data.position
	player.rotation = player_data.rotation
	player.frames_since_last_shot = player_data.frames_since_last_shot

func add_simulated_player(player_id: int, position: Vector2, rotation: float) -> Player:
	print("DEBUG: Adding player to simulation %d" % player_id)
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
	print("DEBUG: Removing player from simulation %d" % player.player)
	simulated_players.erase(player.player)
	main_level.players.remove_child(player)
	player.queue_free()

@rpc("unreliable", "any_peer")
func accept_player_input(player_input: Dictionary):
	# Local input, assign it to the next frame and return
	if player_input.player_id == multiplayer.get_unique_id():
		var input_idx = player_input.current_frame % player_input_size
		print("INFO: Assigning player input. Frame: %d. Buffer index %d." % [player_input.current_frame, input_idx])
		print("DEBUG: Input: %s" % player_input)
		player_inputs[input_idx][player_input.player_id] = player_input
		return
	
	#print("Input from %d" % player_input.player_id)
	var server_time = (Time.get_ticks_msec())

	var offset = player_input_frame_offsets.get(player_input.player_id, null)
	var msec_offset = player_input_msec_offsets.get(player_input.player_id, null)

	# This is the first input we've received for this player, add to offset map
	if offset == null:
		offset = (current_frame - player_input.current_frame)
		player_input_frame_offsets[player_input.player_id] = offset + delay_processing_by
		
		msec_offset = server_time - player_input.time
		player_input_msec_offsets[player_input.player_id] = msec_offset
		
		player_pings[player_input.player_id] = msec_offset * 2
		
		print("INFO: Got first input for player %s: offset %d" % [player_input.player_id, offset])
	
	# Calculate time it took for this command to reach the server in ms
	if not multiplayer.is_server():
		var latency_from_player = current_frame - offset - player_input.current_frame
		var latency_from_player_ms = server_time - msec_offset - player_input.time
		#print("DEBUG: latency_from_player: frame %d, ms %d" % [latency_from_player, latency_from_player_ms])

	# Slowly move towards more recent pings
	player_pings[player_input.player_id] = (
		(player_pings[player_input.player_id] * 10) 
		+ (server_time - player_input.time)
	)/11
	
	var player_frame_in_server_time = player_input.current_frame + offset
	if debug:
		player_frame_in_server_time += int(fake_additional_player_latency_ms/default_frame_time)
	# If this input for the frame we are just about to simulate, this is 0
	# Large numbers here mean the server is running slowly or something is wrong client-side
	var frames_into_future = player_frame_in_server_time - current_frame 
	if frames_into_future >= 12:
		print("WARN: Received an input frame in the distant future (%d frames) from %d local frame %d server frame %d; discarding" % [frames_into_future, player_input.player_id, player_input.current_frame + offset, current_frame])
		return
	
	# This input arrived too late, the server has moved on :(
	# Should only happen when the player has -significant- lag
	# This allows for (~10 frames * 16.6667ms per frame) = 166.667ms of lag
	if frames_into_future < 0:
		print("WARN: Received input from player %s behind the server, discarding" % player_input.player_id)
		# Reset their offset so once they send packets again it can catch up
		player_input_frame_offsets.erase(player_input.player_id)
		return
	
	var input_idx = player_frame_in_server_time % player_input_size
	#print("INFO: Assigning player input to buffer index %d" % input_idx)
	player_inputs[input_idx][player_input.player_id] = player_input

func handle_direction_input(input: Dictionary):
	var accel = .3
	
	var player = simulated_players[input.player_id]
	
	if player.health <= 0:
		return 
	
	var input_direction = Vector2(
		input.direction.x,
		input.direction.y
	).normalized()
	
	var new_velocity = player.velocity.move_toward((input_direction * player_speed), accel)
	
	player.velocity.x = new_velocity.x
	player.velocity.y = new_velocity.y
	# https://github.com/godotengine/godot-proposals/issues/2821#issuecomment-854081858
	player.move_and_collide(input_direction * player_speed)
	print("=====", Vector2(player.velocity.x, player.velocity.y))

func handle_rotation_input(input: Dictionary):
	var player = simulated_players[input.player_id]
	
	if player.health <= 0:
		return 
	
	player.rotation = input.rotation

func handle_fire_gun(input: Dictionary):
	if input.fired:
		var player: Player = simulated_players[input.player_id]
		
		# Can't shoot if dead
		if player.health <= 0:
			return
		
		# Can't shoot too quickly
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
		
		if result: # But if it h/its something, use that
			end_of_ray = result.position
			var hit = result.collider
			
			# IMPORTANT: Only servers can validate hits and apply damage
			if multiplayer.is_server():
				if hit.is_in_group("player"):
					var hit_player = hit.get_parent()
					hit_player.health -= 25
					add_simulated_hit("", result.position)
		
		add_simulated_tracer("", str(player.player), start_of_ray, end_of_ray)

func simulate(inputs: Dictionary):
#	print("INFO: Simulating server frame.")
	
	# Check if we have everyone's input when processing server
	if multiplayer.is_server():
		for player_id in simulated_players:
			if player_id not in inputs:
				print("WARN: Frame %d don't have input for %s" % [current_frame, player_id])
		
	for player_id in inputs:
		var input = inputs[player_id]
		apply_input_to_simulation(input)
	
	
	# Time-based simulation advancement
	for player in simulated_players.values():
		# Time out player's that have died
		if player.health <= 0:
			player.frames_since_died += 1
			if player.frames_since_died >= 200:
				player.health = 100
				player.frames_since_died = 0
		
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
			"health": player.health,
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

func get_current_player_position() -> Vector2:
	for player in simulated_players.values():
		if player.is_current_player():
			return player.position
	return Vector2.ZERO
