extends CharacterBody3D

@onready var collider: CollisionShape3D = $collider
@onready var cam_pivot: Node3D = $camPivot
@onready var camera: Camera3D = $camPivot/camera

@export_group("Camera Stuff")
@export_subgroup("Direct Alterations")
@export var MOUSE_SENSITIVITY: float = 0.002
@export var CAMERA_X_ROTATION: float = 0.0
@export var BASE_FOV := 90.0
@export var TARGET_FOV := 90.0
@export var FOV_LERP_SPEED := 8.0
@export var TILT_ANGLE := 0.0
@export var TARGET_TILT := 0.0
@export var TILT_SPEED := 10.0
@export var MAX_TILT := deg_to_rad(2)

@export_group("Movement Stuff")
@export_subgroup("Booleans")
@export var IS_DASHING: bool = false
@export var GROUNDED: bool = false
@export var WALL_COLLIED: bool = false
@export var IS_MOVING: bool = false
@export var IS_JUMPING: bool = false
@export var CAN_WALL_JUMP: bool = false

@export_subgroup("General Variables (gravity, friction, etc)")
@export var FRICTION: float = 5.0
@export var FRICTION_DELAY: float = 0.5
@export var GRAVITY: float = 2.5

@export_subgroup("Speed Alterations")
@export var SPEED: float = 0.0
@export var MAX_SPEED: float = 5.0
@export var ACCELERATION: float = 5.0
@export var DASH_SPEED: float = 15.0
@export var JUMP_HEIGHT: float = 5.5

@export_subgroup("Dash vars")
@export var REMAINING_DASHES: int = 3
@export var DASH_CHARGE_SPEED: float = 0.001
@export var DASH_CHARGE: float = 0.0

@export_subgroup("Wall Stuff")
@export var REMAINING_WALL_JUMPS: int = 3
@export var WALL_JUMP_ANGLE: float = 0.0
@export var WALL_JUMP_FORCE: float = 10.0

var grounded_time: float = 0.0
var air_max_speed: float = MAX_SPEED


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var ui = camera.get_node_or_null("UI/Control")
	if ui:
		ui.player = self
	else:
		print("Warning: UI/Control node not found under camera!")

	BASE_FOV = camera.fov
	TARGET_FOV = BASE_FOV


func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

		CAMERA_X_ROTATION -= event.relative.y * MOUSE_SENSITIVITY
		CAMERA_X_ROTATION = clamp(CAMERA_X_ROTATION, deg_to_rad(-80), deg_to_rad(80))
		cam_pivot.rotation.x = CAMERA_X_ROTATION

	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta):
	GROUNDED = is_on_floor()

	# Gravity
	if not GROUNDED:
		velocity.y -= GRAVITY * delta * 10.0
	elif velocity.y < 0:
		velocity.y = 0

	# Movement input
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var cam_basis = camera.global_transform.basis
	var direction = (cam_basis.z * input_dir.y + cam_basis.x * input_dir.x)
	direction.y = 0
	direction = direction.normalized()

	IS_MOVING = direction.length() > 0

	# Air movement
	if not GROUNDED:
		var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
		var speed = horizontal_velocity.length()

		if IS_MOVING and speed < air_max_speed:
			var desired_velocity = direction * air_max_speed
			var acceleration = ACCELERATION * delta

			velocity.x = lerp(velocity.x, desired_velocity.x, acceleration)
			velocity.z = lerp(velocity.z, desired_velocity.z, acceleration)

		if grounded_time > 0:
			grounded_time -= delta

	else:
		# Ground movement
		if grounded_time > FRICTION_DELAY:
			if velocity.length() > MAX_SPEED:
				velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
				velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

		if GROUNDED:
			grounded_time += delta

		if IS_MOVING:
			var target_velocity = direction * MAX_SPEED
			velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta * 10.0)
			velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta * 10.0)
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta * 6.0)
			velocity.z = move_toward(velocity.z, 0, FRICTION * delta * 6.0)

	# Jumping
	if Input.is_action_just_pressed("jump"):
		if is_on_wall_only() and REMAINING_WALL_JUMPS > 0:
			var wall_normal = get_wall_collision_normal()
			velocity.x = wall_normal.x * WALL_JUMP_FORCE
			velocity.z = wall_normal.z * WALL_JUMP_FORCE
			velocity.y = JUMP_HEIGHT * 2.5

			REMAINING_WALL_JUMPS -= 1
			IS_JUMPING = true
			grounded_time = 0.0

		elif GROUNDED:
			velocity.y = JUMP_HEIGHT
			IS_JUMPING = true
			REMAINING_WALL_JUMPS = 3
			grounded_time = 0.0

	# Dashing
	if Input.is_action_just_pressed("dash") and not IS_DASHING and REMAINING_DASHES > 0:
		start_dash(direction)
		REMAINING_DASHES -= 1
	else:
		if REMAINING_DASHES < 3:
			DASH_CHARGE += DASH_CHARGE_SPEED
			if DASH_CHARGE >= 1.0:
				REMAINING_DASHES = 3
				DASH_CHARGE = 0

	# Camera tilt
	var target_tilt = 0.0
	if IS_DASHING:
		if Input.is_action_pressed("left"):
			target_tilt = MAX_TILT
		elif Input.is_action_pressed("right"):
			target_tilt = -MAX_TILT

	TILT_ANGLE = lerp(TILT_ANGLE, target_tilt, delta * (TILT_SPEED * 1.5 if IS_DASHING else TILT_SPEED))
	camera.rotation.z = TILT_ANGLE

	# FOV smoothing
	camera.fov = lerp(camera.fov, TARGET_FOV, delta * FOV_LERP_SPEED)

	move_and_slide()


func start_dash(direction):
	if direction == Vector3.ZERO:
		direction = -camera.global_transform.basis.z.normalized()

	IS_DASHING = true

	velocity.x += direction.x * DASH_SPEED
	velocity.z += direction.z * DASH_SPEED

	var forward_dot = direction.dot(-camera.global_transform.basis.z)

	if forward_dot > 0.5:
		TARGET_FOV = BASE_FOV - 5.0
	elif forward_dot < -0.5:
		TARGET_FOV = BASE_FOV + 10.0
	else:
		TARGET_FOV = BASE_FOV + 6.0

	await get_tree().create_timer(0.2).timeout

	TARGET_FOV = BASE_FOV
	IS_DASHING = false


func get_wall_collision_normal() -> Vector3:
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision.get_normal().y < 0.1:
			return collision.get_normal()

	return Vector3.ZERO
