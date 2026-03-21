extends Control

@onready var speed_label = $"Speed Label"
@onready var accel_label = $"Acceleration Label"
@onready var walljump_label = $"WallJump Label"
@onready var fps_label = $"FPS Label"
@onready var dash_label = $"Dash Label"
@onready var dash_charge_label = $"DashCharge Label"

var player = null
var last_velocity := Vector3.ZERO

func _process(delta):
	if player == null:
		return

	# --- Horizontal speed ---
	var speed = player.SPEED
	speed_label.text = "Speed: " + str(speed)

	# --- Acceleration ---
	var accel = round((player.velocity - last_velocity).length() / delta * 100) / 100.0
	accel_label.text = "Accel: " + str(accel)

	# --- Wall jumps ---
	walljump_label.text = "Wall Jumps: " + str(player.REMAINING_WALL_JUMPS)

	# --- FPS ---
	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: " + str(fps)
	
	# --- DASH ---
	var dash = player.REMAINING_DASHES
	dash_label.text = "DASH: " + str(dash)
	
	var dashCharge = player.DASH_CHARGE*100
	dash_charge_label.text = "DASH CHARGE: " + str(dashCharge) + " / 100"

	last_velocity = player.velocity
