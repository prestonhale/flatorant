extends CharacterBody2D

class_name Player

signal fired_shot

const SPEED = 400


@onready var input = $PlayerInput
@onready var vision_cone = $VisionCone2D
@onready var vision_cone_area = $VisionCone2D/VisionConeArea
@onready var server_synchronizer = $ServerSynchronizer
@onready var health = $Health
@onready var gun = $Gun
@onready var sprite = $PlayerSprite2D

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
	if is_current_player():
		add_child(Camera2D.new())
	else:
		$VisionCone2D.hide()

func is_current_player() -> bool:
	return input.get_multiplayer_authority() == multiplayer.get_unique_id()

@rpc("call_local")
func take_hit(hit_pos: Vector2, dmg_location: Health.DamageLocation):
	health.take_damage(hit_pos, dmg_location)
	
func _process(delta):
	if input.fired:
		var shot_pos = gun.shoot()
		fired_shot.emit(position, shot_pos)
	
	if is_current_player():
		input.mouse_position = get_global_mouse_position()
	if multiplayer.is_server():
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

@rpc("call_local")
func _on_died():
	sprite.hide()
	vision_cone.hide()
	set_controls_enabled(false)

@rpc("call_local")
func respawn():
	sprite.show()
	if is_current_player():
		vision_cone.show()
	health.reset()
	set_controls_enabled(true)
	
func set_controls_enabled(is_enabled: bool):
	input.enabled = is_enabled

func change_color(color: Color):
	sprite.modulate = color
	
func set_visible_to(opponent_id: int):
	server_synchronizer.set_visibility_for(opponent_id, true)

func set_invisible_to(opponent_id: int):
	server_synchronizer.set_visibility_for(opponent_id, false)
	



