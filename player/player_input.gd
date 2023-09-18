extends Node2D

var ray: RayCast2D

var enabled = true

@export var direction := Vector2()
@export var mouse_position := Vector2()
@export var fired := false

@onready var synchronizer = $PlayerInputSynchronizer


func _ready():
	# Allow server (but no other players) to see our inputs
	synchronizer.set_visibility_for(1, true)
	
	# Only process for the local player
	var is_our_player = get_multiplayer_authority() == multiplayer.get_unique_id()
	set_process(is_our_player)
	print("Accepting input for player: %s" % multiplayer.get_unique_id())
	

func _process(delta):
	if not enabled:
		return
	
	direction = Input.get_vector("left", "right", "up", "down")
	
	mouse_position = get_global_mouse_position()
	
	fired = false
	if Input.is_action_just_pressed("fire"):
		fired = true

func _on_mouse_position_updated(in_mouse_position):
	mouse_position = in_mouse_position
	

