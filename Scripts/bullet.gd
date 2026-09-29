extends Area2D
## Balle en plastique tirée par Gilbert.
## Se déplace en ligne droite (gauche ou droite), inflige des dégâts au premier
## contact puis disparaît. S'autodétruit aussi si elle ne touche rien après un délai.

@export var speed: float = 260.0      # volontairement lent : "balle en plastique"
@export var damage: float = 10.0
@export var lifetime: float = 2.0     # secondes avant autodestruction

var direction: int = 1                # 1 = vers la droite, -1 = vers la gauche

func _ready() -> void:
	scale.x = direction

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_hit(area)

func _hit(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
	queue_free()
