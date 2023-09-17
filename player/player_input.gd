extends MultiplayerSynchronizer

var ray: RayCast2D

var enabled = true

@export var direction := Vector2()
@export var mouse_position := Vector2()
@export var fired := false

func _ready():
	# Only process for the local player.
	var is_our_player = get_multiplayer_authority() == multiplayer.get_unique_id()
	set_process(is_our_player)

func _process(delta):
	if not enabled:
		return
	
	direction = Input.get_vector("left", "right", "up", "down")
	
	fired = false
	if Input.is_action_just_pressed("fire"):
		fired = true
	

