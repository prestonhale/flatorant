extends Node2D

@export var health = 100

enum DamageLocation {
	shoulder,
	head
}

const SHOULDER_DMG = 20
const HEAD_DMG = 100

signal died

func take_damage(dmg_location: DamageLocation):
	match dmg_location:
		DamageLocation.shoulder:
			small_particles.
			health -= SHOULDER_DMG
		DamageLocation.head:
			large_particles.
			health -= HEAD_DMG
			
	if health <= 0:
		died.emit()
		health = 0
	
