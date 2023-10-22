extends Line2D

class_name SimulatedTracer

var player_id: String # Player who created this tracer
var id: String
var start: Vector2
var end: Vector2

# Called when the node enters the scene tree for the first time.
func _ready():
	# Placing this at 0,0 means that local and global position are the same for it
	global_position = Vector2.ZERO 
#	print("===")
#	print(start)
#	print(end)
	add_point(start)
	add_point(end)
	$Timer.timeout.connect(queue_free)
