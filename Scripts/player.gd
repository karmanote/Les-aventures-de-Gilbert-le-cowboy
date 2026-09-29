extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var bullet_scene: PackedScene   # à assigner dans l'Inspector avec bullet.tscn
@export var fire_cooldown: float = 0.35

@onready var muzzle_front: Marker2D = $MuzzleFront
@onready var muzzle_back: Marker2D = $MuzzleBack

var spawn_position : Vector2
var can_shoot: bool = true


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	# --- Tir avant / arrière ---
	# Gilbert ne se retourne jamais : "devant" = toujours à droite,
	# "derrière" = toujours à gauche, quel que soit son sens de déplacement.
	if Input.is_action_just_pressed("shoot_forward"):
		_shoot(1)
	elif Input.is_action_just_pressed("shoot_backward"):
		_shoot(-1)


func _shoot(direction: int) -> void:
	if not can_shoot or bullet_scene == null:
		return
	can_shoot = false

	var spawn_point: Marker2D = muzzle_front if direction == 1 else muzzle_back
	var bullet: Area2D = bullet_scene.instantiate()
	bullet.direction = direction
	bullet.global_position = spawn_point.global_position
	get_tree().current_scene.add_child(bullet)

	# TODO : anim "bras tendu vers l'arrière" quand direction == -1 (tir à l'aveuglette)
	# TODO : onomatopée "PAN !" / effet sonore façon BD ici

	await get_tree().create_timer(fire_cooldown).timeout
	can_shoot = true


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.respawn()
		
func respawn():
	velocity = Vector2.ZERO
	global_position = spawn_position
