extends Node2D

@onready var hit_region: Area2D = $Hit_Region

func _ready() -> void:
	hit_region.body_entered.connect(_on_hit_region_body_entered)

func _on_hit_region_body_entered(body: Node) -> void:
	if body.name == "Player":
		get_tree().reload_current_scene()
