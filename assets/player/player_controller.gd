extends CharacterBody2D

const GRAVITY = 2400.0
const EXTRA_FALL_GRAVITY = 2.2
const HANG_GRAVITY = 0.15
const CUT_GRAVITY = 2.8

const MAX_SPEED = 390.0
const MAX_FALL_SPEED = 986.0
const GLIDE_VELOCITY = 110
const GLIDE_CLIP_VEL = 100

const ACCELERATION = 7200.0

const JUMP_VELOCITY = -690.0
const MIN_JUMP_VELOCITY = -500.0

const WALL_JUMP_VELOCITY = -720.0
const WALL_JUMP_PUSH = 270.0
const WALL_JUMP_CONTROL_LOCK = 0.10

const COYOTE_TIME = 0.11
const JUMP_BUFFER_TIME = 0.10
const WALL_COYOTE_TIME = 0.11

var vel = Vector2()
var axis = Vector2()

var coyote_timer = 0.0
var wall_coyote_timer = 0.0
var jump_buffer_timer = 0.0

var can_jump = false
var airborne_friction = false

var is_shielding = false

var on_wall = false
var wall_dir = 0
var last_wall_dir = 0
var wall_jump_lock = 0.0
var is_gliding = false

var sprite_color = "red"

func _physics_process(delta):
	apply_gravity(delta)
	get_input_axis()
	check_wall()
	
	if on_wall:
		$Rotatable.scale.x = -wall_dir

	if is_on_floor():
		can_jump = true
		coyote_timer = 0.0
		wall_coyote_timer = 0.0
		on_wall = false
		sprite_color = "red"
	else:
		coyote_timer += delta
		if on_wall:
			wall_coyote_timer = 0.0
		else:
			wall_coyote_timer += delta
		if coyote_timer > COYOTE_TIME:
			can_jump = false
		airborne_friction = true
		sprite_color = "blue"
	
	if Input.is_action_pressed("shield"):
		is_shielding = true

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	jump_buffer_timer -= delta

	if jump_buffer_timer > 0.0:
		if can_jump:
			do_jump()
			jump_buffer_timer = 0.0
		elif on_wall or wall_coyote_timer < WALL_COYOTE_TIME:
			do_wall_jump()
			jump_buffer_timer = 0.0

	if on_wall and vel.y > 0:
		vel.y = min(vel.y, MAX_FALL_SPEED * 0.25)

	apply_variable_jump(delta)

	wall_jump_lock = max(wall_jump_lock - delta, 0.0)

	horizontal_movement(delta)

	velocity = vel
	move_and_slide()
	vel = velocity

	apply_debug_rotation()

func get_input_axis():
	axis = Vector2(
		float(Input.is_action_pressed("right")) - float(Input.is_action_pressed("left")),
		0
	).normalized()

func check_wall():
	on_wall = false
	wall_dir = 0

	if not is_on_floor() and is_on_wall_only():
		var col = get_last_slide_collision()
		if col:
			wall_dir = sign(col.get_normal().x)
			last_wall_dir = wall_dir
			on_wall = true

func apply_gravity(delta):
	if vel.y < 0:
		if Input.is_action_pressed("jump"):
			vel.y += GRAVITY * (1.0 - HANG_GRAVITY) * delta
		else:
			vel.y += GRAVITY * delta
	else:
		var fall_speed_clip = MAX_FALL_SPEED
		if Input.is_action_pressed("jump") and vel.y > GLIDE_CLIP_VEL:
			fall_speed_clip = GLIDE_VELOCITY
			is_gliding = true
		else:
			is_gliding = false

		vel.y += GRAVITY * EXTRA_FALL_GRAVITY * delta
		vel.y = min(vel.y, fall_speed_clip)


func horizontal_movement(delta):
	if wall_jump_lock > 0:
		vel.x = move_toward(vel.x, 0, ACCELERATION * delta * 0.4)
		return

	if on_wall:
		vel.x = 0
		return

	if axis.x != 0:
		var target = axis.x * MAX_SPEED
		if sign(vel.x) != axis.x:
			vel.x = move_toward(vel.x, target, ACCELERATION * delta * 2.0)
		else:
			vel.x = move_toward(vel.x, target, ACCELERATION * delta)
		
		
		$Rotatable.scale.x = sign(axis.x)
	else:
		vel.x = move_toward(vel.x, 0, ACCELERATION * delta * 0.7)

	if airborne_friction:
		vel.x = lerp(vel.x, 0.0, 0.08)


func do_jump():
	vel.y = JUMP_VELOCITY
	can_jump = false


func do_wall_jump():
	var input_dir = sign(axis.x)
	var strong_push = WALL_JUMP_PUSH

	if input_dir != 0 and input_dir == -wall_dir:
		strong_push *= 1.45
	else:
		strong_push *= 3.0

	vel.y = WALL_JUMP_VELOCITY
	vel.x = wall_dir * strong_push
	wall_jump_lock = WALL_JUMP_CONTROL_LOCK

	if input_dir == 0:
		$Rotatable.scale.x = -sign($Rotatable.scale.x)
	else:
		$Rotatable.scale.x = -wall_dir

	

func apply_variable_jump(delta):
	if not Input.is_action_pressed("jump") and vel.y < 0:
		vel.y += GRAVITY * CUT_GRAVITY * delta
	if Input.is_action_just_released("jump") and vel.y < MIN_JUMP_VELOCITY:
		vel.y = MIN_JUMP_VELOCITY


func apply_debug_rotation():
	var t = 0.0
	if axis.x != 0 and abs(vel.x) > 0.01:
		t = -deg_to_rad(5) * axis.x
	$Rotatable.rotation = lerp($Rotatable.rotation, t, 0.7)
