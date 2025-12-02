extends Camera2D

var shake_amount: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0

func _ready() -> void:
	randomize()

func _process(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		
		# Random offset for shake
		var shake_offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		offset = shake_offset
		
		# Reduce shake over time
		shake_amount = lerp(shake_amount, 0.0, delta * 5.0)
	else:
		# Reset offset when shake is done
		offset = Vector2.ZERO
		shake_amount = 0.0

func shake(duration: float = 0.3, amount: float = 10.0) -> void:
	shake_timer = duration
	shake_duration = duration
	shake_amount = amount
