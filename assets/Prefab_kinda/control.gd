extends Control
@onready var play_button: Button = $VBoxContainer/Play_button

func _ready() -> void:
	play_button.grab_focus()


func _on_play_button_button_down() -> void:
	get_tree().change_scene_to_file("res://Scenes/testing_scene.tscn")

func _on_quit_button_down() -> void:
	get_tree().quit()
	
