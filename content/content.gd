extends Resource

const gun_types = {
	"pistol": {
		"name": "pistol",
		"reload_time": 60,
		"rate_of_fire": 45,
		"max_ammo": 6,
		"is_large": false,
		"movement_penalty": 0.2,
		"body_damage": 25,
		"head_damage": 150,
		"spray_pattern": [
			0
		]
	},
	"rapid": {
		"name": "rifle",
		"reload_time": 100,
		"rate_of_fire": 8,
		"max_ammo": 25,
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
