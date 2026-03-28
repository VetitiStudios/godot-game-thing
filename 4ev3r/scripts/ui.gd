extends Control

@onready var label = $"label"

var player = null
var Gun = null
var last_velocity := Vector3.ZERO

func _process(delta):
	if player == null:
		return
	if Gun == null:
		return
	var speed = player.SPEED
	var accel = round((player.velocity - last_velocity).length() / delta) / 100.0
	var dash = player.REMAINING_DASHES
	var dashCharge = player.DASH_CHARGE*100
	var fps = Engine.get_frames_per_second() 

	label.text = "Speed: " + str(speed) + "\n" + "Accel: " + str(accel) + "\n" + "Wall Jumps: " + str(player.REMAINING_WALL_JUMPS) + "\n" + "FPS: " + str(fps) + "\n" + "DASH: " + str(dash) + "\n" + "DASH CHARGE: " + str(dashCharge) + " / 100" + "\n" + "Ammo: " + str(Gun.CURRENT_GUN["current_ammo"]) + " : " + str(Gun.CURRENT_GUN["max_ammo"]) + "\n" + "target tween: " + str(Gun.CURRENT_GUN["targetTweenDir"]) + "\n" + "prev tween: " + str(Gun.CURRENT_GUN["prevTweenDir"])
