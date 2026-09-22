extends CanvasLayer
class_name HUD

@onready var health_bar: ProgressBar = $StatsPanel/VBox/HealthRow/HealthBar
@onready var ocali_bar: ProgressBar = $StatsPanel/VBox/OcaliRow/OcaliBar


func connect_to_player(player: Player) -> void:
	player.health_changed.connect(_on_health_changed)
	player.ocali_changed.connect(_on_ocali_changed)
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	ocali_bar.max_value = player.max_ocali
	ocali_bar.value = player.ocali


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_ocali_changed(current: int, maximum: int) -> void:
	ocali_bar.max_value = maximum
	ocali_bar.value = current
