extends Node2D

class_name SimulatedTracer

var start: Vector2
var end: Vector2

# Called when the node enters the scene tree for the first time.
func _ready():
	$Timer.timeout.connect(queue_free)
