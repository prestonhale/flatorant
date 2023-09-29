extends Node2D

class_name MainLevel

const SPAWN_RANDOM = 5.0

@export var death_timer = 2.0

var shot_scn = preload("res://effects/shot/shot.tscn")

@onready var players := $Players
@onready var ray := $RayCast2D
@onready var shots_manager := $ShotsManager
@onready var fog_of_war := $FogOfWar
@onready var start_positions := $StartPositions
@onready var simulation := $Simulation

var ready_to_simulate = false

var current_character # The character representing our client's player

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
#	process_priority = 30

	for player in MultiplayerLobby.players.values():
		add_player(player["id"])
	
	MultiplayerLobby.player_connected.connect(_on_player_connected)
	simulation.main_level = self
	
	random_level()
#
	ready_to_simulate = true

func _on_player_connected(new_player_id: int, new_player_info: Dictionary):
	print("Added peer: %d" % new_player_id)
	add_player(new_player_id)

@rpc("reliable", "call_local")
func add_player(id: int):
	print("add_player: %d" % id)
	var character = preload("res://player/player.tscn").instantiate()
	character.player = id
	character.position = _get_start_pos().position
	character.name = str(id)
	$Players.add_child(character, true)
	
	simulation.add_player(character)
	character.input.simulation = simulation
	
#	var player_count = $Players.get_child_count() - 1
#	character.change_color(PLAYER_COLORS[player_count])

	# Capture important signals from this player
#	character.vision_cone_area.body_entered.connect(
#		func(other_player: Node2D): _on_vision_cone_body_entered(character, other_player)
#	)
#	character.vision_cone_area.body_exited.connect(
#		func(other_player: Node2D): _on_vision_cone_body_exited(character, other_player)
#	)
#	character.fired_shot.connect(
#		shots_manager.on_player_fired_shot)
#
#	character.health.died.connect(
#		func(): _on_player_died(character))
#
	# Fog of war follows only our character
	if id == multiplayer.get_unique_id():
		current_character = character
		fog_of_war.tracked_player = current_character

@rpc("reliable", "call_local")
func del_player(id: int):
	if simulation:
		simulation.del_player(id)
		
	if not $Players.has_node(str(id)):
		return
		
	$Players.get_node(str(id)).queue_free()

@rpc("call_local", "unreliable")
func receive_snapshot(snapshot: Dictionary):
	if not ready_to_simulate:
		return 
		
	if multiplayer.is_server():
		return # The server has already updated its simulation
	
	var player_ids = []
	for player in players.get_children():
		player_ids.append(int(str(player.name)))
	
	var player_snapshot_data = snapshot["players"]
	for player_id in player_snapshot_data:
		if player_id not in player_ids:
			print("ERROR: Got a simulation frame for a player we don't know about: %s" % player_id)
			print(player_ids)
			continue
		var player = players.get_node(str(player_id))
		var player_data = player_snapshot_data[player_id]
		
		# Set the player's position to render
		player.position = player_data["position"]
		player.rotation = player_data["rotation"]

# Hook up the player to all the systems that track their actions
func _track_new_player(player: Player):
	if player.player == multiplayer.get_unique_id():
		current_character = player
		fog_of_war.tracked_player = current_character
	shots_manager.track_player(player)
	
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


@rpc("call_local", "reliable")
func _draw_shot_tracer(player_pos: Vector2, shot_pos: Vector2):
	var shot = shot_scn.instantiate()
	shot.add_point(player_pos)
	shot.add_point(shot_pos)
	add_child(shot)

func _get_start_pos() -> Node2D:
	return start_positions.get_child(randi_range(0, (start_positions.get_child_count()-1)))

func _draw():
	draw_circle(circle_pos, 10, Color.RED)
#	draw_line(line_pos_a, line_pos_b, Color.YELLOW_GREEN, 2)
	
func random_level():
	var rlevel = [preload("res://levels/vanilla_level.tscn")]
#	var rlevel = [preload("res://levels/crab_level.tscn"),preload("res://levels/vanilla_level.tscn")]
	var i = randi_range(0,rlevel.size()-1)
	var newlevelr = rlevel[i].instantiate()
	add_child(newlevelr)
	move_child(newlevelr,0)
	
func _unhandled_input(_event: InputEvent):
	if Input.is_action_just_pressed("exit"):
		get_tree().quit()
	
