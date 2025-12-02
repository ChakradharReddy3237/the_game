extends CanvasLayer

@onready var death_label: Label = $DeathLabel
@onready var restart_hint: Label = $RestartHint

func _ready() -> void:
	hide_death_screen()

func show_death_screen() -> void:
	visible = true
	print("Death screen visible set to true")
	
	# Animate death text appearing
	death_label.modulate.a = 0.0
	restart_hint.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Continue during pause
	tween.set_parallel(true)
	
	# Death label fade in and scale
	death_label.scale = Vector2(0.5, 0.5)
	tween.tween_property(death_label, "modulate:a", 1.0, 0.3).set_delay(0.2)
	tween.tween_property(death_label, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Restart hint fade in
	tween.tween_property(restart_hint, "modulate:a", 1.0, 0.3).set_delay(0.6)
	
	print("Death label alpha: ", death_label.modulate.a)
	print("Tween created and started")

func hide_death_screen() -> void:
	visible = false
