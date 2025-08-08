extends RigidBody3D
class_name BaseItem

@export var unique_id: String = "stone"

@export var icon_path: String = "res://assets/placeholders/placeholder_64.png"
var icon: CompressedTexture2D = load(icon_path)

@export var stackable: bool = true
@export var item_count: int = 1
@export var scene: String = "res://scenes/items/stone.tscn"

var material = preload("res://shaders/item_outline.tres").duplicate()

func _ready() -> void:
	icon = load(icon_path)

	for c in get_children():
		if c is MeshInstance3D:
			c.mesh.material.next_pass = material

func enable_outline() -> void:
	for c in get_children():
		if c is MeshInstance3D:
			c.mesh.material.next_pass.set(
				"shader_parameter/outline_color",
				Vector4(255, 255, 255, 1.0)
			)

func disable_outline() -> void:
	for c in get_children():
		if c is MeshInstance3D:
			c.mesh.material.next_pass.set(
				"shader_parameter/outline_color",
				Vector4(255, 255, 255, 0.0)
			)
