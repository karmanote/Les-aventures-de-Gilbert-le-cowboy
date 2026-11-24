extends CharacterBody2D
## Bandit : l'ennemi de base.
## Il marche, fait demi-tour contre les murs et au bord du vide,
## et fait mal à Gilbert s'il le touche.

const VITESSE = 120.0
const COEF_GRAVITE = 2

@export var direction = -1   # -1 = il part vers la gauche, 1 = vers la droite

var vie = 30
var temps_recul = 0.0        # temps pendant lequel il est repoussé après un coup


func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta * COEF_GRAVITE

	if temps_recul > 0:
		# Il vient de prendre un coup : il se laisse pousser
		temps_recul -= delta
	else:
		marcher()

	move_and_slide()
	toucher_gilbert()


func marcher():
	# Le rayon qui regarde le sol devant ses pieds
	var sol_devant = $SolGauche
	if direction == 1:
		sol_devant = $SolDroite

	# Demi-tour s'il y a un mur devant, ou du vide devant ses pieds
	if is_on_wall() or (is_on_floor() and not sol_devant.is_colliding()):
		direction = -direction

	velocity.x = direction * VITESSE
	$Apparence.scale.x = direction   # il regarde là où il va


# Si Gilbert est dans la zone de contact, il prend des dégâts
func toucher_gilbert():
	for corps in $ZoneContact.get_overlapping_bodies():
		if corps.has_method("prendre_degats"):
			# On pousse Gilbert loin du bandit
			var cote = sign(corps.global_position.x - global_position.x)
			corps.prendre_degats(1, Vector2(cote * 350, -350))


# Appelée par les balles et le coup de pied de Gilbert
func prendre_degats(degats, poussee):
	vie -= degats
	velocity = poussee
	temps_recul = 0.3
	if vie <= 0:
		queue_free()


# Appelée par le Vide
func tomber_dans_le_vide():
	queue_free()
