extends Area2D
## Balle en plastique tirée par Gilbert. Elle va tout droit.

const VITESSE = 1200.0
const DEGATS = 10

var direction = 1         # 1 = devant (droite), -1 = derrière (gauche)
var duree_de_vie = 1.5    # secondes avant de disparaître si elle ne touche rien


func _physics_process(delta):
	position.x += direction * VITESSE * delta

	duree_de_vie -= delta
	if duree_de_vie <= 0:
		queue_free()


# Branché dans l'éditeur sur le signal "body_entered" : la balle touche quelque chose
func _on_body_entered(body):
	if body.has_method("prendre_degats"):
		body.prendre_degats(DEGATS, Vector2(direction * 150, -100))
	queue_free()
