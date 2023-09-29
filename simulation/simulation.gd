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

enum PlayerInputType {
	DIRECTION,
	ROTATION,
	FIRE_GUN,
}

class PlayerInput:
	var input_type: PlayerInputType
	var player: CharacterBody2D
	var direction: Vector2
	var rotation: float
	
	static func create(
			player: CharacterBody2D,
			input_type: PlayerInputType,
			direction: Vector2 = Vector2.ZERO,
			rotation: float = 0.0,
		):
		var player_input = PlayerInput.new()
		player_input.player = player
		player_input.input_type = input_type
		player_input.direction = direction
		player_input.rotation = rotation
		return player_input

func _ready():
	if not multiplayer.is_server():
		set_process(false)
		set_physics_process(false)
		return
		
	frame_buffer.resize(20)
	frame_buffer.fill([])
	
func _physics_process(delta: float):
	process_priority = 0 # Always run the simulation first
	
	frame_time += (delta * 1000)
	
	# TODO: Is this actually a feasible solution?
	if frame_time > desired_frame_time:
		simulate()
		frame_time = frame_time - desired_frame_time

# Called by the server, adds a simulated player
func add_player(player: Player):
	print("Adding player to simulation %d" % player.player)
	simulated_players[player.player] = player

func del_player(player_id: int):
	print("Removing player from simulation %d" % player_id)
	simulated_players.erase(player_id)

@rpc("unreliable", "any_peer", "call_local")
func change_direction(_frame_sent: int, direction: Vector2):
	var player_id = int(multiplayer.get_remote_sender_id())
	player_inputs.append(PlayerInput.create(
		simulated_players[player_id],
		PlayerInputType.DIRECTION,
		direction, # direction
	))

func handle_direction_input(input: PlayerInput):
	var direction = Vector2(
		input.direction.x,
		input.direction.y
	).normalized()
	input.player.velocity.x = direction.x * 400
	input.player.velocity.y = direction.y * 400
	input.player.move_and_slide()

@rpc("unreliable", "any_peer", "call_local")
func change_rotation(_frame_sent: int, rotation: float):
	player_inputs.append(PlayerInput.create(
		simulated_players[multiplayer.get_remote_sender_id()],
		PlayerInputType.ROTATION,
		Vector2.ZERO, #direction
		rotation, # rotation
	))

func handle_rotation_input(input: PlayerInput):
	input.player.rotation = input.rotation

@rpc("reliable", "any_peer", "call_local")
func fire_gun(_frame_sent: int):
	player_inputs.append(PlayerInput.create(
		simulated_players[multiplayer.get_remote_sender_id()],
		PlayerInputType.FIRE_GUN
	))

func handle_fire_gun(_input: PlayerInput):
	pass

func simulate():
	# Process all player inputs (updating the simulation as we go) in order received
	var input_size = player_inputs.size()
	var inputs_this_frame = player_inputs.duplicate()
	player_inputs = []
	
#	print("Processing frame: %d (%d inputs)" % [current_frame, input_size])
	
	for i in range(input_size):
		# We need to reverse through the array to get inputs in the order they were received
		var cur_input: PlayerInput = inputs_this_frame[input_size-i-1]
		
		# Skip players who have since disconnected
		if cur_input.player.player not in simulated_players:
			continue
		
#		print("\tProcessing input of type: %s" % cur_input.input_type)
		apply_input_to_simulation(cur_input)
	
	# The current, full, state of the server simulation
	var snapshot = {}
	
	snapshot["players"] = {}
	for player_id in simulated_players:
		var player = simulated_players[player_id]
		snapshot["players"][player_id] = {
			"position": player.position,
			"rotation": player.rotation
		}
	
	main_level.receive_snapshot.rpc(snapshot)
	
	current_frame += 1
	
func apply_input_to_simulation(input: PlayerInput):
	match input.input_type:
		PlayerInputType.DIRECTION:
			handle_direction_input(input)
		PlayerInputType.ROTATION:
			handle_rotation_input(input)
		PlayerInputType.FIRE_GUN:
			handle_fire_gun(input)
