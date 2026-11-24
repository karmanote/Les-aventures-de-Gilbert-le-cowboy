extends Area2D
## Le Vide sous le niveau : ce qui tombe dedans est puni.


# Branché dans l'éditeur sur le signal "body_entered" : quelque chose tombe dans le vide
func _on_body_entered(body):
	if body.has_method("tomber_dans_le_vide"):
		body.tomber_dans_le_vide()
