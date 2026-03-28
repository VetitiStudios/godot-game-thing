extends Node3D

@onready var FIRE_TIMER: Timer
@onready var CURRENT_GUN = {}
@export var ui: Control
@export var fire_sounds: Array[AudioStream] = []

var fire_button_held: bool = false
var is_firing: bool = false
var is_reloading: bool = false
var moving: bool = false

enum SwayState { LEFT, CENTER_FROM_LEFT, RIGHT, CENTER_FROM_RIGHT }
var sway_state: SwayState = SwayState.LEFT
var sway_progress: float = 0.0
var sway_speed: float = 1.0

func _ready():
	var PISTOL = load_json("res://4ev3r/gundata/pistol.json")
	PISTOL["current_ammo"] = PISTOL["max_ammo"]
	PISTOL["animation"] = $Control/pistol
	CURRENT_GUN = PISTOL
	CURRENT_GUN["current_animation"] = "idle"

	FIRE_TIMER = Timer.new()
	FIRE_TIMER.one_shot = true
	add_child(FIRE_TIMER)

	if ui:
		ui.Gun = self

func _input(event):
	moving = (
		Input.is_action_pressed("forward") or
		Input.is_action_pressed("backward") or
		Input.is_action_pressed("left") or
		Input.is_action_pressed("right")
	)

	if Input.is_action_just_pressed("fire"):
		fire_button_held = true
		_start_fire()
	elif Input.is_action_just_released("fire"):
		fire_button_held = false

	if Input.is_action_just_pressed("reload") and not is_reloading:
		if CURRENT_GUN["type"] == "pistol":
			is_reloading = true
			_pistol_reload()


func _process(delta):
	CURRENT_GUN["animation"].play(CURRENT_GUN["current_animation"])
	
	var sprite: AnimatedSprite2D = CURRENT_GUN["animation"]
	
	if moving and not is_reloading:
		# sway_time = duration for full left-to-right (2 legs: left->center->right)
		sway_speed = 2.0 / CURRENT_GUN["sway_time"]
		sway_progress += delta * sway_speed
		
		if sway_progress >= 1.0:
			sway_progress = 0.0
			# Advance to next state
			match sway_state:
				SwayState.LEFT:
					sway_state = SwayState.CENTER_FROM_LEFT
				SwayState.CENTER_FROM_LEFT:
					sway_state = SwayState.RIGHT
				SwayState.RIGHT:
					sway_state = SwayState.CENTER_FROM_RIGHT
				SwayState.CENTER_FROM_RIGHT:
					sway_state = SwayState.LEFT
		
		# Get start, end, and control points for quadratic Bezier arc
		var start_pos: Vector2
		var end_pos: Vector2
		var control_pos: Vector2
		
		match sway_state:
			SwayState.LEFT:
				# Arc from center up to left
				start_pos = Vector2(CURRENT_GUN["centeredX"], CURRENT_GUN["centeredY"])
				end_pos = Vector2(CURRENT_GUN["walkXLeft"], CURRENT_GUN["walkYBottom"])
				var mid = (start_pos + end_pos) / 2.0
				control_pos = mid + Vector2(0, -30)  # <-- NEGATIVE for upward arc
			SwayState.CENTER_FROM_LEFT:
				# Arc from left back up to center
				start_pos = Vector2(CURRENT_GUN["walkXLeft"], CURRENT_GUN["walkYBottom"])
				end_pos = Vector2(CURRENT_GUN["centeredX"], CURRENT_GUN["centeredY"])
				var mid = (start_pos + end_pos) / 2.0
				control_pos = mid + Vector2(0, -30)  # <-- NEGATIVE for upward arc
			SwayState.RIGHT:
				# Arc from center up to right
				start_pos = Vector2(CURRENT_GUN["centeredX"], CURRENT_GUN["centeredY"])
				end_pos = Vector2(CURRENT_GUN["walkXRight"], CURRENT_GUN["walkYBottom"])
				var mid = (start_pos + end_pos) / 2.0
				control_pos = mid + Vector2(0, -30)  # <-- NEGATIVE for upward arc
			SwayState.CENTER_FROM_RIGHT:
				# Arc from right back up to center
				start_pos = Vector2(CURRENT_GUN["walkXRight"], CURRENT_GUN["walkYBottom"])
				end_pos = Vector2(CURRENT_GUN["centeredX"], CURRENT_GUN["centeredY"])
				var mid = (start_pos + end_pos) / 2.0
				control_pos = mid + Vector2(0, -30)  # <-- NEGATIVE for upward arc
		
		# Linear progress - no ease() so it doesn't slow down at waypoints
		var t = sway_progress  # <-- REMOVED ease(), now linear
		sprite.position = _quadratic_bezier(start_pos, control_pos, end_pos, t)
		
	# When not moving, do nothing - gun stays exactly where it is


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	# Quadratic Bezier: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
	var one_minus_t = 1.0 - t
	return (p0 * one_minus_t * one_minus_t) + (p1 * 2.0 * one_minus_t * t) + (p2 * t * t)


func _start_fire() -> void:
	if is_reloading:
		return
	if CURRENT_GUN["current_ammo"] <= 0:
		CURRENT_GUN["current_animation"] = "empty"
		return
	if not is_firing:
		is_firing = true
		_fire_loop()


func _fire_loop() -> void:
	if CURRENT_GUN["current_ammo"] <= 0:
		CURRENT_GUN["current_animation"] = "empty"
		is_firing = false
		return

	CURRENT_GUN["current_animation"] = "fire"
	CURRENT_GUN["current_ammo"] -= 1

	FIRE_TIMER.wait_time = CURRENT_GUN["fire_animation_len"]
	FIRE_TIMER.start()

	await FIRE_TIMER.timeout

	CURRENT_GUN["current_animation"] = (
		"idle" if CURRENT_GUN["current_ammo"] > 0 else "empty"
	)

	if fire_button_held and CURRENT_GUN["current_ammo"] > 0:
		_fire_loop()
	else:
		is_firing = false


func _pistol_reload() -> void:
	var sprite: AnimatedSprite2D = $Control/pistol

	CURRENT_GUN["current_animation"] = "empty"
	CURRENT_GUN["current_ammo"] = 0

	var t := create_tween()
	t.set_ease(Tween.EASE_IN)
	t.tween_property(
		sprite,
		"position",
		Vector2(CURRENT_GUN["reloadX"], CURRENT_GUN["reloadBottomY"]),
		CURRENT_GUN["reloadTimer"] / 2
	)
	await t.finished

	CURRENT_GUN["current_ammo"] = CURRENT_GUN["max_ammo"]
	CURRENT_GUN["current_animation"] = "idle"

	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(
		sprite,
		"position",
		Vector2(CURRENT_GUN["reloadX"], CURRENT_GUN["reloadTopY"]),
		CURRENT_GUN["reloadTimer"] / 2
	)
	await t.finished

	is_reloading = false


func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)
