extends Node2D

class_name Health

@onready var small_particles = $SmallHitParticles

@export var health = 100

enum DamageLocation {
	shoulder,
	head
}

const SHOULDER_DMG = 20
const HEAD_DMG = 100

signal died

func take_damage(hit_pos: Vector2, dmg_location: DamageLocation):
	small_particles.position = to_local(hit_pos)
	small_particles.restart()
	small_particles.emitting = true
	
	match dmg_location:
		DamageLocation.shoulder:
#			small_particles.
			health -= SHOULDER_DMG
		DamageLocation.head:
#			large_particles.
			health -= HEAD_DMG
			
	if health <= 0:
		died.emit()
		health = 0
