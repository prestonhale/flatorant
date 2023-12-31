extends Resource

const gun_types = {
	"pistol": {
		"rate_of_fire": 45,
		"magazine_size": 6,
		"is_large": false,
		"movement_penalty": 0.2,
		"body_damage": 25,
		"head_damage": 150,
		"spray_pattern": [
			0
		]
	},
	"rapid": {
		"rate_of_fire": 8,
		"magazine_size": 25,
		"is_large": true,
		"body_damage": 25,
		"head_damage": 150,
		"movement_penalty": 0.2,
		"spray_pattern": [
			0., 
			-0.001,
			0.01,
			0.03, 
			-0.05, 
			-0.09, 
			0.1, 
			0.12,
			-0.15, 
			-0.20,
			-0.1,
			-0.05,
			0.2 # Used to calculate random sway
		]
	}
}
