extends Control
@onready var play_button: Button = $VBoxContainer/Play_button
@onready var options_button: Button = $VBoxContainer/Options
@onready var vbox_container: VBoxContainer = $VBoxContainer

var options_menu_scene = preload("res://assets/Prefab_kinda/options_menu.tscn")
var options_menu_instance: Control = null

func _ready() -> void:
	play_button.grab_focus()


func _on_play_button_button_down() -> void:
	get_tree().change_scene_to_file("res://Scenes/testing_scene.tscn")

func _on_quit_button_down() -> void:
	get_tree().quit()
	
func _on_options_pressed() -> void:
	# Hide the main menu buttons
	vbox_container.visible = false
	
	# Remove existing options menu if it exists
	if options_menu_instance:
		options_menu_instance.queue_free()
	
	# Create new options menu instance
	options_menu_instance = options_menu_scene.instantiate()
	add_child(options_menu_instance)
	
	# Connect to the tree_exiting signal to show main menu again when closed
	options_menu_instance.tree_exiting.connect(_on_options_menu_closed)

func _on_options_menu_closed() -> void:
	# Show the main menu buttons again
	vbox_container.visible = true
	play_button.grab_focus()