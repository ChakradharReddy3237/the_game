extends Area2D

@export var player: CharacterBody2D
# Called when the node enters the scene tree for the first time.
func _on_body_entered(body: Node2D) -> void:
	if body.name == player.name:
		body.die()
	
