extends Node

class_name Simulation

# As the players send inputs up those inputs are placed in the buffer to be 
# processed by the game simulation.
# As the simulation runs, it pulls down the inputs for a frame, simulates them
# and then sends updates to the players
# The server is perpetually BEHIND the client view by the length of the buffer.
# This is to give players inputs time to reach the server and be processed.

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

# Simulated players; player_id -> player
var simulated_players = {}

@export var player_speed = 200

func _ready():
	frame_buffer.resize(20)
	frame_buffer.fill([])
	
func _physics_process(delta: float):
	process_priority = 0 # Always run the simulation first
	
	frame_time += (delta * 1000)
	
	var snapshot = simulate(delta)
	main_level.receive_snapshot(snapshot)
	
	# Only save and send the snapshot on server ticks
	if multiplayer.is_server():
		update_client_snapshots(delta, snapshot)

func update_client_snapshots(delta: float, snapshot: Dictionary):
	frame_time += (delta * 1000)
	if frame_time > desired_frame_time:
#		print("snap send")
		main_level.receive_snapshot.rpc(snapshot)
		
		frame_time = frame_time - desired_frame_time
		current_frame += 1

# Called by the server, adds a simulated player
func add_player(player: Player):
	print("Adding player to simulation %d" % player.player)
	simulated_players[player.player] = player

func del_player(player_id: int):
	print("Removing player from simulation %d" % player_id)
	simulated_players.erase(player_id)

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
	
	return snapshot
	
func apply_input_to_simulation(input: Dictionary, delta: float):
	handle_direction_input(input, delta)
	handle_rotation_input(input)
#	handle_fire_gun(input)
