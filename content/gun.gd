extends RefCounted

class_name Gun

signal gun_changed

enum GunState {
	READY,
	RELOADING,
	RESETTING
}

var Utils = preload("res://utils.gd")

var gun_type

var cur_ammo: int
var consecutive_shots: int = 0
var state: GunState
var frames_in_cur_state: int = 0

func simulate():
	frames_in_cur_state += 1
	match state:
		GunState.RELOADING:
			if frames_in_cur_state >= gun_type.reload_time:
				cur_ammo = gun_type.max_ammo
				state = GunState.READY
				gun_changed.emit(self)
		GunState.RESETTING:
			if frames_in_cur_state >= gun_type.rate_of_fire:
				state = GunState.READY

func reload():
	if state == GunState.READY:
		frames_in_cur_state = 0
		state = GunState.RELOADING

func can_shoot() -> bool:
	return cur_ammo > 0 and state == GunState.READY

func get_spray_angle(hash: int) -> float:
	if consecutive_shots >= gun_type.spray_pattern.size():
		var deterministic_random_mod = Utils.generate_random_from_hash(hash)
		return gun_type.spray_pattern[-1] * deterministic_random_mod
	return gun_type.spray_pattern[consecutive_shots]
