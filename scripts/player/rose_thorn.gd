extends Area3D
class_name RoseThorn

@export var speed: float = 18.0
@export var damage: int = 25

var direction: Vector3 = Vector3.FORWARD
var _distance_traveled: float = 0.0
var _max_distance: float = 30.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = false


func _physics_process(delta: float) -> void:
	var move := direction * speed * delta
	global_position += move
	_distance_traveled += move.length()
	if _distance_traveled >= _max_distance:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
