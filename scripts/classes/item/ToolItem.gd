extends BaseItem
class_name ToolItem

# when reach 0, poof
@export var durability: int = 100

# Will take 5 damage, and reduce dur by 3, when used to attack entity
@export var damage: int = 5
@export var attacking_reduces_dur_by: int = 3

enum ToolType {
	MINING,
	HARVESTING,
	WEAPON
}

@export var type: ToolType

# Example: tree is 100, 10 hits required to down tree
# We use harvestable/harvesting even if its mining for simplicity
@export var harvestable_damage: int = 10
@export var harvesting_reduces_dur_by: int = 2

var is_ready = true

func _process(_delta: float) -> void:
	if get_parent().name != "Hold": return
	
	var player: CharacterBody3D = get_parent().get_parent()
	
	if Input.is_action_just_pressed("use"):
		if player.is_blocking_ui_visible():
			return
		
		if len(player.hotbar_items) >= player.current_hotbar_slot:
			var slot = player.hotbar_items[player.current_hotbar_slot]
			
			if slot.unique_id == unique_id and is_ready:
				$AnimationPlayer.play("use")
				Network.rpc("_play_item_anim", player.name.to_int())
				is_ready = false
				
				if not player.get_node("Camera3D/ShortRaycast").is_colliding():
					return
				
				var collider = player.get_node("Camera3D/ShortRaycast").get_collider()
				
				if (
					collider.is_in_group("Harvestable") and type == ToolType.HARVESTING
					or collider.is_in_group("Mineable") and type == ToolType.MINING
				):
					player.hotbar_items[
						player.current_hotbar_slot
					].durability -= harvesting_reduces_dur_by
					
					collider.damage(harvestable_damage)
					
					var item = collider.yields.duplicate() as BaseItem
					for child in item.get_children():
						child.free()
					
					item.item_count = collider.yields_per_damage * harvestable_damage
					item.show()
					item.freeze = false
					
					player.add_item_to_inv(item)
				elif damage > 0:
					if collider.is_in_group("Player"):
						player.hotbar_items[
							player.current_hotbar_slot
						].durability -= attacking_reduces_dur_by
						
						Network.rpc_id(1, "_attack_player", collider.name.to_int(), damage)
					elif collider.is_in_group("Entity"):
						player.hotbar_items[
							player.current_hotbar_slot
						].durability -= attacking_reduces_dur_by
						
						Network.rpc_id(1, "_attack_entity", collider.get_path(), damage)
					elif collider.is_in_group("Harvestable") or collider.is_in_group("Mineable"):
						player.hotbar_items[
							player.current_hotbar_slot
						].durability -= harvesting_reduces_dur_by
				
				if player.hotbar_items[
					player.current_hotbar_slot
				].durability <= 0:
					player.hotbar_items[player.current_hotbar_slot] = null


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	is_ready = true
