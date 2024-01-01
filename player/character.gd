extends CharacterBody2D

class_name Player

# Configs
@export var PLAYER_VISION_LIMIT = 320

signal resurrected

@onready var player_input = $PlayerInput
@onready var vision_cone = $VisionCone2D
@onready var vision_cone_area = $VisionCone2D/VisionConeArea
@onready var sprite = $PlayerSprite2D
@onready var torso = $Torso
@onready var head = $Head
@onready var death_particles = $DeathParticles

# Config
static var INITIAL_HEALTH = 150

# The main level will give a reference to these if you are the main player
var crosshair

# Times tracked by the server
var frames_since_died: int = 0

# Presentation based, not server tracked
var dead = false

var health: int = 150

var rrotation: float

var large_gun: Gun = null
var small_gun: Gun = null
var held_tool = null

var player := 1 :
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
		$VisionCone2D.max_distance = PLAYER_VISION_LIMIT
	else:
		$VisionCone2D.hide()

func pickup_gun(gun: Gun):
	gun.cur_ammo = gun.gun_type.max_ammo
	if gun.gun_type.is_large:
		large_gun = gun
	else:
		small_gun = gun
	held_tool = gun
	# TODO: Drop current gun if holding one

func change_held(held_selection: PlayerInput.held_selection):
	match held_selection:
		PlayerInput.held_selection.LARGE_GUN:
			if large_gun:
				held_tool = large_gun
		PlayerInput.held_selection.SMALL_GUN:
			if small_gun:
				held_tool = small_gun

func reconcile_to(player_data: Dictionary):
	set_health(player_data.health)
	position = player_data.position
	rotation = player_data.rotation
	velocity = player_data.velocity
	frames_since_died = player_data.frames_since_died
	held_tool.cur_ammo = player_data.held_tool.cur_ammo
	held_tool.consecutive_shots = player_data.held_tool.consecutive_shots
	held_tool.frames_in_cur_state = player_data.held_tool.frames_in_cur_state

func simulate():
	if health <= 0:
		frames_since_died += 1
		if frames_since_died >= 100:
			set_health(INITIAL_HEALTH)
			frames_since_died = 0
			resurrected.emit(self)
	
	held_tool.simulate()

func set_health(new_health: int):
	health = new_health

func _process(delta):
	if is_current_player():
		# https://www.reddit.com/r/godot/comments/uugo9l/can_anyone_explain_how_the_look_at_function_works/
		var mouse_position = get_local_mouse_position()
		rotation = atan2(mouse_position.y, mouse_position.x) + global_rotation
			
		var crosshair_position = get_global_mouse_position()
		crosshair.global_position = crosshair_position
		
	
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

func get_crosshair_position():
	return get_global_mouse_position()
	var space_state = get_world_2d().direct_space_state
	# Ray cast a very long distance towards (and past) the mouse cursor
	var direction = (get_global_mouse_position() - position).normalized()
	var to_position = position + (direction * PLAYER_VISION_LIMIT)
	var collision_mask = 1 << 3
	var query = PhysicsRayQueryParameters2D.create(position, to_position, collision_mask)
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	else:
		return position + (direction * PLAYER_VISION_LIMIT)
	
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
