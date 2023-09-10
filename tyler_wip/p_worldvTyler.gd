extends Node2D
@onready var character = $character 
@onready var circle_drawer = $CircleDrawer

# Called when the node enters the scene tree for the first time.
func _ready():
	character.hit_something.connect(on_hit_something)
	
func on_hit_something():
	circle_drawer.draw_hitspot(character.hitspot)
