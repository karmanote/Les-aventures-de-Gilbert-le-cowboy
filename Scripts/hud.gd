extends CanvasLayer
## Affichage à l'écran : vie, bouteilles de whisky, messages et rappel des touches.

@onready var stats_label: Label = $Stats
@onready var message_label: Label = $Message

var player = null


func _ready() -> void:
	message_label.text = ""
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		push_warning("HUD : aucun joueur trouvé dans le groupe 'Player'")
		return
	player.health_changed.connect(_on_health_changed)
	player.bottles_changed.connect(_on_bottles_changed)
	player.died.connect(_on_player_died)
	_refresh()


func _refresh() -> void:
	stats_label.text = "Vie : %d / %d\nWhisky : %d" % [player.health, player.max_health, player.bottles]


func _on_health_changed(_current: int, _maximum: int) -> void:
	_refresh()


func _on_bottles_changed(_count: int) -> void:
	_refresh()


func _on_player_died() -> void:
	message_label.text = "Gilbert a mordu la poussière..."
