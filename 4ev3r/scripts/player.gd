extends CharacterBody3D

# These are for interacting with the nodes directly do not touch or edit unless you rename a node.
@onready var COLLIDER: CollisionShape3D = $collider
@onready var CAM_PIVOT: Node3D = $camPivot
@onready var CAMERA: Camera3D = $camPivot/camera

# Actually important things below
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
@export_subgroup("Speed Alterations")
@export var SPEED : float = 0.0
@export var MAX_SPEED: float = 5.0
@export var ACCELERATION: float = 5.0
@export var DASH_SPEED: float = 15.0
@export var JUMP_HEIGHT: float = 3.5
@export_subgroup("Wall Bullshit")
@export var REMAINING_WALL_JUMPS: int = 3
@export var WALL_JUMP_ANGLE: float = 0.0
@export_group("")
