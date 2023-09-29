class_name PlayerInput

enum PlayerInputType {
	DIRECTION,
	ROTATION,
	FIRE_GUN,
}

var input_type: PlayerInputType
var player: CharacterBody2D
var direction: Vector2
var rotation: float

static func create(
		player: CharacterBody2D,
		input_type: PlayerInputType,
		direction: Vector2 = Vector2.ZERO,
		rotation: float = 0.0,
	):
	var player_input = PlayerInput.new()
	player_input.player = player
	player_input.input_type = input_type
	player_input.direction = direction
	player_input.rotation = rotation
	return player_input
