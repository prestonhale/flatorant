extends Node2D

class_name Game

# Called when the node enters the scene tree for the first time.
func _ready():
	Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
