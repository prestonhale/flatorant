extends MultiplayerSynchronizer

var ray: RayCast2D

@export var direction := Vector2()
@export var mouse_position := Vector2()
@export var fired := false

func _ready():
	# Only process for the local player.
	var is_our_player = get_multiplayer_authority() == multiplayer.get_unique_id()
	set_process(is_our_player)
	set_process_unhandled_input(is_our_player)
	

func _process(delta):
	direction = Input.get_vector("left", "right", "up", "down")
	
	fired = false
	if Input.is_action_just_pressed("fire"):
		fired = true
	

#func _unhandled_input(event):
#	# Get rotation needed to look at mouse
#	if event is InputEventMouseMotion:
#		mouse_position = event.global_position
#		print (get_viewport().get_mouse_position())
#
#		var viewport = get_viewport()
#		print (viewport.get_mouse_position())
	
