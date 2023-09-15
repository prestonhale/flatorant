extends Node2D

var bullet_scn = preload("res://player/bullet/bullet.tscn")

func shoot(shot_pos: Vector2):
	var bullet = bullet_scn.instantiate()
	bullet.add_point(global_position)
	bullet.add_point(shot_pos)
	return bullet
	
