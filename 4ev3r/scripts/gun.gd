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
	"walkYBottom": 605.0,
	"walkXRight": 1019.0,
	"sway_time": .5,
	"targetTweenDir": "left",
	"prevTweenDir": "",
	"damage": 5,
}
@onready var FIRE_TIMER: Timer
@onready var CURRENT_GUN = PISTOL
@export var ui: Control

var sway_active: bool = false
var fire_queue: int = 0
var is_firing: bool = false
var fire_button_held: bool = false
var is_reloading: bool = false
var max_ammo:=0
var current_ammo:=0
var movekeys = ["forward","backward","left","right"]
var moving = false

func _ready():
	CURRENT_GUN["current_animation"] = "idle"
	FIRE_TIMER = Timer.new()
	FIRE_TIMER.one_shot = true
	add_child(FIRE_TIMER)
	FIRE_TIMER.timeout.connect(_on_fire_timer_timeout)
	if ui:
		ui.Gun = self
	else:
		print("Warning: UI/Control node not found under camera!")

func _input(event):
	if Input.is_action_pressed("forward") or Input.is_action_pressed("backward") or Input.is_action_pressed("left") or Input.is_action_pressed("right"):
		moving = true
	else:
		moving = false
	if Input.is_action_pressed("fire"):
		fire()
	if Input.is_action_just_pressed("reload"):
		if CURRENT_GUN["type"] == "pistol":
			is_reloading = true
			_pistol_reload()

func _process(delta):
	CURRENT_GUN["animation"].play(CURRENT_GUN["current_animation"])
	if moving and not sway_active and not is_reloading:
		sway_active = true
		_start_gun_sway()

func fire() -> void:
	if CURRENT_GUN["current_ammo"] <= 0:
		CURRENT_GUN["current_animation"] = "empty"
		return

	fire_queue += 1

	if not is_firing:
		_start_fire_animation()

func _pistol_reload() -> void:
	var _target_sprite: AnimatedSprite2D = $Control/pistol
	CURRENT_GUN["current_ammo"] = 0
	CURRENT_GUN["current_animation"] = "empty"
	var _tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(_target_sprite,"position",Vector2(PISTOL["reloadX"],PISTOL["reloadBottomY"]),PISTOL["reloadTimer"]/2)
	await _tween.finished
	_tween = create_tween()
	CURRENT_GUN["current_ammo"] = CURRENT_GUN["max_ammo"]
	CURRENT_GUN["current_animation"] = "idle"
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_target_sprite,"position",Vector2(PISTOL["reloadX"],PISTOL["reloadTopY"]),PISTOL["reloadTimer"]/2)
	await _tween.finished
	is_reloading = false

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
			# Alternate sides based on last side
			if CURRENT_GUN["prevTweenDir"] == "left":
				CURRENT_GUN["targetTweenDir"] = "right"
			elif CURRENT_GUN["prevTweenDir"] == "right":
				CURRENT_GUN["targetTweenDir"] = "left"
			else:
				CURRENT_GUN["targetTweenDir"] = ["left", "right"][randi_range(0, 1)]
		else:
			CURRENT_GUN["targetTweenDir"] = "center"

		CURRENT_GUN["prevTweenDir"] = prev_dir

	sway_active = false

func _start_fire_animation() -> void:
	if fire_queue <= 0 or CURRENT_GUN["current_ammo"] <= 0:
		return

	is_firing = true
	fire_queue -= 1

	CURRENT_GUN["current_animation"] = "fire"
	CURRENT_GUN["current_ammo"] -= 1

	FIRE_TIMER.wait_time = CURRENT_GUN["fire_animation_len"]
	FIRE_TIMER.start()

func _on_fire_timer_timeout() -> void:
	if CURRENT_GUN["current_ammo"] > 0:
		CURRENT_GUN["current_animation"] = "idle"
	else:
		CURRENT_GUN["current_animation"] = "empty"

	is_firing = false

	if fire_button_held and CURRENT_GUN["current_ammo"] > 0:
		fire_queue += 1

	if fire_queue > 0:
		_start_fire_animation()
