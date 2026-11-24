extends CharacterBody2D
## Gilbert le cowboy.
##
## Règle d'or : Gilbert ne se retourne JAMAIS.
## "Devant" = toujours à droite, "derrière" = toujours à gauche, quel que soit
## son sens de déplacement : il recule en moonwalk et tire derrière lui à l'aveuglette.
##
## Le script est une machine à états : Gilbert est toujours dans UN seul état
## (normal, dash, glissade...). Chaque état a sa fonction _state_xxx() appelée
## à chaque frame, et on passe d'un état à l'autre avec _change_state().

signal health_changed(current: int, maximum: int)
signal bottles_changed(count: int)
signal died

enum State { NORMAL, DASH, SLIDE, ROLL, KICK, DRINK, HURT, DEAD }

## Devant = droite. C'est le concept du jeu, on n'y touche pas !
const FORWARD := 1
## Différence de hauteur entre la hitbox debout (64) et accroupie (32).
const CROUCH_DELTA := 32.0

@export_group("Déplacement")
@export var speed: float = 450.0
@export var deceleration: float = 6000.0       ## freinage au sol quand on lâche les touches
@export var air_deceleration: float = 1500.0   ## freinage en l'air : garde l'élan d'un dash ou d'une glissade
@export var gravity_scale: float = 2.0
@export var max_fall_speed: float = 1400.0

@export_group("Saut")
@export var jump_velocity: float = -800.0
@export var coyote_time: float = 0.1   ## on peut encore sauter un court instant après avoir quitté le bord
@export var jump_buffer: float = 0.1   ## un saut appuyé juste avant d'atterrir est quand même pris
@export var jump_cut: float = 0.5      ## relâcher le saut tôt = saut plus court

@export_group("Tir")
@export var bullet_scene: PackedScene  ## Prefabs/Bullet.tscn
@export var fire_cooldown: float = 0.25
@export var auto_fire: bool = true     ## maintenir le clic = tir en rafale
@export var inherit_speed: bool = true ## la balle ajoute la vitesse de Gilbert s'il court dans le même sens
@export var shake_on_fire: float = 2.0 ## intensité du screen shake (0 = désactivé)

@export_group("Dash")
@export var dash_speed: float = 1100.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.4
@export var air_dashes: int = 1        ## dashs autorisés en l'air avant de retoucher le sol

@export_group("Glissade")
@export var slide_speed: float = 750.0
@export var slide_duration: float = 0.55
@export var slide_friction: float = 900.0

@export_group("Roulade")
@export var roll_speed: float = 550.0
@export var roll_duration: float = 0.35
@export var roll_cooldown: float = 0.5

@export_group("Coup de pied")
@export var kick_damage: int = 15
@export var kick_duration: float = 0.35
@export var kick_hit_time: float = 0.1 ## moment où le pied touche (après l'élan)
@export var kick_knockback: Vector2 = Vector2(600, -300)

@export_group("Vie")
@export var max_health: int = 5
@export var max_bottles: int = 3
@export var drink_heal: int = 2
@export var drink_duration: float = 0.8
@export var hurt_duration: float = 0.25
@export var invincibility_time: float = 1.0

@onready var visual: Node2D = $Visual
@onready var bottle: Polygon2D = $Visual/Bottle
@onready var stand_shape: CollisionShape2D = $StandShape
@onready var crouch_shape: CollisionShape2D = $CrouchShape
@onready var muzzle_front: Marker2D = $MuzzleFront
@onready var muzzle_back: Marker2D = $MuzzleBack
@onready var kick_hitbox: Area2D = $KickHitbox
@onready var boot: Polygon2D = $KickHitbox/Boot
@onready var camera: Camera2D = $Camera2D

var state: State = State.NORMAL
var state_time: float = 0.0   # temps passé dans l'état actuel
var move_dir: int = FORWARD   # sens du dash / de la glissade / de la roulade en cours

var health: int
var bottles: int
var checkpoint_position: Vector2

var fire_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var roll_cooldown_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var invincible_timer: float = 0.0
var air_dashes_left: int = 0
var kick_done: bool = false
var crouched: bool = false

var _muzzle_height: float


func _ready() -> void:
	health = max_health
	bottles = max_bottles
	checkpoint_position = global_position
	air_dashes_left = air_dashes
	_muzzle_height = muzzle_front.position.y
	if bullet_scene == null:
		push_warning("Player : 'Bullet Scene' n'est pas assigné dans l'Inspector !")


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	state_time += delta

	match state:
		State.NORMAL: _state_normal(delta)
		State.DASH: _state_dash(delta)
		State.SLIDE: _state_slide(delta)
		State.ROLL: _state_roll(delta)
		State.KICK: _state_kick(delta)
		State.DRINK: _state_drink(delta)
		State.HURT: _state_hurt(delta)
		State.DEAD: _state_dead(delta)

	move_and_slide()

	if is_on_floor():
		coyote_timer = coyote_time
		air_dashes_left = air_dashes

	_update_visual()


func _update_timers(delta: float) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	roll_cooldown_timer = maxf(0.0, roll_cooldown_timer - delta)
	coyote_timer = maxf(0.0, coyote_timer - delta)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	invincible_timer = maxf(0.0, invincible_timer - delta)
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer


# =========================================================================
# ÉTATS
# =========================================================================

func _state_normal(delta: float) -> void:
	_apply_gravity(delta)
	_apply_horizontal_input(delta)
	_try_jump()
	_handle_shooting()

	# Actions spéciales : une seule à la fois
	if Input.is_action_just_pressed("dash") and _can_dash():
		_change_state(State.DASH)
	elif Input.is_action_just_pressed("slide") and is_on_floor():
		_change_state(State.SLIDE)
	elif Input.is_action_just_pressed("roll") and is_on_floor() and roll_cooldown_timer <= 0.0:
		_change_state(State.ROLL)
	elif Input.is_action_just_pressed("front_kick"):
		_change_state(State.KICK)
	elif Input.is_action_just_pressed("drink") and _can_drink():
		_change_state(State.DRINK)


# Dash : rafale horizontale très rapide, sans gravité. Marche aussi en l'air.
func _state_dash(_delta: float) -> void:
	velocity = Vector2(move_dir * dash_speed, 0.0)
	_handle_shooting()
	if state_time >= dash_duration:
		velocity.x = move_dir * speed
		_end_action()


# Glissade : Gilbert se couche et glisse en gardant son élan.
# Il peut tirer pendant la glissade et sauter pour en sortir (le saut garde l'élan !).
func _state_slide(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
	_handle_shooting()

	if not _can_stand_up():
		# Coincé sous un plafond : on avance au minimum pour ressortir de l'autre côté
		velocity.x = move_dir * maxf(absf(velocity.x), speed * 0.5)
		return

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_change_state(State.NORMAL)
		_jump()
	elif not is_on_floor() or state_time >= slide_duration or absf(velocity.x) < speed * 0.4:
		_change_state(State.NORMAL)


# Roulade : esquive courte, Gilbert est invincible pendant toute la roulade.
func _state_roll(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_dir * roll_speed
	if state_time >= roll_duration:
		velocity.x = move_dir * speed * 0.5
		_end_action()


# Coup de pied : toujours vers l'avant (Gilbert ne se retourne pas !).
func _state_kick(delta: float) -> void:
	_apply_gravity(delta)
	var decel := deceleration if is_on_floor() else air_deceleration
	velocity.x = move_toward(velocity.x, 0.0, decel * delta)

	if not kick_done and state_time >= kick_hit_time:
		kick_done = true
		_kick_hit()

	if state_time >= kick_duration:
		_end_action()


# Boire : Gilbert s'arrête pour boire une gorgée de whisky et récupère de la vie.
# S'il se fait toucher avant la fin, la gorgée est perdue (mais pas la bouteille).
func _state_drink(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	if state_time >= drink_duration:
		bottles -= 1
		health = mini(health + drink_heal, max_health)
		bottles_changed.emit(bottles)
		health_changed.emit(health, max_health)
		_end_action()


func _state_hurt(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, air_deceleration * delta)
	if state_time >= hurt_duration:
		_end_action()


func _state_dead(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)


func _change_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0

	match new_state:
		State.NORMAL:
			if crouched:
				_set_crouched(false)
		State.DASH:
			move_dir = _input_dir_or(FORWARD)
			dash_cooldown_timer = dash_cooldown
			if not is_on_floor():
				air_dashes_left -= 1
			velocity = Vector2(move_dir * dash_speed, 0.0)
			_shake(3.0)
		State.SLIDE:
			var current_dir := int(signf(velocity.x)) if velocity.x != 0.0 else FORWARD
			move_dir = _input_dir_or(current_dir)
			velocity.x = move_dir * maxf(slide_speed, absf(velocity.x))
			_set_crouched(true)
		State.ROLL:
			move_dir = _input_dir_or(FORWARD)
			roll_cooldown_timer = roll_cooldown
			velocity.x = move_dir * roll_speed
			_set_crouched(true)
		State.KICK:
			kick_done = false
		State.DEAD:
			died.emit()
			get_tree().create_timer(1.5).timeout.connect(_on_death_timer_timeout)


## Fin d'une action : retour à l'état normal, sauf si on est coincé sous un plafond.
func _end_action() -> void:
	if crouched and not _can_stand_up():
		_change_state(State.SLIDE)
	else:
		_change_state(State.NORMAL)


# =========================================================================
# DÉPLACEMENT
# =========================================================================

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta
		velocity.y = minf(velocity.y, max_fall_speed)


func _apply_horizontal_input(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var target := direction * speed
	if direction != 0.0 and absf(velocity.x) <= speed:
		velocity.x = target # réactif : pleine vitesse tout de suite
	else:
		# On lâche les touches, ou on va plus vite que la normale (élan d'un dash / d'une glissade)
		var decel := deceleration if is_on_floor() else air_deceleration
		velocity.x = move_toward(velocity.x, target, decel * delta)


func _try_jump() -> void:
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_jump()
	# Saut à hauteur variable : relâcher tôt coupe la montée
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= jump_cut


func _jump() -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0


func _can_dash() -> bool:
	return dash_cooldown_timer <= 0.0 and (is_on_floor() or air_dashes_left > 0)


func _can_drink() -> bool:
	return bottles > 0 and health < max_health and is_on_floor()


## Sens donné par les touches, ou default_dir si aucune touche n'est appuyée.
func _input_dir_or(default_dir: int) -> int:
	var axis := Input.get_axis("ui_left", "ui_right")
	if axis > 0.0:
		return 1
	if axis < 0.0:
		return -1
	return default_dir


## Accroupi (glissade, roulade) = petite hitbox, on passe sous les obstacles bas.
func _set_crouched(value: bool) -> void:
	crouched = value
	# set_deferred : on ne change pas les collisions en plein calcul de physique
	stand_shape.set_deferred("disabled", value)
	crouch_shape.set_deferred("disabled", not value)
	# On tire plus bas quand on est couché
	var muzzle_y := _muzzle_height + CROUCH_DELTA * 0.5 if value else _muzzle_height
	muzzle_front.position.y = muzzle_y
	muzzle_back.position.y = muzzle_y


## Vrai s'il y a la place de se relever (pas de plafond juste au-dessus).
func _can_stand_up() -> bool:
	if not crouched:
		return true
	return not test_move(global_transform, Vector2(0.0, -CROUCH_DELTA))


# =========================================================================
# COMBAT
# =========================================================================

# --- Tir avant / arrière ---
# "devant" = toujours à droite (clic gauche), "derrière" = toujours à gauche (clic droit).
func _handle_shooting() -> void:
	if fire_timer > 0.0:
		return
	if _shoot_pressed("shoot_forward"):
		_shoot(FORWARD)
	elif _shoot_pressed("shoot_backward"):
		_shoot(-FORWARD)


func _shoot_pressed(action: String) -> bool:
	if auto_fire:
		return Input.is_action_pressed(action)
	return Input.is_action_just_pressed(action)


func _shoot(direction: int) -> void:
	if bullet_scene == null:
		return
	fire_timer = fire_cooldown

	var spawn_point: Marker2D = muzzle_front if direction == FORWARD else muzzle_back
	var bullet = bullet_scene.instantiate()
	bullet.direction = direction
	bullet.shooter = self
	if inherit_speed:
		bullet.speed += maxf(0.0, velocity.x * direction)

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = spawn_point.global_position
	_shake(shake_on_fire)

	# TODO : anim "bras tendu vers l'arrière" quand direction == -1 (tir à l'aveuglette)
	# TODO : onomatopée "PAN !" / effet sonore façon BD ici


func _kick_hit() -> void:
	var hit_something := false
	for body in kick_hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(kick_damage, Vector2(kick_knockback.x * FORWARD, kick_knockback.y))
			hit_something = true
	if hit_something:
		_shake(8.0)


## Appelée par les ennemis. knockback = la poussée reçue (vers où Gilbert est projeté).
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD or is_invincible():
		return
	_lose_health(amount)
	if state == State.DEAD:
		return
	velocity = knockback
	_change_state(State.HURT)


func is_invincible() -> bool:
	return invincible_timer > 0.0 or state == State.ROLL


## Appelée par la KillZone quand Gilbert tombe dans le vide.
func fall_into_void() -> void:
	if state == State.DEAD:
		return
	_lose_health(1) # tomber fait toujours mal, même invincible
	if state == State.DEAD:
		return
	global_position = checkpoint_position
	velocity = Vector2.ZERO
	_change_state(State.NORMAL)


## À appeler depuis un futur checkpoint : c'est là que Gilbert reviendra s'il tombe.
func set_checkpoint(new_position: Vector2) -> void:
	checkpoint_position = new_position


func _lose_health(amount: int) -> void:
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_shake(12.0)
	if health == 0:
		_change_state(State.DEAD)
	else:
		invincible_timer = invincibility_time


func _on_death_timer_timeout() -> void:
	get_tree().reload_current_scene()


# =========================================================================
# VISUEL (en attendant les vrais sprites / animations)
# =========================================================================

func _update_visual() -> void:
	var target_scale := Vector2.ONE
	var target_position := Vector2.ZERO
	var target_rotation := 0.0

	match state:
		State.SLIDE:
			target_scale = Vector2(1.2, 0.5)
			target_position = Vector2(0.0, CROUCH_DELTA * 0.5)
		State.ROLL:
			target_scale = Vector2(0.5, 0.5)
			target_position = Vector2(0.0, CROUCH_DELTA * 0.5)
			target_rotation = move_dir * TAU * state_time / roll_duration
		State.DASH:
			target_scale = Vector2(1.3, 0.8)
		State.DRINK:
			target_scale = Vector2(1.0, 0.96 + 0.04 * sin(state_time * 30.0))
		State.DEAD:
			target_rotation = -PI / 2.0 # Gilbert tombe à la renverse

	visual.scale = target_scale
	visual.position = target_position
	visual.rotation = target_rotation

	var color := Color(0.5, 0.5, 0.5) if state == State.DEAD else Color.WHITE
	if invincible_timer > 0.0 and state != State.DEAD:
		color.a = 0.35 if fmod(invincible_timer, 0.16) < 0.08 else 1.0
	visual.modulate = color

	bottle.visible = state == State.DRINK
	boot.visible = state == State.KICK and state_time >= kick_hit_time and state_time < kick_hit_time + 0.15


func _shake(amount: float) -> void:
	if amount > 0.0 and camera and camera.has_method("trigger_shake"):
		camera.trigger_shake(amount, amount * 4.0)
