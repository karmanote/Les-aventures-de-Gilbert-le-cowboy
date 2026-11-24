extends Area2D
## Balle en plastique tirée par Gilbert.
## Ligne droite, dégâts au premier contact, disparaît après un délai si elle ne touche rien.

@export var speed: float = 1200.0   ## vitesse de base (le joueur peut y ajouter la sienne)
@export var damage: int = 10
@export var knockback: Vector2 = Vector2(150, -100) ## petit recul infligé à la cible
@export var lifetime: float = 1.5   ## secondes avant autodestruction

var direction: int = 1              ## 1 = devant (droite), -1 = derrière (gauche)
var shooter: Node = null            ## Gilbert : la balle l'ignore

@onready var visual: Node2D = $Visual


func _ready() -> void:
	visual.scale.x = direction
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position.x += direction * speed * delta

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, Vector2(knockback.x * direction, knockback.y))
	queue_free()
