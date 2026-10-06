extends StaticBody3D
## DamageableTree — A tree that can be damaged and felled.
## When health reaches 0 the tree tips over (tween), becomes a log on the ground.
## Add this as the root of any tree you want to be damageable.
##
## USAGE: Place a DamageableTree node in the scene. Add tree mesh/visuals as children.
##        Set the trunk_node export to the MeshInstance3D that should tip over.

@export var max_health: int = 60         # How many HP before it falls
@export var wood_yield: int = 3          # Wood items added to log pickup
@export var trunk_node: Node3D = null    # The visual mesh to tip over on death

# Groups
const TREE_GROUP: String = "tree"
const LOG_GROUP:  String = "log"

var health: int = max_health
var _fallen: bool = false
var _pickup_layer:   CanvasLayer = null
var _pickup_label:   Label = null
var _player_nearby:  bool  = false
var _pickup_cooldown: float = 0.0

signal tree_felled(tree: Node3D)


func _ready() -> void:
	add_to_group(TREE_GROUP)
	health = max_health

	# Pickup UI (shown when fallen + player close)
	_pickup_layer = CanvasLayer.new()
	_pickup_layer.layer = 4
	add_child(_pickup_layer)
	_pickup_label = Label.new()
	_pickup_label.text = "[ E ]  Collect Wood"
	_pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pickup_label.add_theme_font_size_override("font_size", 14)
	_pickup_label.visible = false
	_pickup_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_pickup_label.position.y = -60
	_pickup_layer.add_child(_pickup_label)

	# Detection area for player proximity
	var detection := Area3D.new()
	detection.name = "DetectionArea"
	var det_shape := SphereShape3D.new()
	det_shape.radius = 2.5
	var col := CollisionShape3D.new()
	col.shape = det_shape
	detection.add_child(col)
	detection.body_entered.connect(_on_body_entered)
	detection.body_exited.connect(_on_body_exited)
	detection.collision_layer = 0
	detection.collision_mask = 2
	add_child(detection)


func _process(delta: float) -> void:
	if not _fallen:
		return
	if _pickup_cooldown > 0.0:
		_pickup_cooldown -= delta
	if _pickup_label != null:
		_pickup_label.visible = _player_nearby
	if _player_nearby and _pickup_cooldown <= 0.0 and Input.is_key_pressed(KEY_E):
		_pickup_cooldown = 0.5
		_collect_wood()


func take_damage(amount: int) -> void:
	if _fallen:
		return
	health -= amount
	health = max(health, 0)
	print("[Tree] Hit! HP = ", health, " / ", max_health)
	if health <= 0:
		_fell()


func _fell() -> void:
	if _fallen:
		return
	_fallen = true
	remove_from_group(TREE_GROUP)
	add_to_group(LOG_GROUP)
	print("[Tree] Felled! Now a log.")
	emit_signal("tree_felled", self)

	# Tip the visual over
	var tip_target: Node3D = trunk_node if trunk_node != null else self
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	# Rotate 90 degrees on Z to lay it flat
	tween.tween_property(tip_target, "rotation:z", PI / 2.0, 1.2)


func _collect_wood() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not player.has_method("add_item"):
		return
	for _i in wood_yield:
		player.add_item("wood")
	print("[Tree] Collected ", wood_yield, " wood!")
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player3D":
		_player_nearby = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player3D":
		_player_nearby = false
