extends CharacterBody2D

const GRAVITY             = 2400.0
const MAX_SPEED           = 400.0
const MAX_FALL_SPEED      = 720.0
const ACCELERATION        = 9400.0
const JUMP_VELOCITY       = -680.0
const MIN_JUMP_VELOCITY   = -200.0

const COYOTE_TIME         = 0.12
const JUMP_BUFFER_TIME    = 0.12

var player_vel = Vector2()
var axis = Vector2()

var coyote_timer = 0.0
var jump_buffer_timer = 0.0

var can_jump = false
var friction = false

var sprite_color = "red"

func _physics_process(delta: float):

	if player_vel.y < 0:
		player_vel.y += GRAVITY * delta
	elif player_vel.y >= 0:
		player_vel.y += GRAVITY * 1.8 * delta
		player_vel.y = min(player_vel.y, MAX_FALL_SPEED)
	
	
	friction = false
	get_input_axis()

	if is_on_floor():
		can_jump = true
		coyote_timer = 0.0
		sprite_color = "red"
	else:
		coyote_timer += delta
		if coyote_timer > COYOTE_TIME:
			can_jump = false
		friction = true

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	jump_buffer_timer -= delta
	if jump_buffer_timer > 0.0 and can_jump:
		jump()
		jump_buffer_timer = 0.0

	set_jump_height()
	horizontal_movement(delta)

	velocity = player_vel
	move_and_slide()
	player_vel = velocity

func horizontal_movement(delta: float):
	if axis.x != 0:
		player_vel.x = move_toward(player_vel.x, axis.x * MAX_SPEED, ACCELERATION * delta)
		$Rotatable.scale.x = sign(axis.x)
	else:
		player_vel.x = move_toward(player_vel.x, 0, ACCELERATION * delta * 0.4)

	if friction:
		player_vel.x = lerp(player_vel.x, 0.0, 0.001)

func jump():
	player_vel.y = JUMP_VELOCITY
	can_jump = false

func set_jump_height():
	if Input.is_action_just_released("jump"):
		if player_vel.y < MIN_JUMP_VELOCITY:
			player_vel.y = MIN_JUMP_VELOCITY

func get_input_axis():
	axis = Vector2(
		float(Input.is_action_pressed("right")) - float(Input.is_action_pressed("left")),
		float(Input.is_action_pressed("down"))  - float(Input.is_action_pressed("up"))
	)
	if axis != Vector2.ZERO:
		axis = axis.normalized()
