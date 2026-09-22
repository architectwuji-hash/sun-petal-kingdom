extends Node3D

@onready var player: Player = $PlayerSpawn/Player
@onready var hud: HUD = $HUD


func _ready() -> void:
	hud.connect_to_player(player)
