extends CharacterBody2D
## Gilbert le cowboy.
##
## Règle d'or : Gilbert ne se retourne JAMAIS.
## Devant = toujours à droite, derrière = toujours à gauche.
## Il peut reculer (moonwalk) et tirer derrière lui à l'aveuglette.
##
## Gilbert est toujours dans UN "état" à la fois :
## "normal", "dash", "glissade", "roulade", "coup_de_pied", "boire", "touche" ou "mort".
## Selon son état, il ne peut pas faire les mêmes choses.


# --- Réglages : change les nombres pour tester ! ---
const VITESSE = 450.0
const VITESSE_SAUT = -800.0
const COEF_GRAVITE = 2

const VITESSE_DASH = 1100.0
const DUREE_DASH = 0.15

const VITESSE_GLISSADE = 700.0
const DUREE_GLISSADE = 0.5

const VITESSE_ROULADE = 550.0
const DUREE_ROULADE = 0.35

const ATTENTE_ENTRE_ESQUIVES = 0.5  # temps à attendre entre deux dashs ou roulades

const DEGATS_COUP_DE_PIED = 15
const DUREE_COUP_DE_PIED = 0.3

const VIE_MAX = 5
const SOIN_WHISKY = 2
const DUREE_BOIRE = 0.8
const DUREE_TOUCHE = 0.25      # Gilbert est sonné pendant ce temps après un coup
const DUREE_INVINCIBLE = 1.0   # temps sans prendre de dégâts après un coup

const BALLE = preload("res://Prefabs/Bullet.tscn")


# --- Variables qui changent pendant le jeu ---
var etat = "normal"
var temps_dans_etat = 0.0      # depuis combien de secondes on est dans l'état actuel
var direction_action = 1       # sens du dash / de la glissade / de la roulade (1 = droite, -1 = gauche)
var vie = VIE_MAX
var bouteilles = 3
var attente_esquive = 0.0
var temps_invincible = 0.0
var point_de_depart = Vector2.ZERO


func _ready():
	point_de_depart = global_position


func _physics_process(delta):
	# Les compteurs de temps
	temps_dans_etat += delta
	attente_esquive -= delta
	temps_invincible -= delta

	# La gravité (sauf pendant le dash)
	if not is_on_floor() and etat != "dash":
		velocity += get_gravity() * delta * COEF_GRAVITE

	# Ce que fait Gilbert dépend de son état
	match etat:
		"normal": etat_normal()
		"dash": etat_dash()
		"glissade": etat_glissade()
		"roulade": etat_roulade()
		"coup_de_pied": etat_coup_de_pied()
		"boire": etat_boire()
		"touche": etat_touche()
		"mort": velocity.x = 0

	move_and_slide()
	mettre_a_jour_apparence()


func changer_etat(nouvel_etat):
	etat = nouvel_etat
	temps_dans_etat = 0.0


# =========================================================================
# LES ÉTATS
# =========================================================================

func etat_normal():
	# Courir à gauche ou à droite
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * VITESSE
	else:
		velocity.x = move_toward(velocity.x, 0, VITESSE / 2)

	# Sauter
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = VITESSE_SAUT

	gerer_tir()

	# Les actions spéciales
	if Input.is_action_just_pressed("dash") and attente_esquive <= 0:
		changer_etat("dash")
		direction_action = direction_choisie()
		attente_esquive = ATTENTE_ENTRE_ESQUIVES

	elif Input.is_action_just_pressed("slide") and is_on_floor():
		changer_etat("glissade")
		direction_action = direction_choisie()
		se_baisser(true)

	elif Input.is_action_just_pressed("roll") and is_on_floor() and attente_esquive <= 0:
		changer_etat("roulade")
		direction_action = direction_choisie()
		attente_esquive = ATTENTE_ENTRE_ESQUIVES
		se_baisser(true)

	elif Input.is_action_just_pressed("front_kick"):
		changer_etat("coup_de_pied")
		donner_coup_de_pied()

	elif Input.is_action_just_pressed("drink") and bouteilles > 0 and vie < VIE_MAX and is_on_floor():
		changer_etat("boire")


# Dash : une poussée très rapide, même en l'air
func etat_dash():
	velocity = Vector2(direction_action * VITESSE_DASH, 0)
	gerer_tir()
	if temps_dans_etat >= DUREE_DASH:
		changer_etat("normal")


# Glissade : Gilbert se couche et glisse. Il peut tirer en même temps !
func etat_glissade():
	velocity.x = direction_action * VITESSE_GLISSADE
	gerer_tir()
	# À la fin, on se relève... sauf si on est encore sous un plafond
	if temps_dans_etat >= DUREE_GLISSADE and peut_se_relever():
		se_baisser(false)
		changer_etat("normal")


# Roulade : comme la glissade, mais Gilbert est invincible et ne tire pas
func etat_roulade():
	velocity.x = direction_action * VITESSE_ROULADE
	if temps_dans_etat >= DUREE_ROULADE and peut_se_relever():
		se_baisser(false)
		changer_etat("normal")


func etat_coup_de_pied():
	velocity.x = move_toward(velocity.x, 0, VITESSE / 2)
	if temps_dans_etat >= DUREE_COUP_DE_PIED:
		changer_etat("normal")


# Boire : Gilbert s'arrête pour boire, et récupère de la vie à la fin
func etat_boire():
	velocity.x = 0
	if temps_dans_etat >= DUREE_BOIRE:
		bouteilles -= 1
		vie = min(vie + SOIN_WHISKY, VIE_MAX)
		changer_etat("normal")


# Touché : Gilbert est sonné, on ne le contrôle plus pendant un court instant
func etat_touche():
	if temps_dans_etat >= DUREE_TOUCHE:
		se_baisser(false)
		changer_etat("normal")


# =========================================================================
# LES ACTIONS
# =========================================================================

# Le sens des touches, ou devant (droite) si on n'appuie sur rien
func direction_choisie():
	if Input.get_axis("ui_left", "ui_right") < 0:
		return -1
	return 1


# Clic gauche = tirer devant (à droite), clic droit = tirer derrière (à gauche)
func gerer_tir():
	if Input.is_action_just_pressed("shoot_forward"):
		tirer(1, $CanonDevant)
	if Input.is_action_just_pressed("shoot_backward"):
		tirer(-1, $CanonDerriere)


func tirer(direction, canon):
	var balle = BALLE.instantiate()
	balle.direction = direction
	get_tree().current_scene.add_child(balle)
	balle.global_position = canon.global_position
	$Camera2D.trigger_shake(2.0, 8.0)
	# TODO : onomatopée "PAN !" / effet sonore façon BD


# Le coup de pied touche tous les ennemis dans la zone devant Gilbert
func donner_coup_de_pied():
	for corps in $ZoneCoupDePied.get_overlapping_bodies():
		if corps.has_method("prendre_degats"):
			corps.prendre_degats(DEGATS_COUP_DE_PIED, Vector2(600, -300))
			$Camera2D.trigger_shake(8.0, 30.0)


# Baissé (glissade, roulade) = petite hitbox, pour passer sous les obstacles
func se_baisser(baisse):
	# set_deferred = on change la collision à la fin de la frame, pas en plein calcul
	$HitboxDebout.set_deferred("disabled", baisse)
	$HitboxBaissee.set_deferred("disabled", not baisse)


# On peut se relever s'il n'y a rien dans la zone au-dessus de la tête
func peut_se_relever():
	return not $ZoneTete.has_overlapping_bodies()


# =========================================================================
# LA VIE
# =========================================================================

# Appelée par les ennemis quand ils touchent Gilbert
func prendre_degats(degats, poussee):
	if etat == "mort" or etat == "roulade" or temps_invincible > 0:
		return  # pas de dégâts !

	vie -= degats
	$Camera2D.trigger_shake(12.0, 40.0)
	if vie <= 0:
		mourir()
	else:
		temps_invincible = DUREE_INVINCIBLE
		velocity = poussee
		changer_etat("touche")


# Appelée par le Vide quand Gilbert tombe dedans
func tomber_dans_le_vide():
	if etat == "mort":
		return

	vie -= 1
	if vie <= 0:
		mourir()
	else:
		# Retour au point de départ
		global_position = point_de_depart
		velocity = Vector2.ZERO
		temps_invincible = DUREE_INVINCIBLE
		se_baisser(false)
		changer_etat("normal")


func mourir():
	vie = 0
	changer_etat("mort")
	await get_tree().create_timer(1.5).timeout  # on attend 1,5 seconde...
	get_tree().reload_current_scene()           # ...et on recommence le niveau


# =========================================================================
# L'APPARENCE (en attendant les vrais sprites)
# =========================================================================

func mettre_a_jour_apparence():
	# Écrasé quand il est baissé
	if etat == "glissade" or etat == "roulade":
		$Apparence.scale = Vector2(1.2, 0.5)
		$Apparence.position.y = 16
	else:
		$Apparence.scale = Vector2(1, 1)
		$Apparence.position.y = 0

	# Allongé quand il est mort
	if etat == "mort":
		$Apparence.rotation_degrees = -90

	# À moitié transparent quand il est invincible
	if temps_invincible > 0 or etat == "roulade":
		$Apparence.modulate.a = 0.5
	else:
		$Apparence.modulate.a = 1.0

	# La bouteille et la botte n'apparaissent que pendant leur action
	$Apparence/Bouteille.visible = (etat == "boire")
	$ZoneCoupDePied/Botte.visible = (etat == "coup_de_pied")
