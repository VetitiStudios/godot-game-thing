extends CharacterBody3D

@onready var COLLIDER: CollisionShape3D = $collider
@onready var CAM_PIVOT: Node3D = $camPivot
@onready var CAMERA: Camera3D = $camPivot/camera

@export_group("Camera Stuff")
@export_subgroup("Direct Alterations")
@export var mouse_sensitivity: float = 0.002
@export var camera_x_rotation: float = 0.0
@export var base_fov := 75.0
@export var target_fov := 75.0
@export var fov_lerp_speed := 8.0
@export var tilt_angle := 0.0
@export var target_tilt := 0.0
@export var tilt_speed := 10.0
@export var max_tilt := deg_to_rad(2)

@export_group("Movement Stuff")
@export_subgroup("Booleans")
@export var IS_DASHING : bool = false
@export var GROUNDED : bool = false
@export var WALL_COLLIED : bool = false
@export var IS_MOVING : bool = false
@export var IS_JUMPING : bool = false
@export var CAN_WALL_JUMP : bool = false

@export_subgroup("General Variables (gravity, friction, etc)")
@export var FRICTION: float = 5.0
@export var FRICTION_DELAY: float = 2.5
@export var GRAVITY: float = 2.5
@export var coyote_time := 0.12
@export var coyote_timer := 0.0
@export var jump_buffer_time := 0.15
@export var jump_buffer_timer := 0.0

@export_subgroup("Speed Alterations")
@export var SPEED : float = 0.0
@export var MAX_SPEED: float = 5.0
@export var ACCELERATION: float = 5.0
@export var DASH_SPEED: float = 15.0
@export var JUMP_HEIGHT: float = 5.5

@export_subgroup("Wall Stuff")
@export var REMAINING_WALL_JUMPS: int = 3
@export var WALL_JUMP_ANGLE: float = 0.0
@export var last_wall_normal := Vector3.ZERO

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var ui = $camPivot/camera/UI/Control
	ui.player = self
	
	base_fov = CAMERA.fov
	target_fov = base_fov

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_x_rotation -= event.relative.y * mouse_sensitivity
		camera_x_rotation = clamp(camera_x_rotation, deg_to_rad(-80), deg_to_rad(80))
		CAM_PIVOT.rotation.x = camera_x_rotation

	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	GROUNDED = is_on_floor()

	if GROUNDED:
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# Apply gravity
	if not GROUNDED:
		velocity.y -= GRAVITY * delta * 10.0
	else:
		REMAINING_WALL_JUMPS = 3
		if velocity.y < 0:
			velocity.y = 0

	# Get input
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var cam_basis = CAMERA.global_transform.basis
	var direction = (cam_basis.z * input_dir.y + cam_basis.x * input_dir.x)
	direction.y = 0
	direction = direction.normalized()
	IS_MOVING = direction.length() > 0

	# Ground movement
	if GROUNDED:
		if IS_MOVING:
			var target_velocity = direction * MAX_SPEED
			velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta * 10.0)
			velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta * 10.0)
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta * 6.0)
			velocity.z = move_toward(velocity.z, 0, FRICTION * delta * 6.0)
	else:
		# Air movement: redirect direction only, do not change speed magnitude
		if IS_MOVING:
			var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
			var speed = horizontal_velocity.length()
			if speed > 0:
				var new_dir = horizontal_velocity.normalized().lerp(direction, ACCELERATION * delta)
				velocity.x = new_dir.x * speed
				velocity.z = new_dir.z * speed
			else:
				velocity.x = direction.x * ACCELERATION * delta
				velocity.z = direction.z * ACCELERATION * delta

	# Wall detection
	WALL_COLLIED = is_on_wall()
	CAN_WALL_JUMP = WALL_COLLIED and not GROUNDED
	if WALL_COLLIED:
		last_wall_normal = get_wall_collision_normal()
		if velocity.y < 0:
			velocity.y *= 0.85

	# Jumping / Wall jumps
	if jump_buffer_timer > 0:
		if coyote_timer > 0:
			velocity.y = JUMP_HEIGHT * 2.0
			IS_JUMPING = true
			jump_buffer_timer = 0
		elif CAN_WALL_JUMP and REMAINING_WALL_JUMPS > 0:
			# Strong wall jump overwrite
			var jump_dir = (last_wall_normal + direction).normalized()
			velocity.x = jump_dir.x * MAX_SPEED * 1.5
			velocity.z = jump_dir.z * MAX_SPEED * 1.5
			velocity.y = JUMP_HEIGHT * 3.0  # stronger vertical boost
			REMAINING_WALL_JUMPS -= 1
			jump_buffer_timer = 0

	if Input.is_action_just_released("jump") and velocity.y > 0:
		velocity.y *= 0.5

	# Dash
	if Input.is_action_just_pressed("dash") and not IS_DASHING:
		start_dash(direction)

	# Camera tilt
	if IS_DASHING:
		target_tilt = 0.0
		if Input.is_action_pressed("left"):
			target_tilt = max_tilt
		elif Input.is_action_pressed("right"):
			target_tilt = -max_tilt
	else:
		target_tilt = 0.0

	tilt_angle = lerp(tilt_angle, target_tilt, delta * (tilt_speed * 1.5 if IS_DASHING else tilt_speed))
	CAMERA.rotation.z = tilt_angle

	# Smooth FOV
	CAMERA.fov = lerp(CAMERA.fov, target_fov, delta * fov_lerp_speed)

	move_and_slide()

func start_dash(direction):
	if direction == Vector3.ZERO:
		direction = -CAMERA.global_transform.basis.z.normalized()

	IS_DASHING = true

	velocity.x += direction.x * DASH_SPEED
	velocity.z += direction.z * DASH_SPEED

	var forward_dot = direction.dot(-CAMERA.global_transform.basis.z)

	if forward_dot > 0.5:
		target_fov = base_fov - 5.0
	elif forward_dot < -0.5:
		target_fov = base_fov + 10.0
	elif direction.dot(CAMERA.global_transform.basis.x) > 0:
		target_fov = base_fov + 6.0
	else:
		target_fov = base_fov + 6.0

	await get_tree().create_timer(0.2).timeout

	target_fov = base_fov
	IS_DASHING = false

func get_wall_collision_normal() -> Vector3:
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision.get_normal().y < 0.1:
			return collision.get_normal()
	return Vector3.ZERO
