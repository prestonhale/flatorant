extends Node

class_name Utils

static func generate_random_from_hash(data) -> float:
	var hash_value = hash(data)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash_value
	return rng.randf_range(-1, 1)
