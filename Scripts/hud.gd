extends CanvasLayer
## Affiche la vie et le whisky de Gilbert en haut de l'écran.

@onready var gilbert = get_tree().get_first_node_in_group("Player")


func _process(_delta):
	$Stats.text = "Vie : " + str(gilbert.vie) + " / " + str(gilbert.VIE_MAX)
	$Stats.text += "\nWhisky : " + str(gilbert.bouteilles)

	if gilbert.etat == "mort":
		$Message.text = "Gilbert a mordu la poussière..."
