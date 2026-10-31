class_name BruteEnemy
extends MeleeEnemy
## Bestione: zombie enorme e lento. Da vicino schianta le braccia a terra; da
## lontano, se ti vede, carica in linea retta e travolge tutto quello che trova.
## Davanti è corazzato, il punto debole è il serbatoio luminoso sulla schiena.
## Troppo pesante per essere lanciato: le spinte lo stordiscono soltanto.

enum Charge { WINDUP, RUN, RECOVER }

@export_group("Corazza")
## Danno ricevuto da davanti, in frazione (0,25 = un quarto).
@export var front_armor_factor := 0.25
## Danno ricevuto sul punto debole, sulla schiena.
@export var weak_spot_factor := 2.5
## Altezza dal suolo del punto debole, in metri (da, a).
@export var weak_spot_height := Vector2(1.0, 2.0)

@export_group("Carica")
## Carica solo se il bersaglio è tra queste distanze, in metri.
@export var charge_min_distance := 6.0
@export var charge_max_distance := 15.0
## Secondi di preparazione: abbassa la testa e raspa il terreno.
@export var charge_windup := 0.8
@export var charge_speed := 14.0
## Durata massima della corsa, in secondi.
@export var charge_duration := 1.1
@export var charge_damage := 30.0
## Velocità con cui la carica scaraventa via il giocatore, in m/s.
@export var charge_knockback := 13.0
## Secondi fermo dopo la carica.
@export var charge_recovery := 0.6
## Secondi tra una carica e l'altra.
@export var charge_cooldown := 6.0
## Secondi stordito se finisce contro un muro indistruttibile.
@export var wall_stun := 1.5
## Danno ai blocchi distruttibili quando ci carica contro: li sfonda e prosegue.
@export var charge_structure_damage := 200.0

var _charging := false
var _charge := Charge.WINDUP
var _charge_time := 0.0
var _charge_direction := Vector3.FORWARD
var _charge_cooldown_left := 0.0


func _ready() -> void:
	super()
	_health.damage_filter = _armor_filter
	# La prima carica non arriva appena compare.
	_charge_cooldown_left = charge_cooldown * 0.5


func _physics_process(delta: float) -> void:
	_charge_cooldown_left -= delta
	super(delta)


func is_charging() -> bool:
	return is_attacking() and _charging and _charge == Charge.RUN


func _wants_attack(to_target: Vector3) -> bool:
	_charging = false
	if super(to_target):
		return true
	var distance := to_target.length()
	if _charge_cooldown_left <= 0.0 and distance >= charge_min_distance \
			and distance <= charge_max_distance and _height_to(_target) < 1.5 \
			and _can_see(_target, 1.8):
		_charging = true
		return true
	return false


func _begin_attack() -> void:
	if not _charging:
		super()
		return
	_charge = Charge.WINDUP
	_charge_time = 0.0
	_stop()
	# Testa bassa, pronto a partire.
	_attack_tween = _physics_tween()
	_attack_tween.tween_property(_visual, "rotation:x", deg_to_rad(-20.0), charge_windup * 0.5)


func _update_attack(delta: float) -> void:
	if not _charging:
		super(delta)
		return
	_charge_time += delta
	match _charge:
		Charge.WINDUP:
			_stop()
			if is_instance_valid(_target):
				_turn_towards(_flat(_target.global_position - global_position), turn_speed, delta)
			if _charge_time >= charge_windup:
				_charge = Charge.RUN
				_charge_time = 0.0
				_charge_direction = -global_basis.z
		Charge.RUN:
			velocity.x = _charge_direction.x * charge_speed
			velocity.z = _charge_direction.z * charge_speed
			_check_charge_hit()
			if _charge == Charge.RUN and _charge_time >= charge_duration:
				_start_charge_recovery()
		Charge.RECOVER:
			_stop()
			if _charge_time >= charge_recovery:
				_finish_charge()


func _after_move(velocity_before_move: Vector3) -> void:
	super(velocity_before_move)
	if not is_charging():
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider()
		if other is Enemy:
			# Travolge gli altri zombie spingendoli di lato.
			var away := _flat(other.global_position - global_position).normalized()
			other.apply_knockback((away + _charge_direction) * 6.0 + Vector3.UP * 4.0, 0.0, self)
		elif other is DestructibleBlocks:
			# Un muro di blocchi non lo ferma: lo sfonda e continua a correre.
			other.damage_sphere(collision.get_position(), 1.6, charge_structure_damage, charge_speed * 0.6)
		elif collision.get_normal().y < 0.5 and collision.get_normal().dot(_charge_direction) < -0.5 \
				and not other is FpsController:
			# Dritto contro un muro: resta intontito.
			_finish_charge()
			stun(wall_stun)
			return


func _interrupt_attack() -> void:
	super()
	_visual.rotation.x = 0.0
	if _charging:
		_charge_cooldown_left = charge_cooldown


func _check_charge_hit() -> void:
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		var health := HealthComponent.of(player)
		if health == null or not health.is_alive():
			continue
		var offset := player.global_position - global_position
		if _flat(offset).length() <= 1.6 and absf(offset.y) < 1.5:
			health.take_damage(charge_damage, self, player.global_position + Vector3.UP)
			if player.has_method("apply_knockback"):
				player.apply_knockback(_charge_direction * charge_knockback + Vector3.UP * 5.0)
			_start_charge_recovery()
			return


func _start_charge_recovery() -> void:
	_charge = Charge.RECOVER
	_charge_time = 0.0
	_stop()
	_physics_tween().tween_property(_visual, "rotation:x", 0.0, 0.3)


func _finish_charge() -> void:
	_charge_cooldown_left = charge_cooldown
	_charging = false
	_visual.rotation.x = 0.0
	_end_attack()


## Corazza davanti, punto debole dietro: dipende da dove arriva il colpo.
func _armor_filter(amount: float, _source: Node, hit_position: Vector3) -> float:
	if hit_position == Vector3.ZERO:
		return amount
	var local := to_local(hit_position)
	var flat := Vector2(local.x, local.z)
	if flat.length() < 0.01:
		return amount
	# Il davanti è -Z: facing va da 1 (davanti) a -1 (dietro).
	var facing := -local.z / flat.length()
	if facing > 0.5:
		return amount * front_armor_factor
	if facing < -0.5 and local.y >= weak_spot_height.x and local.y <= weak_spot_height.y:
		return amount * weak_spot_factor
	return amount
