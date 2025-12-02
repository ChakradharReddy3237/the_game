extends Control

@onready var music_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/MusicContainer/MusicHeader/MusicToggle
@onready var music_slider: HSlider = $Panel/MarginContainer/VBoxContainer/MusicContainer/MusicSlider
@onready var sfx_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/SFXContainer/SFXHeader/SFXToggle
@onready var sfx_slider: HSlider = $Panel/MarginContainer/VBoxContainer/SFXContainer/SFXSlider
@onready var help_popup: AcceptDialog = $HelpPopup

# Since we don't have separate audio buses set up, both controls affect the Master bus
const MASTER_BUS = 0

func _ready() -> void:
	# Load saved settings
	load_audio_settings()
	
	# Connect signals
	music_toggle.toggled.connect(_on_music_toggle_toggled)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_toggle.toggled.connect(_on_sfx_toggle_toggled)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)

func load_audio_settings() -> void:
	# Load from config or use defaults
	var audio_enabled = true
	var audio_volume = 0.5
	
	# Try to load from config file
	if FileAccess.file_exists("user://settings.cfg"):
		var config = ConfigFile.new()
		var err = config.load("user://settings.cfg")
		if err == OK:
			audio_enabled = config.get_value("audio", "audio_enabled", true)
			audio_volume = config.get_value("audio", "audio_volume", 0.5)
	
	# Apply settings to both UI controls (they both control the same Master bus)
	music_toggle.button_pressed = audio_enabled
	music_slider.value = audio_volume
	sfx_toggle.button_pressed = audio_enabled
	sfx_slider.value = audio_volume
	
	# Apply to actual audio
	apply_audio_settings(audio_enabled, audio_volume)

func save_audio_settings() -> void:
	var config = ConfigFile.new()
	
	# Load existing config if it exists
	if FileAccess.file_exists("user://settings.cfg"):
		config.load("user://settings.cfg")
	
	# Save audio settings (use music toggle/slider as the source of truth)
	config.set_value("audio", "audio_enabled", music_toggle.button_pressed)
	config.set_value("audio", "audio_volume", music_slider.value)
	
	config.save("user://settings.cfg")

func apply_audio_settings(enabled: bool, volume: float) -> void:
	# Apply volume in dB and mute state to Master bus
	var db = linear_to_db(clamp(volume, 0.0001, 1.0))  # Avoid -inf dB
	AudioServer.set_bus_volume_db(MASTER_BUS, db)
	AudioServer.set_bus_mute(MASTER_BUS, not enabled)

func apply_music_settings(enabled: bool, volume: float) -> void:
	apply_audio_settings(enabled, volume)

func apply_sfx_settings(enabled: bool, volume: float) -> void:
	apply_audio_settings(enabled, volume)

func _on_music_toggle_toggled(toggled_on: bool) -> void:
	apply_music_settings(toggled_on, music_slider.value)
	save_audio_settings()

func _on_music_slider_changed(value: float) -> void:
	apply_music_settings(music_toggle.button_pressed, value)
	save_audio_settings()

func _on_sfx_toggle_toggled(toggled_on: bool) -> void:
	apply_sfx_settings(toggled_on, sfx_slider.value)
	save_audio_settings()

func _on_sfx_slider_changed(value: float) -> void:
	apply_sfx_settings(sfx_toggle.button_pressed, value)
	save_audio_settings()

func _on_help_button_pressed() -> void:
	help_popup.popup_centered()

func _on_back_button_pressed() -> void:
	queue_free()
