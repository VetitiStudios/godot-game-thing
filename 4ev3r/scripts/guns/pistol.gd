extends Node3D

@export var ui: Control
@export var fire_sounds: Array[AudioStream] = []

@export_group("Gun Data")
@export var fire_animation_len: float = 0.15
@export var max_ammo: int = 12
@export var type: String = "pistol"
@export var centeredX: float = 939.0
@export var centeredY: float = 541.0
@export var reloadX: float = 939.0
@export var reloadTopY: float = 541.0
@export var reloadBottomY: float = 914.0
@export var reloadTimer: float = 3.0
@export var walkXLeft: float = 859.0
@export var walkYBottom: float = 605.0
@export var walkXRight: float = 1019.0
@export var sway_time: float = 2.0
@export var damage: int = 5

var is_reloading: bool = false
var current_ammo: int = 12
var current_animation: String = "idle"

@onready var animation: AnimatedSprite2D = $Control/pistol
@onready var fire_timer: Timer = $FireTimer
@onready var shot_sound: AudioStreamPlayer = $AudioStreamPlayer 



enum SwayState { LEFT, CENTER_FROM_LEFT, RIGHT, CENTER_FROM_RIGHT }
var sway_state: SwayState = SwayState.LEFT
var sway_progress: float = 0.0

var _fire_requested: bool = false
var _reload_requested: bool = false

func _ready():
	current_ammo = max_ammo
	fire_timer.one_shot = true
	fire_timer.wait_time = fire_animation_len
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	if ui == null:
		ui = get_node_or_null("../../camPivot/camera/UI/Control")
	if ui:
		ui.gun = self

func _process(delta: float):
	animation.play(current_animation)

func _physics_process(delta: float):
	var is_moving: bool = (
		Input.is_action_pressed("forward") or
		Input.is_action_pressed("backward") or
		Input.is_action_pressed("left") or
		Input.is_action_pressed("right")
	)

	if is_moving and not is_reloading:
		var sway_speed: float = 2.0 / sway_time
		sway_progress += delta * sway_speed
		
		if sway_progress >= 1.0:
			sway_progress = 0.0
			sway_state = wrapi(sway_state + 1, 0, 4)
		
		var t: float = sway_progress
		var start_pos: Vector2
		var end_pos: Vector2
		
		match sway_state:
			SwayState.LEFT:
				start_pos = Vector2(centeredX, centeredY)
				end_pos = Vector2(walkXLeft, walkYBottom)
			SwayState.CENTER_FROM_LEFT:
				start_pos = Vector2(walkXLeft, walkYBottom)
				end_pos = Vector2(centeredX, centeredY)
			SwayState.RIGHT:
				start_pos = Vector2(centeredX, centeredY)
				end_pos = Vector2(walkXRight, walkYBottom)
			SwayState.CENTER_FROM_RIGHT:
				start_pos = Vector2(walkXRight, walkYBottom)
				end_pos = Vector2(centeredX, centeredY)
		
		var mid: Vector2 = (start_pos + end_pos) / 2.0
		var control_pos: Vector2 = mid + Vector2(0, -30)
		animation.position = _quadratic_bezier(start_pos, control_pos, end_pos, t)
	
	var _was_moving = is_moving
	
	if _fire_requested:
		_fire_requested = false
		_fire()
	
	if _reload_requested:
		_reload_requested = false
		_reload()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("fire"):
		_fire_requested = true
	if event.is_action_pressed("reload") and not is_reloading and type == "pistol":
		_reload_requested = true

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var one_minus_t: float = 1.0 - t
	var tt: float = t * t
	var omt: float = one_minus_t * one_minus_t
	return p0 * omt + p1 * 2.0 * one_minus_t * t + p2 * tt

func _fire() -> void:
	if is_reloading or current_ammo <= 0:
		current_animation = "empty"
		return

	current_animation = "fire"
	shot_sound.play()
	current_ammo -= 1
	fire_timer.start()

func _on_fire_timer_timeout():
	current_animation = "idle" if current_ammo > 0 else "empty"

func _reload() -> void:
	is_reloading = true
	current_animation = "empty"
	current_ammo = 0
	
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(animation, "position", Vector2(reloadX, reloadBottomY), reloadTimer / 2)
	await tween.finished
	current_ammo = max_ammo
	current_animation = "idle"
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(animation, "position", Vector2(reloadX, reloadTopY), reloadTimer / 2)
	await tween.finished
	
	is_reloading = false
