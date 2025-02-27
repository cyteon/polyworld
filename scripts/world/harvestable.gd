extends StaticBody3D
class_name Harvestable

@export var health: int = 100
@export var yields: BaseItem

@export var yields_total: int = 20
var yields_per_damage: float = yields_total as float / health as float

func damage(amount: int) -> void:
	health -= amount
	
	if health <= 0:
		Network.rpc("_despawn_item", get_path())
