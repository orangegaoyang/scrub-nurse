extends Node3D
## Main scene: flow control (prep -> countdown -> surgery -> result) + environment.

@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	GameState.reset()
	# Connect player interaction (wiring expanded in later phases)
	if player.has_signal("interact_pressed"):
		player.interact_pressed.connect(_on_player_interact)


func _on_player_interact(_target: Node) -> void:
	# Handled in later phases (pickup / place / pass).
	pass
