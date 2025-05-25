extends BaseItem
class_name ConsumableItem

@onready var player = get_parent().get_parent()

@export var increase_health: int = 0
@export var increase_hunger: int = 0
@export var increase_stamina: int = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if get_parent().name != "Hold": return
	if not player.is_multiplayer_authority(): return
	
	if Input.is_action_just_pressed("use"):
		if player.is_blocking_ui_visible():
			return
		
		# TODO: play eating sound or sum
		player.health += increase_health
		player.hunger += increase_hunger
		player.stamina += increase_stamina
		
		player.hotbar_items[player.current_hotbar_slot].item_count -= 1
		
		if player.hotbar_items[player.current_hotbar_slot].item_count <= 0:
			player.hotbar_items[player.current_hotbar_slot] = null
