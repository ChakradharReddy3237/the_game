extends CharacterBody2D

const GRAVITY = 2400.0
const EXTRA_FALL_GRAVITY = 2.2
const HANG_GRAVITY = 0.15
const CUT_GRAVITY = 2.8

const MAX_SPEED = 390.0
const MAX_FALL_SPEED = 986.0
const GLIDE_VELOCITY = 110.0
const GLIDE_CLIP_VEL = 100.0

const ACCELERATION = 7200.0

const JUMP_VELOCITY = -690.0
const MIN_JUMP_VELOCITY = -500.0

const WALL_JUMP_VELOCITY = -720.0
const WALL_JUMP_PUSH = 270.0
const WALL_JUMP_CONTROL_LOCK = 0.10

const COYOTE_TIME = 0.11
const JUMP_BUFFER_TIME = 0.10
const WALL_COYOTE_TIME = 0.11

@onready var rotatable = $Rotatable
@onready var antenna1 = $Rotatable/Antena1
@onready var antenna2 = $Rotatable/Antena2
@onready var eye1 = $Rotatable/Eye1
@onready var eye2 = $Rotatable/Eye2

# ------------------------
# MOVEMENT STATE
var vel: Vector2 = Vector2.ZERO
var axis: Vector2 = Vector2.ZERO

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

# ------------------------
# ANIMATION / AMBIENT
var anim_time = 0.0

var blink_timer = 0.0
var next_blink = 0.0
const BLINK_MIN_INTERVAL = 1.0
const BLINK_MAX_INTERVAL = 4.0
const BLINK_DURATION = 0.14 
var blink_anim_t = -1.0

var anten1_rot = 0.0
var anten2_rot = 0.0

const ANT_IDLE_FREQ = 2.0
const ANT_IDLE_AMP = 0.18
const ANT_RUN_FREQ = 8.0
const ANT_RUN_AMP = 0.35
const ANT_FALL_FREQ = 20.0
const ANT_FALL_AMP = 0.5
const ANT_JUMP_TILT = -0.28 
const ANT_WALL_TILT = 0.45 

var target_tilt = 0.0

const RUN_THRESHOLD = 20.0

func _ready():
	randomize()
	_schedule_next_blink()

func _physics_process(delta):
	get_input_axis()
	apply_gravity(delta)
	check_wall()
	handle_floor_and_coyote(delta)
	handle_jump_input(delta)
	handle_wall_slide()
	apply_variable_jump(delta)
	wall_jump_lock = max(wall_jump_lock - delta, 0.0)
	horizontal_movement(delta)

	velocity = vel
	move_and_slide()
	vel = velocity

	anim_time += delta
	update_state_and_flip()
	update_ambient(delta)
	apply_debug_rotation()

func get_input_axis():
	axis.x = float(Input.is_action_pressed("right")) - float(Input.is_action_pressed("left"))
	axis.y = 0
	if axis.length() > 1:
		axis = axis.normalized()

func check_wall():
	on_wall = false
	wall_dir = 0
	if not is_on_floor() and is_on_wall_only():
		var col = get_last_slide_collision()
		if col:
			wall_dir = int(sign(col.get_normal().x))
			last_wall_dir = wall_dir
			on_wall = true

func apply_gravity(delta):
	if vel.y < 0:
		if Input.is_action_pressed("jump"):
			vel.y += GRAVITY * (1.0 - HANG_GRAVITY) * delta
		else:
			vel.y += GRAVITY * delta
	else:
		var fall_clip = MAX_FALL_SPEED
		if Input.is_action_pressed("jump") and vel.y > GLIDE_CLIP_VEL:
			fall_clip = GLIDE_VELOCITY
			is_gliding = true
		else:
			is_gliding = false

		vel.y += GRAVITY * EXTRA_FALL_GRAVITY * delta
		vel.y = min(vel.y, fall_clip)

func handle_floor_and_coyote(delta):
	if is_on_floor():
		can_jump = true
		coyote_timer = 0.0
		wall_coyote_timer = 0.0
		on_wall = false
		airborne_friction = false
	else:
		coyote_timer += delta
		if on_wall:
			wall_coyote_timer = 0.0
		else:
			wall_coyote_timer += delta
		if coyote_timer > COYOTE_TIME:
			can_jump = false
		airborne_friction = true

func handle_jump_input(delta):
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	jump_buffer_timer -= delta

	if jump_buffer_timer > 0.0:
		if can_jump:
			_do_jump()
			jump_buffer_timer = 0.0
		elif on_wall or wall_coyote_timer < WALL_COYOTE_TIME:
			_do_wall_jump()
			jump_buffer_timer = 0.0

func handle_wall_slide():
	if on_wall and vel.y > 0:
		vel.y = min(vel.y, MAX_FALL_SPEED * 0.25)

func apply_variable_jump(delta):
	if not Input.is_action_pressed("jump") and vel.y < 0:
		vel.y += GRAVITY * CUT_GRAVITY * delta
	if Input.is_action_just_released("jump") and vel.y < MIN_JUMP_VELOCITY:
		vel.y = MIN_JUMP_VELOCITY

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
		rotatable.scale.x = sign(axis.x)
	else:
		vel.x = move_toward(vel.x, 0, ACCELERATION * delta * 0.7)

	if airborne_friction:
		vel.x = lerp(vel.x, 0.0, 0.08)

func do_jump():
	vel.y = JUMP_VELOCITY
	can_jump = false

func do_wall_jump():
	var input_dir = int(sign(axis.x))
	var push = WALL_JUMP_PUSH
	if input_dir != 0 and input_dir == -wall_dir:
		push *= 1.45
	else:
		push *= 3.0

	vel.y = WALL_JUMP_VELOCITY
	vel.x = wall_dir * push
	wall_jump_lock = WALL_JUMP_CONTROL_LOCK

	if input_dir == 0:
		rotatable.scale.x = -sign(rotatable.scale.x)
	else:
		rotatable.scale.x = -wall_dir

func update_state_and_flip():
	if on_wall:
		rotatable.scale.x = -wall_dir

func update_ambient(delta):
	update_blink(delta)
	update_antennas(delta)

func update_blink(delta):
	if blink_anim_t < 0.0:
		blink_timer += delta
		if blink_timer >= next_blink:
			blink_anim_t = 0.0
			blink_timer = 0.0
	else:
		blink_anim_t += delta
		var p = blink_anim_t / BLINK_DURATION
		if p >= 1.0:
			set_eye_scale_y(1.0)
			blink_anim_t = -1.0
			schedule_next_blink()
		else:
			if p < 0.5:
				var t = p * 2.0
				var s = lerp(1.0, 0.06, ease_out_quad(t))
				set_eye_scale_y(s)
			else:
				var t2 = (p - 0.5) * 2.0
				var s2 = lerp(0.06, 1.0, ease_in_quad(t2))
				set_eye_scale_y(s2)

func schedule_next_blink():
	next_blink = randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)
	blink_timer = 0.0

func set_eye_scale_y(val):
	if eye1:
		var sc = eye1.scale
		sc.y = val
		eye1.scale = sc
	if eye2:
		var sc2 = eye2.scale
		sc2.y = val
		eye2.scale = sc2

func update_antennas(delta):
	var state = "idle"
	if on_wall:
		state = "wall"
	elif not is_on_floor():
		if vel.y < 0:
			state = "jump"
		else:
			if is_gliding:
				state = "glide"
			else:
				state = "fall"
	elif abs(vel.x) > RUN_THRESHOLD:
		state = "run"
	else:
		state = "idle"

	var a1_target = 0.0
	var a2_target = 0.0

	match state:
		"idle":
			a1_target = sin(anim_time * ANT_IDLE_FREQ) * ANT_IDLE_AMP * 0.8
			a2_target = sin((anim_time + 0.7) * ANT_IDLE_FREQ) * ANT_IDLE_AMP * 0.9
		"run":
			a1_target = sin(anim_time * ANT_RUN_FREQ) * ANT_RUN_AMP
			a2_target = sin((anim_time + 0.4) * ANT_RUN_FREQ) * ANT_RUN_AMP * 0.9
		"jump":
			# tilt backwards with small oscillation
			a1_target = ANT_JUMP_TILT + sin(anim_time * 10.0) * 0.06
			a2_target = ANT_JUMP_TILT + sin((anim_time + 0.5) * 10.0) * 0.05
		"fall":
			# flutter while falling
			a1_target = sin(anim_time * ANT_FALL_FREQ) * ANT_FALL_AMP
			a2_target = sin((anim_time + 0.25) * ANT_FALL_FREQ) * ANT_FALL_AMP * 0.85
		"glide":
			# relaxed small swing while gliding
			a1_target = sin(anim_time * 3.0) * (ANT_IDLE_AMP * 0.6)
			a2_target = sin((anim_time + 0.6) * 3.0) * (ANT_IDLE_AMP * 0.6)
		"wall":
			var tilt = -ANT_WALL_TILT
			a1_target = tilt + sin(anim_time * 4.0) * 0.08
			a2_target = tilt + sin((anim_time + 0.3) * 4.0) * 0.06

	# smooth towards target rotations
	var smooth_speed = 12.0
	anten1_rot = lerp_angle(anten1_rot, a1_target, clamp(smooth_speed * delta, 0.0, 1.0))
	anten2_rot = lerp_angle(anten2_rot, a2_target, clamp(smooth_speed * delta, 0.0, 1.0))

	if antenna1:
		antenna1.rotation = anten1_rot
	if antenna2:
		antenna2.rotation = anten2_rot

func apply_debug_rotation():
	var t = 0.0
	if axis.x != 0 and abs(vel.x) > 0.01:
		t = -deg_to_rad(5) * axis.x
	rotatable.rotation = lerp(rotatable.rotation, t, 0.7)

func ease_in_quad(t):
	return t * t

func ease_out_quad(t):
	return t * (2.0 - t)
