extends Node2D

const PORT = 4433

func _ready():
#	$ConnectToLobbyUI.host_pressed.connect(start_game)
#
#	get_tree().paused = true
#
#	multiplayer.server_relay = false
#
#	if DisplayServer.get_name() == "headless":
#		print("Automatically starting dedicated server.")
#		_on_host_pressed.call_deferred()
	
#func _on_host_pressed():
#	var peer = ENetMultiplayerPeer.new()
#	peer.create_server(PORT)
#	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
#		OS.alert("Failed to start multiplayer server.")
#		return
#	multiplayer.multiplayer_peer = peer
#	start_game()
	
#func _on_connect_pressed():
#	var text: String = $ConnectToLobbyUI/Net/Options/Remote.text
#	if text == "":
#		OS.alert("Need a remote to connect to.")
#		return
#	var peer = ENetMultiplayerPeer.new()
#	multiplayer.connected_to_server.connect(func(): print("connected"))
#	peer.create_client(text, PORT)
#	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
#		OS.alert("Failed to start multiplayer client.")
#		return 
#	multiplayer.multiplayer_peer = peer
#	start_game()
	
#func start_game():
#	print("Starting game.")
#	$ConnectToLobbyUI.hide()
#	get_tree().paused = false
#	# Only change level on the server.
#	# Clients will instantiate the level via the spawner.
#	change_level.call_deferred(load("res://levels/main_level.tscn"))

## Call this function deferred and only on the main authority (server).
#func change_level(scene: PackedScene):
#	# Remove old level if any.
#	var level = $Level
#	for c in level.get_children():
#		level.remove_child(c)
#		c.queue_free()
#	# Add new level.
#	level.add_child(scene.instantiate())

# The server can restart the level by pressing Home.
#func _input(event):
#	if not multiplayer.is_server():
#		return
#	if event.is_action("ui_home") and Input.is_action_just_pressed("ui_home"):
#		change_level.call_deferred(load("res://level.tscn"))
