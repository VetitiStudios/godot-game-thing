extends Node3D

@onready var PISTOL = {
	"animation": $Control/pistol,
	"fire_animation_len": .15,
	"current_animation": "idle",
	"current_ammo": 12,
	"max_ammo": 12,
	"type": "pistol",
	"centeredX": 939.0,
	"centeredY": 541.0,
	"reloadX": 939.0,
	"reloadTopY": 541.0,
	"reloadBottomY": 914.0,
	"reloadTimer": 3.0,
	"walkXLeft": 859.0,
	"walkYBottom": 585.0,
	"walkXRight": 1019.0,
	"sway_time": .5,
	"targetTweenDir": "left",
	"prevTweenDir": "jew",
	"damage": 5,
}
@onready var FIRE_TIMER: Timer
@onready var CURRENT_GUN = {}
@export var ui: Control
@export var fire_sounds: Array[AudioStream] = []

var sway_tween: Tween = null
var sway_active: bool = false
var fire_button_held: bool = false
var is_firing: bool = false
var is_reloading: bool = false
var moving: bool = false

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

	if moving and not sway_active and not is_reloading:
		sway_active = true
		_start_sway()


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

func _start_gun_sway() -> void:
	var _target_sprite: AnimatedSprite2D = CURRENT_GUN["animation"]

	while moving and not is_reloading:
		var target_pos: Vector2
		match CURRENT_GUN["targetTweenDir"]:
			"left":
				target_pos = Vector2(CURRENT_GUN["walkXLeft"], CURRENT_GUN["walkYBottom"])
			"right":
				target_pos = Vector2(CURRENT_GUN["walkXRight"], CURRENT_GUN["walkYBottom"])
			"center":
				target_pos = Vector2(CURRENT_GUN["centeredX"], CURRENT_GUN["centeredY"])
			_:
				target_pos = Vector2(CURRENT_GUN["centeredX"], CURRENT_GUN["centeredY"])

		var _tween = create_tween()
		_tween.set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(_target_sprite, "position", target_pos, CURRENT_GUN["sway_time"])
		await _tween.finished

		var prev_dir = CURRENT_GUN["targetTweenDir"]
		if CURRENT_GUN["targetTweenDir"] == "center":
			if CURRENT_GUN["prevTweenDir"] == "left":
				CURRENT_GUN["targetTweenDir"] = "right"
			elif CURRENT_GUN["prevTweenDir"] == "right":
				CURRENT_GUN["targetTweenDir"] = "left"
			else:
				CURRENT_GUN["targetTweenDir"] = ["left", "right"][randi_range(0, 1)]
		else:
			CURRENT_GUN["targetTweenDir"] = "center"
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


func _start_sway() -> void:
	if sway_tween and sway_tween.is_running():
		return
	sway_tween = _sway_step()


func _sway_step() -> Tween:
	var sprite: AnimatedSprite2D = CURRENT_GUN["animation"]
	var tween := create_tween()

	var target_pos = _get_sway_target()

	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", target_pos, CURRENT_GUN["sway_time"])

	tween.finished.connect(func():
		if moving and not is_reloading:
			var current = CURRENT_GUN["targetTweenDir"]
			var prev = CURRENT_GUN["prevTweenDir"]
			CURRENT_GUN["targetTweenDir"] = _next_sway_dir(current, prev)
			CURRENT_GUN["prevTweenDir"] = current
			sway_tween = _sway_step()
		else:
			sway_active = false
	)

	return tween

func _next_sway_dir(current: String, prev: String) -> String:
	match current:
		"left":
			return "center"

		"right":
			return "center"

		"center":
			# Decide based on previous sway direction
			if prev == "left":
				return "right"
			elif prev == "right":
				return "left"
			else:
				# First-time sway; pick a random side
				return ["left", "right"][randi_range(0, 1)]

		_:
			return "center"


func _get_sway_target() -> Vector2:
	match CURRENT_GUN["targetTweenDir"]:
		"left":
			return Vector2(CURRENT_GUN["walkXLeft"], CURRENT_GUN["walkYBottom"])
		"right":
			return Vector2(CURRENT_GUN["walkXRight"], CURRENT_GUN["walkYBottom"])
		_:
			return Vector2(CURRENT_GUN["centeredX"], CURRENT_GUN["centeredY"])


func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)
