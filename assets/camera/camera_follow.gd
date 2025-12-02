extends Camera2D

@export var deadzone_size := Vector2(200, 140)
@export var camera_lerp_speed := 4.0

@export var look_ahead_distance := Vector2(120, 80)
@export var look_ahead_lerp := 6.0

var player: Node2D
var _look_offset := Vector2.ZERO

# Screen shake variables
var shake_amount: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var shake_offset := Vector2.ZERO

func _ready() -> void:
	player = get_node("../Player")
	randomize()

func _process(delta: float) -> void:
	# Update screen shake
	if shake_timer > 0.0:
		shake_timer -= delta
		
		# Random offset for shake
		shake_offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		
		# Reduce shake over time
		shake_amount = lerp(shake_amount, 0.0, delta * 5.0)
	else:
		# Reset offset when shake is done
		shake_offset = Vector2.ZERO
		shake_amount = 0.0

func _physics_process(delta: float) -> void:
	var p := player.global_position
	var cam := global_position

	var half := deadzone_size * 0.5

	var left   := cam.x - half.x
	var right  := cam.x + half.x
	var top    := cam.y - half.y
	var bottom := cam.y + half.y

	var target := cam

	if p.x > right:
		var excess := p.x - right
		target.x += excess
	elif p.x < left:
		var excess := p.x - left
		target.x += excess

	if p.y > bottom:
		var excess := p.y - bottom
		target.y += excess
	elif p.y < top:
		var excess := p.y - top
		target.y += excess

	var vel := Vector2.ZERO
	if player.has_method("get_velocity"):
		vel = player.get_velocity()
	elif "velocity" in player:
		vel = player.velocity
	else:
		vel = p - cam

	var desired_offset := Vector2(
		sign(vel.x) * look_ahead_distance.x,
		sign(vel.y) * look_ahead_distance.y
	)

	_look_offset = _look_offset.lerp(desired_offset, look_ahead_lerp * delta)

	target += _look_offset

	global_position = global_position.lerp(target, camera_lerp_speed * delta)
	
	# Apply shake offset (doesn't affect target position calculation)
	offset = shake_offset

func shake(duration: float = 0.3, amount: float = 10.0) -> void:
	shake_timer = duration
	shake_duration = duration
	shake_amount = amount
