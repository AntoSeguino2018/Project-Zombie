class_name MeleeEnemy
extends Enemy
## Zombie da mischia: quando è abbastanza vicino alza le braccia per un attimo
## e poi colpisce. La preparazione è il momento per allontanarsi o spostarsi di
## lato. È il Camminatore, e la base del Bestione.

@export_group("Attacco")
@export var attack_damage := 15.0
## Distanza orizzontale (tra i centri) da cui inizia a preparare il colpo.
@export var attack_range := 1.7
## Il colpo va a segno solo se il bersaglio è ancora entro questa distanza...
@export var attack_reach := 2.3
## ...e davanti a lui, entro questo angolo (in gradi) da dove guarda.
@export var attack_arc_degrees := 70.0
## Secondi di preparazione prima del colpo.
@export var attack_windup := 0.5
## Secondi fermo dopo il colpo, prima di tornare a inseguire.
@export var attack_recovery := 0.6
## Velocità con cui il colpo spinge via il giocatore, in m/s (0 = nessuna spinta).
@export var attack_knockback := 0.0
## Angolo delle braccia a fine preparazione e nel colpo, in gradi.
@export var windup_arm_degrees := 75.0
@export var strike_arm_degrees := -25.0

var _struck := false
var _attack_tween: Tween

@onready var _arms: Node3D = $Visual/Arms


func _wants_attack(to_target: Vector3) -> bool:
	return to_target.length() <= attack_range and _height_to(_target) < 1.5


func _begin_attack() -> void:
	_struck = false
	_stop()
	# Braccia su durante la preparazione, giù di colpo, poi a riposo.
	_attack_tween = _physics_tween()
	_attack_tween.tween_property(_arms, "rotation:x", deg_to_rad(windup_arm_degrees), attack_windup) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(_arms, "rotation:x", deg_to_rad(strike_arm_degrees), 0.08)
	_attack_tween.tween_property(_arms, "rotation:x", 0.0, maxf(attack_recovery - 0.08, 0.01))


func _update_attack(delta: float) -> void:
	_stop()
	if not _struck:
		# Durante la preparazione segue il bersaglio, ma lentamente.
		if is_instance_valid(_target):
			_turn_towards(_flat(_target.global_position - global_position), turn_speed * 0.3, delta)
		if _state_time >= attack_windup:
			_struck = true
			_strike()
	elif _state_time >= attack_windup + attack_recovery:
		_end_attack()


func _interrupt_attack() -> void:
	if _attack_tween:
		_attack_tween.kill()
	_arms.rotation.x = 0.0


func _strike() -> void:
	if not is_instance_valid(_target):
		return
	var health := HealthComponent.of(_target)
	if health == null or not health.is_alive():
		return
	var to_target := _flat(_target.global_position - global_position)
	var in_arc := to_target.length() < 0.01 \
			or rad_to_deg((-global_basis.z).angle_to(to_target)) <= attack_arc_degrees
	if to_target.length() <= attack_reach and _height_to(_target) < 1.5 and in_arc:
		health.take_damage(attack_damage, self, _target.global_position + Vector3.UP)
		if attack_knockback > 0.0 and _target.has_method("apply_knockback"):
			_target.apply_knockback(to_target.normalized() * attack_knockback + Vector3.UP * 3.0)
