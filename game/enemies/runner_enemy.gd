class_name RunnerEnemy
extends Enemy
## Scattista: zombie veloce e fragile. Si avvicina a zig-zag e, quando è a tiro,
## si accuccia un attimo e si lancia in tuffo. Se manca il bersaglio resta a
## terra stordito: è il momento per farlo fuori.

enum Lunge { WINDUP, AIR, RECOVER }

@export_group("Zig-zag")
## Quanto devia ai lati della strada, in gradi.
@export var zigzag_degrees := 35.0
## Rapidità del cambio di lato.
@export var zigzag_speed := 4.0
## Sotto questa distanza dal bersaglio smette di zigzagare e va dritto.
@export var zigzag_min_distance := 7.0

@export_group("Tuffo")
## Distanza orizzontale da cui si lancia.
@export var lunge_range := 5.0
## Secondi accucciato prima del tuffo: il segnale per schivare.
@export var lunge_windup := 0.3
## Velocità del tuffo in avanti e verso l'alto, in m/s.
@export var lunge_speed := 12.0
@export var lunge_up := 3.5
@export var lunge_damage := 10.0
## Distanza tra lui e il bersaglio entro cui il tuffo va a segno.
@export var lunge_hit_radius := 1.2
## Secondi fermo dopo un tuffo andato a segno.
@export var lunge_recovery := 0.4
## Secondi a terra stordito dopo un tuffo a vuoto.
@export var miss_stun := 0.9
## Secondi minimi tra un tuffo e l'altro.
@export var lunge_cooldown := 1.0

var _lunge := Lunge.WINDUP
var _lunge_time := 0.0
var _lunge_hit := false
var _cooldown_left := 0.0
## Ogni Scattista zigzaga con un ritmo un po' diverso.
var _zigzag_phase := randf() * TAU


func _physics_process(delta: float) -> void:
	_cooldown_left -= delta
	_zigzag_phase += zigzag_speed * delta
	super(delta)


func _chase_direction(delta: float) -> Vector3:
	var direction := _path_direction(delta)
	if global_position.distance_to(_target.global_position) < zigzag_min_distance:
		return direction
	return direction.rotated(Vector3.UP, sin(_zigzag_phase) * deg_to_rad(zigzag_degrees))


func _wants_attack(to_target: Vector3) -> bool:
	return _cooldown_left <= 0.0 and is_on_floor() and to_target.length() <= lunge_range \
			and _height_to(_target) < 1.0 and _can_see(_target, 1.0)


func _begin_attack() -> void:
	_lunge = Lunge.WINDUP
	_lunge_time = 0.0
	_lunge_hit = false
	_stop()
	# Si accuccia: il segnale che sta per saltare.
	_physics_tween().tween_property(_visual, "position:y", -0.2, lunge_windup * 0.6)


func _update_attack(delta: float) -> void:
	_lunge_time += delta
	match _lunge:
		Lunge.WINDUP:
			_stop()
			if is_instance_valid(_target):
				_turn_towards(_flat(_target.global_position - global_position), turn_speed * 2.0, delta)
			if _lunge_time >= lunge_windup:
				_jump()
		Lunge.AIR:
			if not _lunge_hit:
				_check_lunge_hit()
			if is_on_floor() and _lunge_time > 0.1:
				_land()
		Lunge.RECOVER:
			_stop()
			if _lunge_time >= lunge_recovery:
				_end_attack()


func _interrupt_attack() -> void:
	_visual.position.y = 0.0
	_cooldown_left = lunge_cooldown


func _jump() -> void:
	var direction := -global_basis.z
	if is_instance_valid(_target):
		direction = _flat(_target.global_position - global_position).normalized()
	velocity = direction * lunge_speed + Vector3.UP * lunge_up
	_visual.position.y = 0.0
	_visual.rotation.x = deg_to_rad(-60.0)
	_lunge = Lunge.AIR
	_lunge_time = 0.0


func _check_lunge_hit() -> void:
	if not is_instance_valid(_target):
		return
	var health := HealthComponent.of(_target)
	if health == null or not health.is_alive():
		return
	if center().distance_to(_target.global_position + Vector3.UP * 0.9) <= lunge_hit_radius:
		_lunge_hit = true
		health.take_damage(lunge_damage, self, _target.global_position + Vector3.UP)
		var direction := _flat(velocity).normalized()
		if _target.has_method("apply_knockback"):
			_target.apply_knockback(direction * 4.0 + Vector3.UP * 2.0)
		# Rimbalza sul bersaglio invece di attraversarlo.
		velocity.x *= -0.2
		velocity.z *= -0.2


func _land() -> void:
	_visual.rotation.x = 0.0
	_cooldown_left = lunge_cooldown
	if _lunge_hit:
		_lunge = Lunge.RECOVER
		_lunge_time = 0.0
		_stop()
	else:
		stun(miss_stun)
