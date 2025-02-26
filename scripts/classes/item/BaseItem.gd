extends RigidBody3D
class_name BaseItem

@export var unique_id: String = "stone"

@export var icon_path: String = "res://assets/placeholders/placeholder_64.png"
@export var icon: CompressedTexture2D = CompressedTexture2D.new()
@export var stackable: bool = true
@export var item_count: int = 1
@export var scene: String = "res://scenes/items/stone.tscn"

func _ready() -> void:
	icon = load(icon_path)
