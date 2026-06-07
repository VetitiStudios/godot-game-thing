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
@export var reload_duration: float = 3.0
@export var walkXLeft: float = 859.0
@export var walkYBottom: float = 605.0
@export var walkXRight: float = 1019.0
@export var sway_time: float = 2.0
@export var damage: int = 5
@export var recoil_strength: float = 10.0

enum GunState { IDLE, FIRING, RELOADING }
enum SwayState { LEFT, CENTER_FROM_LEFT, RIGHT, CENTER_FROM_RIGHT }

var current_state: GunState = GunState.IDLE
var current_ammo: int = 12
var is_moving: bool = false
var was_moving: bool = false

var sway_state: SwayState = SwayState.LEFT
var sway_progress: float = 0.0

# Reload phase tracking: "down" or "up"
var reload_phase: String = "down"

# Cached bezier points for each sway state
var sway_points: Dictionary = {}

@onready var animation: AnimatedSprite2D = $Control/pistol
@onready var fire_timer: Timer = $FireTimer
@onready var shot_sound: AudioStreamPlayer = $AudioStreamPlayer
@onready var original_position: Vector2 = Vector2(centeredX, centeredY)


func _ready():
	current_ammo = max_ammo
	fire_timer.one_shot = true
	fire_timer.wait_time = fire_animation_len
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	
	if ui == null:
		ui = get_node_or_null("../../camPivot/camera/UI/Control")
	if ui:
		ui.gun = self
	
	_update_sway_cache()
	animation.position = original_position
	animation.play("idle")
	
	# Set a random starting direction for the first movement
	_start_sway_random()


func _update_sway_cache():
	sway_points = {
		SwayState.LEFT: {
			"start": Vector2(centeredX, centeredY),
			"control": Vector2((centeredX + walkXLeft) / 2, (centeredY + walkYBottom) / 2 - 30),
			"end": Vector2(walkXLeft, walkYBottom)
		},
		SwayState.CENTER_FROM_LEFT: {
			"start": Vector2(walkXLeft, walkYBottom),
			"control": Vector2((walkXLeft + centeredX) / 2, (walkYBottom + centeredY) / 2 - 30),
			"end": Vector2(centeredX, centeredY)
		},
		SwayState.RIGHT: {
			"start": Vector2(centeredX, centeredY),
			"control": Vector2((centeredX + walkXRight) / 2, (centeredY + walkYBottom) / 2 - 30),
			"end": Vector2(walkXRight, walkYBottom)
		},
		SwayState.CENTER_FROM_RIGHT: {
			"start": Vector2(walkXRight, walkYBottom),
			"control": Vector2((walkXRight + centeredX) / 2, (walkYBottom + centeredY) / 2 - 30),
			"end": Vector2(centeredX, centeredY)
		}
	}


func _process(_delta: float):
	match current_state:
		GunState.IDLE:
			_set_animation("idle" if current_ammo > 0 else "empty")
		GunState.FIRING:
			_set_animation("fire")
		GunState.RELOADING:
			# During reload, choose animation based on phase
			if reload_phase == "down":
				_set_animation("empty")
			else:  # up phase
				_set_animation("idle")


func _physics_process(delta: float):
	is_moving = (
		Input.is_action_pressed("forward") or
		Input.is_action_pressed("backward") or
		Input.is_action_pressed("left") or
		Input.is_action_pressed("right")
	)
	
	# Update sway only when moving and not reloading/firing
	if is_moving and current_state == GunState.IDLE:
		_update_sway(delta)
	# When not moving, do nothing → the gun stays exactly where it was
	# (no automatic return to center, no snap)
	
	was_moving = is_moving


func _start_sway_random():
	# Randomize starting direction (LEFT or RIGHT) and reset progress to 0.
	# Does NOT change the gun's current position — that way the gun stays where it is.
	sway_state = SwayState.LEFT if randi() % 2 == 0 else SwayState.RIGHT
	sway_progress = 0.0


func _update_sway(delta: float):
	var sway_speed: float = 2.0 / sway_time
	sway_progress += delta * sway_speed
	
	if sway_progress >= 1.0:
		sway_progress = 0.0
		sway_state = wrapi(sway_state + 1, 0, 4)
	
	var points = sway_points[sway_state]
	var t = sway_progress
	var pos = _quadratic_bezier(points["start"], points["control"], points["end"], t)
	animation.position = pos


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var omt = 1.0 - t
	var omt2 = omt * omt
	var t2 = t * t
	return p0 * omt2 + p1 * 2.0 * omt * t + p2 * t2


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("fire") and current_state != GunState.RELOADING:
		_fire()
	elif event.is_action_pressed("reload") and current_state != GunState.RELOADING and type == "pistol" and current_ammo < max_ammo:
		_reload()


func _fire():
	if current_state == GunState.FIRING or current_state == GunState.RELOADING:
		return
	
	if current_ammo <= 0:
		current_state = GunState.IDLE
		return
	
	current_state = GunState.FIRING
	current_ammo -= 1
	shot_sound.play()
	
	# Recoil effect
	var recoil_tween = create_tween()
	recoil_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	var original_pos = animation.position
	var recoil_offset = Vector2(0, recoil_strength)
	recoil_tween.tween_property(animation, "position", original_pos + recoil_offset, 0.05)
	recoil_tween.tween_property(animation, "position", original_pos, 0.1)
	
	fire_timer.start()


func _on_fire_timer_timeout():
	current_state = GunState.IDLE


func _reload():
	current_state = GunState.RELOADING
	reload_phase = "down"  # Start in down phase (empty animation)
	
	var was_moving_before_reload = is_moving
	is_moving = false
	
	var tween = create_tween()
	tween.set_parallel(false)
	
	# Move down
	tween.tween_property(animation, "position", Vector2(reloadX, reloadBottomY), reload_duration / 2.0)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	# At the bottom, switch to up phase BEFORE moving up
	tween.tween_callback(_set_reload_up_phase)
	
	# Move back up
	tween.tween_property(animation, "position", Vector2(reloadX, reloadTopY), reload_duration / 2.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	await tween.finished
	
	current_ammo = max_ammo
	current_state = GunState.IDLE
	# Randomize the next sway direction after reload
	_start_sway_random()
	
	is_moving = was_moving_before_reload


func _set_reload_up_phase():
	# This runs right after the gun reaches the bottom, before moving up.
	# Change phase to "up", which will make _process play the idle animation
	reload_phase = "up"


func _set_animation(anim_name: String):
	if animation.sprite_frames.has_animation(anim_name) and animation.animation != anim_name:
		animation.play(anim_name)


func _set(property, value):
	if property in ["centeredX", "centeredY", "walkXLeft", "walkYBottom", "walkXRight", "reloadX", "reloadTopY", "reloadBottomY"]:
		_update_sway_cache()
		original_position = Vector2(centeredX, centeredY)
		if current_state == GunState.IDLE and not is_moving:
			animation.position = original_position
	return false
