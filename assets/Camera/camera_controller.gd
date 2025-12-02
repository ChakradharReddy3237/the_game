extends Camera2D

# Band system
@export_group("Band Settings")
@export var target_path: NodePath
@export var band_width: float = 320.0
@export var band_height: float = 240.0
@export var deadzone_width: float = 40.0  # Small area in center before band changes
@export var deadzone_height: float = 30.0
@export var min_band_width: float = 60.0
@export var max_band_width: float = 4096.0
@export var min_band_height: float = 60.0
@export var max_band_height: float = 4096.0

# Smooth transitions
@export_group("Smoothing")
@export var enable_smooth_transition: bool = true
@export var transition_speed_x: float = 8.0  # Higher = faster horizontal transitions
@export var transition_speed_y: float = 6.0  # Higher = faster vertical transitions
@export var transition_ease: float = 0.2  # Ease-out strength (0-1)

# Look-ahead
@export_group("Look Ahead")
@export var enable_look_ahead: bool = true
@export var look_ahead_distance: float = 80.0
@export var look_ahead_smoothness: float = 5.0

# Speed-based zoom
@export_group("Dynamic Zoom")
@export var enable_speed_zoom: bool = true
@export var speed_zoom_threshold: float = 200.0  # Speed to start zooming out
@export var speed_zoom_amount: float = 0.15  # How much to zoom out at max speed
@export var speed_zoom_smoothness: float = 3.0

# Manual zoom
@export_group("Manual Zoom")
@export var initial_zoom: float = 0.5
@export var min_zoom: float = 0.3
@export var max_zoom: float = 2.0
@export var zoom_speed: float = 0.1
@export var enable_mouse_wheel: bool = true
@export var mouse_wheel_sensitivity: float = 0.05
@export var enable_wheel_adjust_band: bool = true
@export var band_adjust_step: float = 20.0

# Camera shake
@export_group("Camera Shake")
@export var shake_decay: float = 5.0  # How fast shake fades
@export var max_shake_offset: float = 10.0

# Level bounds
@export_group("Level Bounds")
@export var enable_bounds: bool = false
@export var bounds_left: float = -1000.0
@export var bounds_right: float = 1000.0
@export var bounds_top: float = -1000.0
@export var bounds_bottom: float = 1000.0

# Debug
@export_group("Debug")
@export var draw_debug: bool = false
@export var line_width: float = 2.0
@export var color_x: Color = Color(1.0, 0.2, 0.2, 0.85)
@export var color_y: Color = Color(0.2, 1.0, 0.2, 0.85)
@export var color_deadzone: Color = Color(1.0, 1.0, 0.0, 0.5)

# Zoom presets
@export_group("Zoom Presets")
@export var preset_1_zoom: float = 0.4  # Wide view
@export var preset_2_zoom: float = 0.6  # Normal
@export var preset_3_zoom: float = 1.0  # Close

# Internal state
var _target: Node2D
var _target_center_x: float
var _target_center_y: float
var _current_x: float
var _current_y: float
var _look_ahead_offset: Vector2
var _base_zoom: float
var _target_zoom: float
var _shake_strength: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _last_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
    enabled = true
    _base_zoom = initial_zoom
    _target_zoom = initial_zoom
    zoom = Vector2(initial_zoom, initial_zoom)
    
    if target_path != NodePath():
        _target = get_node_or_null(target_path)

    var start_pos: Vector2 = _get_target_pos()
    _target_center_x = _snapped_center(start_pos.x, band_width)
    _target_center_y = _snapped_center(start_pos.y, band_height)
    _current_x = _target_center_x
    _current_y = _target_center_y
    global_position = Vector2(_current_x, _current_y)

func _process(delta: float) -> void:
    _update_target_centers(delta)
    _update_look_ahead(delta)
    _update_speed_zoom(delta)
    _handle_manual_zoom(delta)
    _handle_zoom_presets()
    _update_camera_position(delta)
    _update_shake(delta)
    _apply_bounds()
    
    if draw_debug:
        queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        var is_wheel_up := event.button_index == MOUSE_BUTTON_WHEEL_UP
        var is_wheel_down := event.button_index == MOUSE_BUTTON_WHEEL_DOWN
        if is_wheel_up or is_wheel_down:
            var shift := Input.is_key_pressed(KEY_SHIFT)
            var ctrl := Input.is_key_pressed(KEY_CTRL)
            if enable_wheel_adjust_band and (shift or ctrl):
                var delta := (band_adjust_step if is_wheel_up else -band_adjust_step)
                var changed := false
                if shift:
                    band_width = clamp(band_width + delta, min_band_width, max_band_width)
                    changed = true
                if ctrl:
                    band_height = clamp(band_height + delta, min_band_height, max_band_height)
                    changed = true
                if changed:
                    _resnap_centers()
                return
            
            if enable_mouse_wheel:
                if is_wheel_up:
                    _target_zoom += mouse_wheel_sensitivity
                    _target_zoom = clamp(_target_zoom, min_zoom, max_zoom)
                elif is_wheel_down:
                    _target_zoom -= mouse_wheel_sensitivity
                    _target_zoom = clamp(_target_zoom, min_zoom, max_zoom)

func _handle_manual_zoom(delta: float) -> void:
    var zoom_in = Input.is_action_pressed("ui_page_up")
    var zoom_out = Input.is_action_pressed("ui_page_down")
    
    if zoom_in:
        _target_zoom += zoom_speed * delta * 5.0
    elif zoom_out:
        _target_zoom -= zoom_speed * delta * 5.0
    
    _target_zoom = clamp(_target_zoom, min_zoom, max_zoom)

func _handle_zoom_presets() -> void:
    if Input.is_action_just_pressed("ui_text_delete"):  # Key 1
        _target_zoom = preset_1_zoom
    elif Input.is_action_just_pressed("ui_end"):  # Key 2  
        _target_zoom = preset_2_zoom
    elif Input.is_action_just_pressed("ui_text_newline_blank"):  # Key 3
        _target_zoom = preset_3_zoom

func _update_target_centers(delta: float) -> void:
    var p := _get_target_pos()
    
    # Apply deadzone
    var dz_left := _target_center_x - (band_width * 0.5) + deadzone_width
    var dz_right := _target_center_x + (band_width * 0.5) - deadzone_width
    var dz_top := _target_center_y - (band_height * 0.5) + deadzone_height
    var dz_bottom := _target_center_y + (band_height * 0.5) - deadzone_height
    
    # Horizontal stepping
    var left := _target_center_x - band_width * 0.5
    var right := _target_center_x + band_width * 0.5
    if p.x > right:
        _target_center_x += band_width
    elif p.x < left:
        _target_center_x -= band_width
    
    # Vertical stepping
    var top := _target_center_y - band_height * 0.5
    var bottom := _target_center_y + band_height * 0.5
    if p.y > bottom:
        _target_center_y += band_height
    elif p.y < top:
        _target_center_y -= band_height

func _update_look_ahead(delta: float) -> void:
    if not enable_look_ahead or not _target:
        _look_ahead_offset = Vector2.ZERO
        return
    
    var velocity := _get_target_velocity()
    var direction := velocity.normalized()
    var speed := velocity.length()
    
    # Only apply look-ahead if moving significantly
    if speed > 50.0:
        var target_offset: Vector2 = direction * look_ahead_distance * min(speed / 500.0, 1.0)
        _look_ahead_offset = _look_ahead_offset.lerp(target_offset, look_ahead_smoothness * delta)
    else:
        _look_ahead_offset = _look_ahead_offset.lerp(Vector2.ZERO, look_ahead_smoothness * delta)

func _update_speed_zoom(delta: float) -> void:
    if not enable_speed_zoom:
        return
    
    var velocity := _get_target_velocity()
    var speed := velocity.length()
    
    if speed > speed_zoom_threshold:
        var speed_factor: float = min((speed - speed_zoom_threshold) / 500.0, 1.0)
        var zoom_out: float = speed_zoom_amount * speed_factor
        _base_zoom = lerp(_base_zoom, initial_zoom - zoom_out, speed_zoom_smoothness * delta)
    else:
        _base_zoom = lerp(_base_zoom, initial_zoom, speed_zoom_smoothness * delta)
    
    _base_zoom = clamp(_base_zoom, min_zoom, max_zoom)

func _update_camera_position(delta: float) -> void:
    var target_x := _target_center_x + _look_ahead_offset.x
    var target_y := _target_center_y + _look_ahead_offset.y
    
    if enable_smooth_transition:
        # Ease-out interpolation
        var dx := target_x - _current_x
        var dy := target_y - _current_y
        _current_x += dx * transition_speed_x * delta
        _current_y += dy * transition_speed_y * delta
    else:
        _current_x = target_x
        _current_y = target_y
    
    # Apply shake
    global_position = Vector2(_current_x, _current_y) + _shake_offset
    
    # Smooth zoom transition
    var final_zoom := _base_zoom if not enable_speed_zoom else _base_zoom
    final_zoom = lerp(zoom.x, _target_zoom, 5.0 * delta)
    zoom = Vector2(final_zoom, final_zoom)

func _update_shake(delta: float) -> void:
    if _shake_strength > 0:
        _shake_strength = max(_shake_strength - shake_decay * delta, 0)
        _shake_offset = Vector2(
            randf_range(-1, 1) * _shake_strength,
            randf_range(-1, 1) * _shake_strength
        )
    else:
        _shake_offset = Vector2.ZERO

func _apply_bounds() -> void:
    if not enable_bounds:
        return
    
    var vr := get_viewport_rect()
    var half_w := (vr.size.x * 0.5) / zoom.x
    var half_h := (vr.size.y * 0.5) / zoom.y
    
    global_position.x = clamp(global_position.x, bounds_left + half_w, bounds_right - half_w)
    global_position.y = clamp(global_position.y, bounds_top + half_h, bounds_bottom - half_h)

func _get_target_pos() -> Vector2:
    if _target:
        return _target.global_position
    return global_position

func _get_target_velocity() -> Vector2:
    if _target and _target is CharacterBody2D:
        return (_target as CharacterBody2D).velocity
    elif _target:
        var current_vel := (_target.global_position - _last_velocity) / get_process_delta_time()
        _last_velocity = _target.global_position
        return current_vel
    return Vector2.ZERO

func _snapped_center(value: float, size: float) -> float:
    return floor(value / size) * size + size * 0.5

func _resnap_centers() -> void:
    # When band sizes change, resnap to the new band grid around the target
    var p := _get_target_pos()
    _target_center_x = _snapped_center(p.x, band_width)
    _target_center_y = _snapped_center(p.y, band_height)

# Public API for camera shake
func shake(strength: float) -> void:
    _shake_strength = min(strength, max_shake_offset)

# Public API to set zoom preset
func set_zoom_preset(preset: int) -> void:
    match preset:
        1: _target_zoom = preset_1_zoom
        2: _target_zoom = preset_2_zoom
        3: _target_zoom = preset_3_zoom

func _draw() -> void:
    if not draw_debug:
        return

    var vr := get_viewport_rect()
    var half_w := (vr.size.x * 0.5) / zoom.x
    var half_h := (vr.size.y * 0.5) / zoom.y

    var x1 := _target_center_x - band_width * 0.5
    var x2 := _target_center_x + band_width * 0.5
    var y1 := _target_center_y - band_height * 0.5
    var y2 := _target_center_y + band_height * 0.5
    
    # Deadzone boundaries
    var dz_left := _target_center_x - (band_width * 0.5) + deadzone_width
    var dz_right := _target_center_x + (band_width * 0.5) - deadzone_width
    var dz_top := _target_center_y - (band_height * 0.5) + deadzone_height
    var dz_bottom := _target_center_y + (band_height * 0.5) - deadzone_height

    # Vertical boundary lines (left/right)
    var v1_a := to_local(Vector2(x1, _target_center_y - half_h))
    var v1_b := to_local(Vector2(x1, _target_center_y + half_h))
    var v2_a := to_local(Vector2(x2, _target_center_y - half_h))
    var v2_b := to_local(Vector2(x2, _target_center_y + half_h))
    draw_line(v1_a, v1_b, color_x, line_width, true)
    draw_line(v2_a, v2_b, color_x, line_width, true)

    # Horizontal boundary lines (top/bottom)
    var h1_a := to_local(Vector2(_target_center_x - half_w, y1))
    var h1_b := to_local(Vector2(_target_center_x + half_w, y1))
    var h2_a := to_local(Vector2(_target_center_x - half_w, y2))
    var h2_b := to_local(Vector2(_target_center_x + half_w, y2))
    draw_line(h1_a, h1_b, color_y, line_width, true)
    draw_line(h2_a, h2_b, color_y, line_width, true)
    
    # Deadzone lines
    var dz_v1_a := to_local(Vector2(dz_left, _target_center_y - half_h))
    var dz_v1_b := to_local(Vector2(dz_left, _target_center_y + half_h))
    var dz_v2_a := to_local(Vector2(dz_right, _target_center_y - half_h))
    var dz_v2_b := to_local(Vector2(dz_right, _target_center_y + half_h))
    draw_line(dz_v1_a, dz_v1_b, color_deadzone, line_width * 0.5, true)
    draw_line(dz_v2_a, dz_v2_b, color_deadzone, line_width * 0.5, true)
    
    var dz_h1_a := to_local(Vector2(_target_center_x - half_w, dz_top))
    var dz_h1_b := to_local(Vector2(_target_center_x + half_w, dz_top))
    var dz_h2_a := to_local(Vector2(_target_center_x - half_w, dz_bottom))
    var dz_h2_b := to_local(Vector2(_target_center_x + half_w, dz_bottom))
    draw_line(dz_h1_a, dz_h1_b, color_deadzone, line_width * 0.5, true)
    draw_line(dz_h2_a, dz_h2_b, color_deadzone, line_width * 0.5, true)
