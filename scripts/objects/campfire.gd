# Campfire — pixel-art placeholder visual.
# Replace with a real AnimatedSprite2D + spritesheet when the asset is ready.
extends Node2D

func _draw() -> void:
	# Stone ring / pit
	draw_circle(Vector2(0, 4), 7.0, Color(0.28, 0.22, 0.16))
	# Embers
	draw_circle(Vector2(0, 4), 4.5, Color(0.9, 0.35, 0.05))
	# Inner flame — orange
	draw_circle(Vector2(0, 0), 3.5, Color(1.0, 0.55, 0.0))
	# Tip flame — yellow
	draw_circle(Vector2(0, -3), 2.0, Color(1.0, 0.95, 0.2))
