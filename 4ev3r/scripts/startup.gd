extends Node

func _ready():
	# call_deferred is essential to ensure the OS has finished 
	# creating the window before you try to grab it.
	call_deferred("_force_window_focus")

func _force_window_focus():
	# This is the most reliable way to force the OS window to focus in Godot 4
	get_window().grab_focus()
	
	# If you also need to focus a specific UI button inside that window:
	# var first_button = get_tree().root.find_child("MyButton", true, false)
	# if first_button:
	#     first_button.grab_focus()
