extends Control

var level: MainLevel

@onready var gun_name := $GunName
@onready var ammo := $Ammo

# Called when the node enters the scene tree for the first time.
func level_changed(level: MainLevel):
	level = level
	level.simulation.gun_changed.connect(_on_gun_changed)

func _on_gun_changed(gun: Gun):
	ammo.text = str(gun.cur_ammo)
	gun_name.text = gun.gun_type.name
