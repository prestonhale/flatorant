extends RefCounted

class_name Gun

var Utils = preload("res://utils.gd")

var gun_type

var cur_ammo: int
var frames_since_last_shot: int = 500
var consecutive_shots: int = 0

func simulate():
	frames_since_last_shot += 1

func can_shoot() -> bool:
	return frames_since_last_shot >= gun_type.rate_of_fire

func get_spray_angle(hash: int) -> float:
	if consecutive_shots >= gun_type.spray_pattern.size():
		var deterministic_random_mod = Utils.generate_random_from_hash(hash)
		return gun_type.spray_pattern[-1] * deterministic_random_mod
	return gun_type.spray_pattern[consecutive_shots]
