extends CharacterBody2D

class_name Player

const SPEED = 400

signal fired_shot

@onready var input = $PlayerInput
@onready var vision_cone = $VisionCone2D
@onready var vision_cone_area = $VisionCone2D/VisionConeArea
@onready var health = $Health
@onready var gun = $Gun
@onready var sprite = $PlayerSprite2D
@onready var camera = $Camera2D


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
#	process_priority = 10
	
	if is_current_player():
		camera.make_current()
	else:
		$VisionCone2D.hide()

func is_current_player() -> bool:
	return input.get_multiplayer_authority() == multiplayer.get_unique_id()

@rpc("call_local")
func take_hit(hit_pos: Vector2, dmg_location: Health.DamageLocation):
	health.take_damage(hit_pos, dmg_location)

# Replicates the players state
func _process(_delta):
	pass
#	rotation = rrotation

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
	
#func set_visible_to(opponent_id: int):
#	server_synchronizer.set_visibility_for(opponent_id, true)
#
#func set_invisible_to(opponent_id: int):
#	server_synchronizer.set_visibility_for(opponent_id, false)

func get_vision_cone_polygon() -> Polygon2D:
	return $VisionCone2D/VisionConeRenderer



