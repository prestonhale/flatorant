extends CharacterBody2D

@export var speed = 400
# @onready var pointer = $Pointer
@onready var ray = $Pointer/RayCast2D 
var hitspot

func _ready():
	print(ray)

@export var debug_draw = false

func get_input(delta):
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed * delta * 100
	look_at(get_global_mouse_position())
	
func _process(delta):
	pass
	
func _physics_process(delta):
	get_input(delta)
	move_and_slide()

	if Input.is_action_just_pressed("fire"):
		print("shoot")
		if ray.is_colliding():
			print("hit") 
			hitspot = ray.get_collision_point()
			print(hitspot)
			queue_redraw()
			

func _draw():
	if hitspot:
		draw_circle(to_local(hitspot), 10, Color.RED)
			

