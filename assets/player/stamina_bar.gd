extends Node2D

@export var max_width := 32.0 
@onready var bar_fill := $BarFill
@onready var player := get_parent() 

var displayed_fraction := 1.0

func _process(delta):
	var target = player.stamina / player.max_stamina
	displayed_fraction = lerp(displayed_fraction, target, 8 * delta)
	bar_fill.scale.x = clamp(displayed_fraction, 0.0, 1.0)
	modulate.a = lerp(modulate.a,  1.0 if player.stamina < player.max_stamina else 0.0, 6 * delta)
