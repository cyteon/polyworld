extends RigidBody3D
class_name BaseItem

@export var unique_id: String = "stone"

@export var icon: CompressedTexture2D = load("res://assets/placeholders/placeholder_64.png")
@export var stackable: bool = true
@export var item_count: int = 1
