extends Node2D

const SPAWN_RANDOM = 5.0

@export var death_timer = 2.0

var shot_scn = preload("res://player/shot/shot.tscn")

@onready var players := $Players
@onready var debug_drawer := $DebugDrawer
@onready var ray := $RayCast2D
@onready var shots_manager := $ShotsManager
var current_character

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
	
	character.gun.fired_shot.connect(_on_character_fired_shot)
	
	var player_count = $Players.get_child_count() - 1
	character.change_color(PLAYER_COLORS[player_count])

	# Capture important signals from this player
#	character.vision_cone_area.body_entered.connect(
#		func(other_player: Node2D): _on_vision_cone_body_entered(character, other_player)
#	)
#	character.vision_cone_area.body_exited.connect(
#		func(other_player: Node2D): _on_vision_cone_body_exited(character, other_player)
#	)
	character.fired_shot.connect(shots_manager.on_player_fired_shot)
	character.health.died.connect(
		func(): _on_player_died(character))
	
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
	var points = []
	
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
	player.position = $StartPosition.position

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
	

func _draw():
	draw_circle(circle_pos, 10, Color.RED)
#	draw_line(line_pos_a, line_pos_b, Color.YELLOW_GREEN, 2)
	

func del_player(id: int):
	if not $Players.has_node(str(id)):
		return
	$Players.get_node(str(id)).queue_free()
	
func _unhandled_input(event: InputEvent):
	if Input.is_action_just_pressed("exit"):
		get_tree().quit()
	
