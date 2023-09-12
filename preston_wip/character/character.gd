extends CharacterBody2D

class_name Player

signal hit_something 

const SPEED = 400

@onready var ray = $RayCast2D 
@onready var input = $PlayerInput
@onready var vision_cone_area = $VisionCone2D/VisionConeArea
@onready var server_synchronizer = $ServerSynchronizer

@export var player := 1 :
	set(id):
		player = id
		# You can't use "input" here because this assignment happens BEFORE 
		# "onready". You must use "$" syntax in this func
		$PlayerInput.set_multiplayer_authority(id)

var debug_draw = false

func _ready():
	# Hide vision cone this isn't "us".
	# This check is just "do we control this player's input" aka "is it us"
	if input.get_multiplayer_authority() != multiplayer.get_unique_id():
		$VisionCone2D.hide()
	
func _process(delta):
	if input.fired:
		print("fired")
		if ray.is_colliding():
			print("colliding")
			var hitspot = ray.get_collision_point()
			hit_something.emit(global_position, hitspot)
	
	look_at(input.mouse_position)
	
	# Get the input from the multiplayer synchronizer and apply it
	var direction = Vector2(
		input.direction.x,
		input.direction.y
	).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.y = direction.y * SPEED
	else:
		velocity.x = 0
		velocity.y = 0
		
	move_and_slide()

func set_visible_to(opponent_id: int):
	server_synchronizer.set_visibility_for(opponent_id, true)

func set_invisible_to(opponent_id: int):
	server_synchronizer.set_visibility_for(opponent_id, false)
	



