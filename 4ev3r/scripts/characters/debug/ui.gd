extends Control

@onready var label: Label = $label

var player: CharacterBody3D = null
var gun: Node3D = null
var _frame_counter: int = 0
var _last_fps: int = 0

func _process(delta: float):
	_frame_counter += 1
	if _frame_counter < 30:
		return
	_frame_counter = 0
	
	if player == null:
		label.text = "player is null"
		return
	if gun == null:
		label.text = "gun is null"
		return
	
	_last_fps = Engine.get_frames_per_second()
	
	var speed: float = player.SPEED
	var dash: int = player.REMAINING_DASHES
	var dash_charge: float = player.DASH_CHARGE * 100
	var wall_jumps: int = player.REMAINING_WALL_JUMPS
	var current_ammo: int = gun.current_ammo
	var max_ammo: int = gun.max_ammo
	
	label.text = "Speed: %.1f\nFPS: %d\nDASH: %d\nDASH CHARGE: %.0f / 100\nWall Jumps: %d\nAmmo: %d : %d" % [speed, _last_fps, dash, dash_charge, wall_jumps, current_ammo, max_ammo]
