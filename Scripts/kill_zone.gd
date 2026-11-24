extends Area2D
## Le vide sous le niveau : tout ce qui tombe dedans est puni.
## Gilbert perd une vie et revient au dernier checkpoint, les ennemis disparaissent.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("fall_into_void"):
		# call_deferred : on ne téléporte pas un corps en plein calcul de physique
		body.call_deferred("fall_into_void")
	else:
		body.queue_free()
