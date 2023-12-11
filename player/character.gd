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

var health: int = 100
var dead: bool = false

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

func _process(delta):
	# We've died
	if health <= 0 and not dead:
		death_particles.restart()
		death_particles.emitting = true
		sprite.visible = false
		torso.get_node("TorsoShape").disabled = true
		head.get_node("HeadShape").disabled = true
		dead = true
	
	# We're alive again!
	elif health >= 100 and dead:
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
