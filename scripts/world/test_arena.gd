extends Node3D

const BasicEnemyScene := preload("res://scenes/enemies/BasicEnemy.tscn")

@onready var player: Player = $PlayerSpawn/Player
@onready var hud: HUD = $HUD

const RESPAWN_DELAY: float = 4.0
const SPAWN_POSITIONS: Array = [
	Vector3(-4, 0, -6), Vector3(0, 0, -6), Vector3(4, 0, -6),
	Vector3(-8, 0, -10), Vector3(8, 0, -10), Vector3(0, 0, -14),
]


func _ready() -> void:
	hud.connect_to_player(player)
	for child in get_children():
		if child is BasicEnemy:
			child.died.connect(_on_enemy_died)


func _on_enemy_died(xp: int) -> void:
	hud.increment_kills()
	player.add_xp(xp)
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	_spawn_enemy()


func _spawn_enemy() -> void:
	var enemy: BasicEnemy = BasicEnemyScene.instantiate()
	add_child(enemy)
	enemy.global_position = SPAWN_POSITIONS[randi() % SPAWN_POSITIONS.size()]
	enemy.died.connect(_on_enemy_died)
