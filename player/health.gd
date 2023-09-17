extends Node2D

class_name Health

@onready var small_particles = $SmallHitParticles
@onready var large_particles = $LargeHitParticles
@onready var death_particles1 = $DeathParticles

@export var health = 100
var dead = false

enum DamageLocation {
	shoulder,
	head
}

const SHOULDER_DMG = 20
const HEAD_DMG = 100

signal died

func reset():
	health = 100
	dead = false

func take_damage(global_hit_pos: Vector2, dmg_location: DamageLocation):
	if dead: 
		return
	
	print("Took shot to: %s" % DamageLocation.keys()[dmg_location])
	match dmg_location:
		DamageLocation.shoulder:
			emit_particles(to_local(global_hit_pos), small_particles)
			health -= SHOULDER_DMG
		DamageLocation.head:
			emit_particles(to_local(global_hit_pos), large_particles)
			health -= HEAD_DMG
			
	if health <= 0:
		dead = true
		emit_particles(Vector2.ZERO, death_particles1)
		health = 0
		died.emit()
		
func emit_particles(hit_pos: Vector2, particles: CPUParticles2D):
	particles.position = hit_pos
	particles.restart()
	particles.emitting = true
