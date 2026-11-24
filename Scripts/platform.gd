@tool
extends StaticBody2D
## Plateforme provisoire pour tester des niveaux (en attendant les vrais décors).
## Change "taille" dans l'Inspecteur : le rectangle et sa collision suivent.
## @tool = ce script tourne aussi dans l'éditeur, pour qu'on voie le rectangle.

@export var taille = Vector2(256, 64)
@export var couleur = Color(0.55, 0.38, 0.22)

var forme = RectangleShape2D.new()


func _ready():
	# Chaque plateforme fabrique sa propre collision, à sa taille
	var collision = CollisionShape2D.new()
	collision.shape = forme
	add_child(collision)
	forme.size = taille


func _process(_delta):
	forme.size = taille   # la collision suit la taille
	queue_redraw()        # on redessine le rectangle


func _draw():
	draw_rect(Rect2(-taille / 2, taille), couleur)
