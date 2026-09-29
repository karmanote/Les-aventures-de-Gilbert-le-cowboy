extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export_group("Tir")
@export var bullet_scene: PackedScene       # à assigner dans l'Inspector avec bullet.tscn
@export var fire_cooldown: float = 0.3      # délai entre deux tirs
@export var auto_fire: bool = true          # maintenir le bouton = tir en rafale
@export var inherit_speed: bool = true      # la balle ajoute ta vitesse si tu cours dans le même sens
@export var shake_on_fire: float = 2.0      # intensité du screen shake (0 = désactivé)

@onready var muzzle_front: Marker2D = $MuzzleFront
@onready var muzzle_back: Marker2D = $MuzzleBack
@onready var camera: Camera2D = $Camera2D

var spawn_position : Vector2
var fire_timer: float = 0.0


func _ready() -> void:
	spawn_position = global_position
	if bullet_scene == null:
		push_warning("Player : 'Bullet Scene' n'est pas assigné dans l'Inspector !")


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
	_handle_shooting(delta)


# --- Tir avant / arrière ---
# Gilbert ne se retourne jamais : "devant" = toujours à droite,
# "derrière" = toujours à gauche, quel que soit son sens de déplacement.
func _handle_shooting(delta: float) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)
	if fire_timer > 0.0:
		return

	if _shoot_pressed("shoot_forward"):
		_shoot(1)
	elif _shoot_pressed("shoot_backward"):
		_shoot(-1)


func _shoot_pressed(action: String) -> bool:
	if auto_fire:
		return Input.is_action_pressed(action)
	return Input.is_action_just_pressed(action)


func _shoot(direction: int) -> void:
	if bullet_scene == null:
		return
	fire_timer = fire_cooldown

	var spawn_point: Marker2D = muzzle_front if direction == 1 else muzzle_back
	var bullet = bullet_scene.instantiate()
	bullet.direction = direction
	bullet.shooter = self
	if inherit_speed:
		bullet.speed += maxf(0.0, velocity.x * direction)

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = spawn_point.global_position

	if shake_on_fire > 0.0 and camera and camera.has_method("trigger_shake"):
		camera.trigger_shake(shake_on_fire, 15.0)

	# TODO : anim "bras tendu vers l'arrière" quand direction == -1 (tir à l'aveuglette)
	# TODO : onomatopée "PAN !" / effet sonore façon BD ici


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.respawn()

func respawn():
	velocity = Vector2.ZERO
	global_position = spawn_position
