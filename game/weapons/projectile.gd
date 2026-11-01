class_name Projectile
extends Node3D
## Proiettile fisico: vola con la sua velocità, cade con la gravità e colpisce
## la prima cosa che incontra. Se l'arma lo prevede, all'impatto esplode.
##
## A ogni tick si controlla con un raggio il tratto tra la posizione vecchia e
## quella nuova: così anche i proiettili velocissimi non attraversano i muri.
## In rete ogni partecipante simula il suo proiettile, con la stessa partenza:
## solo quello dell'host (autorevole) fa danni e rompe le strutture, gli
## altri mostrano soltanto volo, impatto ed esplosione.

## Il proiettile (o la sua esplosione) ha fatto danno a qualcosa; position è
## dove mostrare il numero del danno.
signal dealt_damage(target: HealthComponent, amount: float, killed: bool, position: Vector3)

@export var impact_scene: PackedScene
@export var explosion_scene: PackedScene

var velocity := Vector3.ZERO
var _data: WeaponData
var _source: Node
var _exclude: Array[RID] = []
var _mask := 0
var _life := 0.0
var _authoritative := true

@onready var _trail: CPUParticles3D = get_node_or_null("Trail")


## Fa partire il proiettile da start verso direction. source è chi ha sparato;
## exclude sono i corpi da ignorare; mask sono i layer che può colpire.
## Se authoritative è falso il proiettile è solo una copia visiva: niente danni.
func launch(start: Vector3, direction: Vector3, data: WeaponData, source: Node,
		exclude: Array[RID], mask: int, authoritative := true) -> void:
	_data = data
	_authoritative = authoritative
	_source = source
	_exclude = exclude
	_mask = mask
	_life = data.projectile_lifetime
	velocity = direction.normalized() * data.projectile_speed
	global_position = start
	_face_velocity()
	reset_physics_interpolation()
	# La scia parte solo ora, già nel punto giusto (vedi le scintille dei colpi).
	if _trail:
		_trail.restart()
		_trail.emitting = true


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	velocity.y -= _data.projectile_gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, _mask, _exclude)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		global_position = result.position
		_impact(result.collider, result.position, result.normal)
		return
	global_position = to
	_face_velocity()
	_life -= delta
	if _life <= 0.0:
		if _data.explosion_radius > 0.0:
			_explode(global_position)
		queue_free()


func _impact(collider: Object, point: Vector3, normal: Vector3) -> void:
	if _authoritative and _data.damage > 0.0:
		_damage(HealthComponent.of(collider), _data.damage, point, point)
	if _data.explosion_radius > 0.0:
		_explode(point + normal * 0.1)
	elif impact_scene:
		var impact: ImpactEffect = impact_scene.instantiate()
		get_tree().current_scene.add_child(impact)
		impact.place(point, normal)
	queue_free()


## Danno ad area (vedi Explosion): lo vedono tutti, lo calcola solo l'host.
func _explode(center: Vector3) -> void:
	Explosion.show(self, explosion_scene, center, _data.explosion_radius)
	if _authoritative:
		Explosion.blast(self, center, _data, _source, _mask, _exclude, dealt_damage.emit)


func _damage(health: HealthComponent, amount: float, hit_position: Vector3, number_position: Vector3) -> void:
	if health == null or not health.is_alive():
		return
	var dealt := health.take_damage(amount, _source, hit_position)
	dealt_damage.emit(health, dealt, not health.is_alive(), number_position)


func _face_velocity() -> void:
	if velocity.length() < 0.01:
		return
	var up := Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.FORWARD
	global_basis = Basis.looking_at(velocity, up)
