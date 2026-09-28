extends Camera2D

# --- Configuration Horizontale (Look Ahead) ---
@export var look_ahead_distance: float = 350.0  # Distance max vers l'avant
@export var horizontal_shift_speed: float = 1.0 # Vitesse de transition horizontale

# --- Configuration Verticale (Look Up / Down) ---
@export var look_vertical_distance: float = 120.0 # Distance de décalage vers le haut/bas
@export var vertical_shift_speed: float = 1.0     # Vitesse de transition verticale
@export var look_delay: float = 0.8               # Temps d'attente (en secondes) avant de décaler

# --- Position de base (Rappel : le joueur est dans le tiers inférieur) ---
@export var base_offset_y: float = -75.0           # Décalage Y initial de votre caméra

# --- Configuration du Tremblement (Screen Shake) ---
var shake_intensity: float = 0.0      # Force actuelle du tremblement
var shake_decay: float = 5.0          # Vitesse à laquelle le tremblement s'atténue
var noise: FastNoiseLite = FastNoiseLite.new() # Générateur de bruit lissé
var noise_y: float = 0.0              # Position dans le temps pour le bruit

# Références et variables internes
@onready var player: CharacterBody2D = get_parent()
var look_timer: float = 0.0
var look_offset_x: float = 0.0
var look_offset_y: float = 0.0

func _ready() -> void:
	# Initialisation du générateur de bruit pour un mouvement organique
	noise.seed = randi()
	noise.frequency = 0.05 # Plus la fréquence est haute, plus le tremblement est rapide
	look_offset_y = base_offset_y

func _process(delta: float) -> void:
	if not player:
		return
	# =========================================================================
	# 1. GESTION DU DÉCALAGE HORIZONTAL (Look Ahead)
	# =========================================================================
	var target_offset_x: float = 0.0
	
	if player.velocity.x > 10:
		target_offset_x = look_ahead_distance
	elif player.velocity.x < -10:
		target_offset_x = -look_ahead_distance
	else:
		target_offset_x = 0.0

	look_offset_x = lerp(look_offset_x, target_offset_x, horizontal_shift_speed * delta)

	# =========================================================================
	# 2. GESTION DU DÉCALAGE VERTICAL (Look Up / Down)
	# =========================================================================
	var target_offset_y: float = base_offset_y # Par défaut, revient à la position de base
	
	# On vérifie si le joueur est immobile au sol
	var is_immobile: bool = abs(player.velocity.x) < 10 and player.is_on_floor()

	if is_immobile:
		# Récupère l'input vertical du joueur (ex: flèches ou stick)
		# "ui_up" et "ui_down" sont les actions par défaut de Godot, à remplacer par vos inputs
		if Input.is_action_pressed("ui_up"):
			look_timer += delta
			if look_timer >= look_delay:
				target_offset_y = base_offset_y - look_vertical_distance # Monte la caméra
		elif Input.is_action_pressed("ui_down"):
			look_timer += delta
			if look_timer >= look_delay:
				target_offset_y = base_offset_y + look_vertical_distance # Descend la caméra
		else:
			look_timer = 0.0 # Reset si aucune touche pressée
	else:
		look_timer = 0.0 # Reset si le joueur se met à bouger ou saute

	# Applique la transition fluide sur l'axe Y
	look_offset_y = lerp(look_offset_y, target_offset_y, vertical_shift_speed * delta)

	# =========================================================================
	# 3. GESTION ET CALCUL DU SCREEN SHAKE
	# =========================================================================
	# On fait décroître l'intensité du tremblement au fil du temps
	shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
	
	var shake_offset_x: float = 0.0
	var shake_offset_y: float = 0.0
	
	if shake_intensity > 0:
		noise_y += delta * 100.0 # Fait défiler le bruit mathématique
		# Récupère une valeur lissée entre -1 et 1, puis la multiplie par l'intensité
		shake_offset_x = noise.get_noise_2d(noise_y, 0) * shake_intensity
		shake_offset_y = noise.get_noise_2d(0, noise_y) * shake_intensity

	# =========================================================================
	# 4. APPLICATION FINALE SUR L'OFFSET
	# =========================================================================
	# On combine le décalage de visée standard (Look) ET le tremblement (Shake)
	offset.x = look_offset_x + shake_offset_x
	offset.y = look_offset_y + shake_offset_y

# =========================================================================
# FONCTION PUBLIQUE : Appelez cette fonction depuis n'importe quel script !
# =========================================================================
func trigger_shake(intensity: float, decay: float = 5.0) -> void:
	shake_intensity = intensity
	shake_decay = decay


# =========================================================================
# FONCTION PUBLIQUE : Zoom lent et fluide vers une valeur cible.
# Un zoom < 1.0 rapproche la caméra (zoom avant), > 1.0 l'éloigne (zoom arrière).
# =========================================================================
var zoom_tween : Tween = null

func zoom_to(target_zoom: float, duration: float = 1.5) -> void:
	if zoom_tween != null and zoom_tween.is_valid():
		zoom_tween.kill()

	zoom_tween = create_tween()
	zoom_tween.set_trans(Tween.TRANS_SINE)
	zoom_tween.set_ease(Tween.EASE_IN_OUT)
	zoom_tween.tween_property(self, "zoom", Vector2.ONE * target_zoom, duration)

"""# Si la caméra est un enfant direct du joueur :
$Camera2D.trigger_shake(15.0, 4.0) 

# Valeurs de référence pour l'intensité :
# 5.0  = Petit tremblement (coup d'épée classique)
# 15.0 = Tremblement moyen (le joueur prend un coup)
# 30.0 = Gros tremblement (explosion, boss qui s'écrase au sol)
Mort d'un boss : trigger_freeze(0.5, 0.1). Au lieu de figer complètement (0.0), 
on passe le temps à 0.1 (gros ralenti) pendant une demi-seconde pour un effet cinématique."""
