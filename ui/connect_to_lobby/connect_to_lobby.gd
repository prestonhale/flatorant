extends Control

signal host_pressed

func _ready():
	$Net/Options/Connect.pressed.connect(_on_connect_pressed)
	$Net/Options/Host.pressed.connect(_on_host_pressed)

func _on_connect_pressed():
	var text: String = $Net/Options/Remote.text
	if text == "":
		OS.alert("Need a remote to connect to.")
		return
	MultiplayerLobby.join_game(text)
	hide()

func _on_host_pressed():
	MultiplayerLobby.create_game()
	hide()
	
