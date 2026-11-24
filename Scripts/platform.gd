@tool
extends StaticBody2D
## Plateforme "greybox" pour monter des niveaux de test rapidement.
## Change `size` dans l'Inspector : la collision et le dessin suivent, même dans l'éditeur.
## À remplacer plus tard par de vrais décors (TileMapLayer + sprites).

var _shape := RectangleShape2D.new()

@export var size: Vector2 = Vector2(256, 64):
	set(value):
		size = value
		_shape.size = size
		queue_redraw()

@export var color: Color = Color(0.55, 0.38, 0.22):
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	# La collision est créée par le code (et jamais sauvegardée dans la scène)
	# pour que chaque plateforme ait sa propre taille.
	var collision := CollisionShape2D.new()
	collision.shape = _shape
	add_child(collision)
	_shape.size = size


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, color)
	# Liseré clair sur le dessus pour bien voir où on marche
	draw_rect(Rect2(rect.position, Vector2(size.x, minf(6.0, size.y))), color.lightened(0.3))
