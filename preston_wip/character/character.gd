extends CharacterBody2D

class_name Player

signal hit_something 

const SPEED = 400

@onready var ray = $RayCast2D 
@onready var input = $PlayerInput
@onready var vision_cone_area = $VisionCone2D/VisionConeArea
@onready var server_synchronizer = $ServerSynchronizer
@onready var health = $Health

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

func take_hit():
	health.take_damage(Health.DamageLocation.shoulder)
	
func _process(delta):
	if input.fired:
		var collision = ray.get_collider()
		if collision:
			print(collision)
			# TODO: More damage for headshot
			if collision.name == "Torso" or collision.name == "Head":
				var player = collision.owner as Player
				player.take_hit()
	
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

func get_root_parent(node):
	# Recursive function to get the root parent of a node
	if node.get_parent():
		return get_root_parent(node.get_parent())
	return node

func _cast_segment():
	var space_state = get_world_2d().get_direct_space_state()

	var segment = SegmentShape2D.new()
	segment.set_a(global_position)
	segment.set_b(global_position + Vector2(cos(rotation), sin(rotation)) * 1000)
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.set_shape(segment)
	query.set_exclude([self]) # If you want to exclude the object casting the segment
	query.collision_mask = 1 # Set the collision mask you want, or none if you want to hit anything
	
	var hits = space_state.intersect_shape(query, 32)
	return hits

func set_visible_to(opponent_id: int):
	server_synchronizer.set_visibility_for(opponent_id, true)

func set_invisible_to(opponent_id: int):
	server_synchronizer.set_visibility_for(opponent_id, false)
	



