extends Node2D
@onready var character = $character 
@onready var debug_drawer = $DebugDrawer

# Called when the node enters the scene tree for the first time.
func _ready():
	character.hit_something.connect(on_hit_something)
	
func on_hit_something():
	debug_drawer.draw_hit(character.hitspot, character.global_position)
