extends Node2D

@export var enabled: bool = true

@onready var enemy_check_area: Area2D = $EnemyCheckArea

func check_empty() -> bool:
	return enemy_check_area.has_overlapping_bodies()
