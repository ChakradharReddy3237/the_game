extends CharacterBody2D

enum {
	STATE_PATROL,
	STATE_SPOT,
	STATE_CHASE,
	STATE_DYING
}

@onready var exclaim := $GFX/ExclaimSign
@onready var exclaim_tween := create_tween()

@export var patrol_speed: float = 70.0
@export var chase_speed: float = 230.0
@export var sight_distance: float = 340.0
@export var gravity: float = 2000.0
@export var flip_with_direction: bool = true
@export var chase_accel := 20.0
@export var forget_distance := 500.0
@export var los_mask := 1
@export var vertical_vision_tolerance := 40.0

var spot_time: float = 1.0
var player: Node2D = null
var direction: float = -1.0
var t: float = 0.0
var state: int = STATE_PATROL
var spot_timer: float = 0.0
var stuck_timer: float = 0.0
var last_position: Vector2 = Vector2.ZERO
var is_dead: bool = false
var death_timer: float = 0.0
var death_duration: float = 0.8
var player_in_stomp_zone: bool = false

@onready var gfx: Node2D = $GFX
@onready var head: Node2D = $GFX/Head
@onready var mid: Node2D = $GFX/Mid
@onready var butt: Node2D = $GFX/Butt
@onready var leg1: Node2D = $GFX/Leg1
@onready var leg2: Node2D = $GFX/Leg2
@onready var mouth: Node2D = $GFX/Mouth
@onready var collider: CollisionShape2D = $Collider
@onready var stomp_zone: Area2D = $StompZone

func _ready() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	hide_exclaim()
	last_position = global_position
	
	# Connect stomp zone signal
	if stomp_zone:
		stomp_zone.body_entered.connect(_on_stomp_zone_body_entered)
		stomp_zone.body_exited.connect(_on_stomp_zone_body_exited)

func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta

	# Handle death state separately
	if state == STATE_DYING:
		state_dying(delta)
		move_and_slide()
		return

	match state:
		STATE_PATROL:
			state_patrol(delta)
		STATE_SPOT:
			state_spot(delta)
		STATE_CHASE:
			state_chase(delta)

	if flip_with_direction and direction != 0.0:
		gfx.scale.x = direction

	apply_body_animation(delta)
	move_and_slide()

	# Check collisions with player - any body collision kills player (unless ant is dead)
	if not is_dead and player:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			if collision.get_collider() == player:
				# Check if player is in stomp zone and falling
				if player_in_stomp_zone:
					var player_velocity: Vector2 = Vector2.ZERO
					if player.has("velocity"):
						player_velocity = player.velocity
					# If player is falling fast enough in stomp zone, don't kill them
					if player_velocity.y >= 60:
						continue
				
				# Player touched ant body - player dies
				player.die()
				return

	# Check if ant hit a wall
	if is_on_wall():
		if state == STATE_CHASE:
			# If chasing and hit a wall, return to patrol
			state = STATE_PATROL
			hide_exclaim()
			direction *= -1.0
		else:
			# Normal patrol behavior - just turn around
			direction *= -1.0
	
	# Check if ant is stuck (not moving much) during chase
	if state == STATE_CHASE:
		var movement = (global_position - last_position).length()
		if movement < 1.0:  # Moving less than 1 pixel
			stuck_timer += delta
			if stuck_timer > 0.5:  # Stuck for more than 0.5 seconds
				state = STATE_PATROL
				hide_exclaim()
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0
	
	last_position = global_position

func state_patrol(delta: float) -> void:
	if player != null:
		var to_player = player.global_position - global_position
		var aligned_y = abs(to_player.y) < vertical_vision_tolerance

		# Check if player is in range regardless of facing direction
		if aligned_y and to_player.length() < sight_distance:
			# Update direction to face the player
			direction = sign(to_player.x)
			state = STATE_SPOT
			spot_timer = spot_time																																															
			velocity.x = 0.0
			show_exclaim()
			return


	velocity.x = lerp(velocity.x, direction * patrol_speed, 6.0 * delta)

func state_spot(delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, 12.0 * delta)
	spot_timer -= delta
	if spot_timer <= 0.0:
		state = STATE_CHASE
		hide_exclaim()



func state_chase(delta: float) -> void:
	if player == null:
		state = STATE_PATROL
		return

	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var aligned_y = abs(to_player.y) < vertical_vision_tolerance

	var params = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	params.collide_with_areas = false
	params.collision_mask = los_mask
	var hit = get_world_2d().direct_space_state.intersect_ray(params)
	var has_los = (hit.is_empty() or hit["collider"] == player)

	if (not has_los or not aligned_y) and dist > forget_distance:
		hide_exclaim()
		state = STATE_PATROL
		return

	direction = float(sign(to_player.x))
	var target_speed = direction * chase_speed
	velocity.x = lerp(velocity.x, target_speed, chase_accel * delta)

func apply_body_animation(delta: float) -> void:
	var horizontal_speed = abs(velocity.x)

	var chase_boost = 1.8 if state == STATE_CHASE else 1.0
	var spotting_slow = 0.3 if state == STATE_SPOT else 1.0

	var walk_amp = 0.20
	var run_amp = 0.57
	var walk_body_amp = 0.04
	var run_body_amp = 0.10
	var walk_phase_speed = 6.0
	var run_phase_speed = 11.0

	var pause_scale = 0.1 if state == STATE_SPOT else 1.0

	var run_blend = clamp(horizontal_speed / chase_speed, 0.0, 1.0)

	var leg_amp = lerp(walk_amp, run_amp, run_blend)
	var body_amp = lerp(walk_body_amp, run_body_amp, run_blend)
	var phase_speed = lerp(walk_phase_speed, run_phase_speed, run_blend)

	leg_amp *= chase_boost
	body_amp *= chase_boost * 0.9
	phase_speed *= chase_boost

	leg_amp *= spotting_slow
	body_amp *= spotting_slow * 0.9
	phase_speed *= spotting_slow

	var idle_blend = clamp(horizontal_speed / 40.0, 0.0, 1.0)
	leg_amp *= idle_blend
	body_amp *= idle_blend
	phase_speed *= idle_blend

	leg_amp *= pause_scale
	body_amp *= pause_scale
	phase_speed = max(phase_speed * pause_scale, 0.2)

	t += delta * phase_speed

	var ph1 = sin(t * 2.0)
	var ph2 = sin(t * 2.0 + PI)
	leg1.rotation = ph1 * leg_amp
	leg2.rotation = ph2 * leg_amp

	var sway = sin(t * 1.1)
	head.rotation = sway * body_amp
	mid.rotation = sway * -body_amp * 0.8
	butt.rotation = sway * body_amp * 0.6

	mouth.position.y = sin(t * 0.9) * (body_amp * 6.0)


func show_exclaim() -> void:
	exclaim.visible = true
	exclaim.scale = Vector2(0.0, 0.0)
	exclaim.position.y = -70
	var tw = create_tween()
	tw.tween_property(exclaim, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(exclaim, "position:y", -68.0, 0.08)

func hide_exclaim() -> void:
	var tw = create_tween()
	tw.tween_property(exclaim, "scale", Vector2(0.0, 0.0), 0.10).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(exclaim.hide)

func die_from_stomp() -> void:
	if is_dead:
		return
	
	is_dead = true
	state = STATE_DYING
	death_timer = 0.0
	velocity.x = 0.0
	
	# Disable collision so player doesn't get stuck
	if collider:
		collider.set_deferred("disabled", true)
	
	# Hide exclaim mark
	hide_exclaim()
	
	# Start death animation
	play_death_animation()

func state_dying(delta: float) -> void:
	death_timer += delta
	
	# Apply slight downward velocity
	velocity.y = min(velocity.y, 200.0)
	
	if death_timer >= death_duration:
		queue_free()

func play_death_animation() -> void:
	var death_tween = create_tween()
	death_tween.set_parallel(true)
	
	# Squash effect - compress vertically and expand horizontally
	death_tween.tween_property(gfx, "scale:y", 0.2, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	death_tween.tween_property(gfx, "scale:x", direction * 1.4, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Move gfx down slightly as it squashes
	death_tween.tween_property(gfx, "position:y", 15.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Fade out
	death_tween.tween_property(gfx, "modulate:a", 0.0, 0.5).set_delay(0.3)
	
	# Add a slight bounce for the head
	var head_tween = create_tween()
	head_tween.tween_property(head, "position:y", -5.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	head_tween.tween_property(head, "position:y", 1.0, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _on_stomp_zone_body_entered(body: Node) -> void:
	# Track when player enters stomp zone
	if body.is_in_group("player"):
		player_in_stomp_zone = true
	
	# Only trigger stomp if player is falling onto the zone
	if is_dead:
		return
	
	if not body.is_in_group("player"):
		return
	
	# Check if player is falling down
	var player_velocity: Vector2 = Vector2.ZERO
	if body.has("velocity"):
		player_velocity = body.velocity
	
	# Player must be falling with some speed
	if player_velocity.y < 60:
		return
	
	# Stomp detected! Kill the ant and bounce the player
	die_from_stomp()
	if body.has_method("bounce_from_stomp"):
		body.bounce_from_stomp()

func _on_stomp_zone_body_exited(body: Node) -> void:
	# Track when player exits stomp zone
	if body.is_in_group("player"):
		player_in_stomp_zone = false

