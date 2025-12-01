extends Control
@onready var resume_: Button = $CanvasLayer/VBoxContainer/Resume
@onready var canvas_layer: CanvasLayer = $CanvasLayer

func resume():
	canvas_layer.visible = false
	get_tree().paused = false
func pause():
	get_tree().paused = true
	canvas_layer.visible = true

func test_esc():
	if Input.is_action_just_pressed("Pause"):
		if get_tree().paused:
			resume()
		else:
			resume_.grab_focus()
			pause()

func _on_resume_button_down() -> void:
	await get_tree().create_timer(0.2).timeout
	resume()

func _on_quit_menu_button_down() -> void:
	resume() 
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _on_quit_game_button_down() -> void:
	get_tree().quit()
func _ready() -> void:
	resume_.grab_focus()
	
func _process(delta: float) -> void:
	test_esc()
