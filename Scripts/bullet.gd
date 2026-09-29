extends Area2D
## Balle en plastique tirée par Gilbert.
## Ligne droite, dégâts au premier contact, disparaît après un délai si elle ne touche rien.

@export var speed: float = 450.0     # vitesse de base (le joueur peut y ajouter la sienne)
@export var damage: float = 10.0
@export var lifetime: float = 2.5    # secondes avant autodestruction

var direction: int = 1               # 1 = droite, -1 = gauche
var shooter: Node = null             # Gilbert : la balle l'ignore

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# On NE touche PAS au scale (ton 0.125 reste intact) : on retourne juste le sprite.
	sprite.flip_h = direction < 0

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	global_position.x += direction * speed * delta

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_hit(area)


func _hit(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
	queue_free()
