extends CharacterBody2D
## Bandit : l'ennemi de base.
## Il patrouille, fait demi-tour contre les murs et au bord du vide,
## et fait mal à Gilbert s'il le touche. Les balles et le coup de pied le blessent.
## (Contrairement à Gilbert, lui a le droit de se retourner !)

@export var max_health: int = 30
@export var speed: float = 120.0
@export var contact_damage: int = 1
@export var contact_knockback: Vector2 = Vector2(350, -350) ## poussée infligée à Gilbert
@export_enum("Gauche:-1", "Droite:1") var start_direction: int = -1
@export var gravity_scale: float = 2.0

var health: int
var direction: int
var knockback_timer: float = 0.0
var flash_timer: float = 0.0
var dying: bool = false

@onready var visual: Node2D = $Visual
@onready var ledge_check: RayCast2D = $LedgeCheck
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	health = max_health
	direction = start_direction


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta

	if dying:
		velocity.x = 0.0
	elif knockback_timer > 0.0:
		knockback_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	else:
		_patrol()

	move_and_slide()
	_hurt_player_on_contact()
	_update_visual(delta)


func _patrol() -> void:
	# Le rayon regarde le sol juste devant les pieds : s'il ne touche rien, c'est le vide
	ledge_check.position.x = direction * absf(ledge_check.position.x)
	ledge_check.force_raycast_update()
	var hit_wall := is_on_wall() and get_wall_normal().x * direction < 0.0
	var at_ledge := is_on_floor() and not ledge_check.is_colliding()
	if hit_wall or at_ledge:
		direction = -direction
	velocity.x = direction * speed


func _hurt_player_on_contact() -> void:
	if dying:
		return
	for body in hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			var side := signf(body.global_position.x - global_position.x)
			if side == 0.0:
				side = 1.0
			body.take_damage(contact_damage, Vector2(contact_knockback.x * side, contact_knockback.y))


## Appelée par les balles et le coup de pied de Gilbert.
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if dying:
		return
	health -= amount
	flash_timer = 0.1
	if knockback != Vector2.ZERO:
		velocity = knockback
		knockback_timer = 0.3
	if health <= 0:
		die()


func die() -> void:
	if dying:
		return
	dying = true
	set_deferred("collision_layer", 0) # les balles passent à travers le cadavre
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2(1.4, 0.1), 0.15) # écrasé façon cartoon
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


## Appelée par la KillZone.
func fall_into_void() -> void:
	queue_free()


func _update_visual(delta: float) -> void:
	if dying:
		return
	visual.scale.x = direction
	flash_timer = maxf(0.0, flash_timer - delta)
	visual.modulate = Color(4, 4, 4) if flash_timer > 0.0 else Color.WHITE
