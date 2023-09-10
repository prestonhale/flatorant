extends CharacterBody2D

@export var speed = 400
# @onready var pointer = $Pointer
@onready var ray = $Pointer/RayCast2D 
var hitspot
signal hit_something 

func _ready():
	print(ray)

@export var debug_draw = false

func get_input(delta):
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed * delta * 100
	look_at(get_global_mouse_position())
	
func _physics_process(delta):
	get_input(delta)
	move_and_slide()

	if Input.is_action_just_pressed("fire"):
		if ray.is_colliding():
			hitspot = ray.get_collision_point()
			hit_something.emit()




