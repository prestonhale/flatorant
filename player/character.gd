extends CharacterBody2D

class_name Player

const SPEED = 400

signal fired_shot

@onready var player_input = $PlayerInput
@onready var vision_cone = $VisionCone2D
@onready var vision_cone_area = $VisionCone2D/VisionConeArea
@onready var sprite = $PlayerSprite2D
@onready var camera = $Camera2D
@onready var torso = $Torso
@onready var head = $Head
@onready var death_particles = $DeathParticles

# Times tracked by the server
# Its safe to use "frames" here as the server updates these and only ever
# ticks at 60fps
var frames_since_last_shot: int = 0
var frames_since_died: int = 0

# Presentation based, not server tracked
var dead = false

var health: int = 100

var rrotation: float

@export var player := 1 :
	set(id):
		player = id
		# You can't use "input" here because this assignment happens BEFORE 
		# "onready". You must use "$" syntax in this func
		$PlayerInput.set_multiplayer_authority(id)

var debug_draw = false

func _ready():
	# Process this script after "PlayerInput"
	process_priority = 20
	if is_current_player():
		camera.make_current()
	else:
		$VisionCone2D.hide()

func reconcile_to(player_data: Dictionary):
	set_health(player_data.health)
	position = player_data.position
	rotation = player_data.rotation
	frames_since_died = player_data.frames_since_died
	frames_since_last_shot = player_data.frames_since_last_shot

func simulate():
	if health <= 0:
		frames_since_died += 1
		if frames_since_died >= 100:
			set_health(100)
			frames_since_died = 0
	
	frames_since_last_shot += 1

func set_health(new_health: int):
	if not multiplayer.is_server() and multiplayer.get_unique_id() == player:
		print(new_health)
	health = new_health

func _process(delta):
	# Potentially trigger visual changes
	# We've died
	if not dead and health <= 0:
		death_particles.restart()
		death_particles.emitting = true
		sprite.visible = false
		torso.get_node("TorsoShape").disabled = true
		head.get_node("HeadShape").disabled = true
		
		dead = true
		
	# We're alive again!
	elif dead and health > 0:
		sprite.visible = true
		torso.get_node("TorsoShape").disabled = false
		head.get_node("HeadShape").disabled = false
		
		dead = false
	
# Called by the server when it is made aware of this player
@rpc("reliable", "call_local")
func server_acknowledge():
	player_input.server_acknowledge()

func is_current_player() -> bool:
	return player_input.get_multiplayer_authority() == multiplayer.get_unique_id()

func set_controls_enabled(is_enabled: bool):
	player_input.enabled = is_enabled

func change_color(color: Color):
	sprite.modulate = color

func can_see(other_character: Player) -> bool:
	if other_character == self:
		return true
	var cone_test = vision_cone_area.overlaps_body(other_character)
	return cone_test
