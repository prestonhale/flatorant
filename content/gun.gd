extends RefCounted

class_name Gun

var gun_type

var cur_ammo: int
var frames_since_last_shot: int = 500

func simulate():
	frames_since_last_shot += 1

func can_shoot() -> bool:
	return frames_since_last_shot >= gun_type.rate_of_fire
