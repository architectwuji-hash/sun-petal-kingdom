extends Area3D
## Gomushi's charge blast — fires straight ahead destroying enemies, trees and rocks.
## power (0–5000) scales damage, AoE radius and travel speed.
## Blasts THROUGH targets — does not stop on first hit.

const IMPACT_SCENE: PackedScene = preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/cast/vfx_fire_cast_01.tscn")

var power: float       = 0.0
var direction: Vector3 = Vector3.FORWARD

var _speed: float    = 28.0
var _lifetime: float = 6.0
var _tree_timer: float = 0.0
var _terrain: Node3D = null

@onready var _vfx: Node3D             = $VFX
@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	var t: float = clampf(power / 5000.0, 0.0, 1.0)
	_speed = lerpf(22.0, 45.0, t)

	# Scale collision sphere with power
	var sphere := _shape.shape as SphereShape3D
	if sphere:
		sphere.radius = lerpf(0.9, 4.0, t)

	# Scale VFX with power
	if _vfx:
		_vfx.scale = Vector3.ONE * lerpf(0.9, 4.0, t)

	# Grab terrain for tree damage
	var trees := get_tree().get_nodes_in_group("harvestable_trees")
	if trees.size() > 0:
		_terrain = trees[0]


func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	_lifetime -= delta
	if _lifetime <= 0.0:
		_fizzle()
		return

	global_position += direction * _speed * delta

	if direction.length_squared() > 0.001 and abs(direction.dot(Vector3.UP)) < 0.99:
		look_at(global_position + direction, Vector3.UP)

	# Periodically chop trees in the blast path
	_tree_timer -= delta
	if _tree_timer <= 0.0:
		_tree_timer = 0.08
		if is_instance_valid(_terrain) and _terrain.has_method("chop_at"):
			var reach: float = lerpf(2.0, 6.0, clampf(power / 5000.0, 0.0, 1.0))
			_terrain.chop_at(global_position, reach, self)


func _on_body_entered(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return

	# Enemies / living things
	if body.is_in_group("enemy") or body.is_in_group("animal"):
		if body.has_method("take_damage"):
			body.take_damage(int(power * 0.2))
		_spawn_impact(global_position)
		return

	# Harvestable rocks (need 400+ power to crack one hit; scales up)
	if body.is_in_group("harvestable_rocks"):
		if power >= 400.0 and body.has_method("mine_at"):
			var hits := maxi(1, int(power / 400.0))
			for _i in hits:
				body.mine_at(global_position, 6.0, self)
		_spawn_impact(global_position)
		return

	# Ground, walls, terrain → ignore silently


func _spawn_impact(pos: Vector3) -> void:
	var fx := IMPACT_SCENE.instantiate() as Node3D
	get_parent().add_child(fx)
	fx.global_position = pos
	var s: float = lerpf(0.8, 4.0, clampf(power / 5000.0, 0.0, 1.0))
	fx.scale = Vector3.ONE * s
	if "one_shot" in fx:
		fx.set("one_shot", true)
	if fx.has_method("play"):
		fx.call("play")
	get_tree().create_timer(2.0).timeout.connect(fx.queue_free)


func _fizzle() -> void:
	set_deferred("monitoring", false)
	if is_instance_valid(_vfx) and "emitting" in _vfx:
		_vfx.set("emitting", false)
	await get_tree().create_timer(0.8).timeout
	queue_free()
