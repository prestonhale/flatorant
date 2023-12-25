extends Line2D

class_name SimulatedTracer

var player_id: int # Player who created this tracer
var id: int
var start: Vector2
var end: Vector2
var remaining_time_to_live_in_frames: int = 10

# Called when the node enters the scene tree for the first time.
func _ready():
	# Placing this at 0,0 means that local and global position are the same for it
	global_position = Vector2.ZERO 
	add_point(start)
	add_point(end)

func simulate():
	remaining_time_to_live_in_frames -= 1
	if remaining_time_to_live_in_frames <= 0:
		queue_free()
