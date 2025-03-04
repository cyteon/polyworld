extends CharacterBody3D

var normal_speed: float = 5.0
var speed: float = normal_speed
const JUMP_VELOCITY: float = 4.5

@export var health: int = 100

@export var max_stamina: int = 100
@export var stamina: float = max_stamina

var current_hotbar_slot: int = 1
@export var hotbar_items: Array[BaseItem] = []
@export var inventory_items: Array[BaseItem] = []

func _ready() -> void:
	if is_multiplayer_authority():
		Network.take_damage.connect(_take_damage)
	else:
		Network.rpc_id(name.to_int(), "_ready_to_send_to", multiplayer.get_unique_id())
		Network.set_holding.connect(_set_holding)
		Network.play_item_anim.connect(_play_item_anim)

func _take_damage(damage: int) -> void:
	health -= damage
	# TODO: maybe smth to indicate like sound effect or sum
	# TODO: add death screen
	
	if health <= 0:
		var all_items = hotbar_items + inventory_items
		hotbar_items = []
		inventory_items = []
		
		for item in all_items:
			var scene = load(item.scene).instantiate()
			scene.unique_id = item.unique_id
			scene.icon_path = item.icon_path
			scene.stackable = item.stackable
			scene.item_count = item.item_count
			scene.scene = item.scene
			
			get_parent().get_node("Items").add_child(scene)
			scene.global_position = global_position
			scene.global_position.y += 0.5
			scene.global_position += -global_transform.basis.z.normalized()
			
			Network.rpc(
				"_spawn_item", 
				scene.scene, scene.unique_id, 
				scene.icon_path, scene.stackable, 
				scene.item_count, scene.global_position,
				scene.name
			)
		
		# TODO: spawn loc or sum
		health = 100
		stamina = max_stamina
		speed = normal_speed
		
		global_position = Vector3(0, 10, 0)

func _play_item_anim(peer: int) -> void:
	if peer == name.to_int():
		if $Hold.get_child_count() == 1:
			$Hold/Item/AnimationPlayer.play("use")

func _set_holding(peer: int, scene: String) -> void:
	if is_multiplayer_authority() or peer != name.to_int(): 
		# is_multiplayer_authority() should be same as: if peer == multiplayer.get_unique_id()
		return
	
	for child in $Hold.get_children():
		child.free()
	
	if not scene or scene == "":
		return
	
	var node = load(scene).instantiate()
	node.name = "Item"
	
	$Hold.add_child(node)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if (
		event is InputEventMouseButton
		and not $"../CanvasLayer/Control/InventoryBG".visible
	):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * .1))
		
		$Camera3D.rotate_x(deg_to_rad(-event.relative.y * .1))
		$Camera3D.rotation.x = clamp($Camera3D.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func add_item_to_inv(item: BaseItem) -> bool:
	for slot in hotbar_items:
		if slot.unique_id == item.unique_id and item.stackable:
			slot.item_count += item.item_count
			return true
	
	if len(hotbar_items) == 5:
		for slot in inventory_items:
			if slot.unique_id == item.unique_id and item.stackable:
				slot.item_count += item.item_count
				return true
		
		if len(inventory_items) == 30:
			return false
		
		inventory_items.append(item)
	else:
		hotbar_items.append(item)
	
	return true

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Have this not inside the if not visible statement
	# so u still get stamina even if in pause menu cause it dosent actually pause
	if stamina < 100 and not Input.is_action_pressed("sprint"):
		stamina += 5 * delta
	
	if Input.is_action_just_pressed("pause"):
		if $"../CanvasLayer/Control/InventoryBG".visible:
			$"../CanvasLayer/Control/InventoryBG".hide()
		else:
			$"../CanvasLayer/Control/PauseMenu".visible = not $"../CanvasLayer/Control/PauseMenu".visible
			
			if $"../CanvasLayer/Control/PauseMenu".visible:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if not $"../CanvasLayer/Control/PauseMenu".visible: 
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		
		var input_dir := Input.get_vector("left", "right", "forward", "backwards")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
		
		if Input.is_action_pressed("sprint") and stamina > 0:
			speed = normal_speed * 1.5
			stamina -= 10 * delta
		else:
			speed = normal_speed
		
		if Input.is_action_just_released("interact") and $Camera3D/RayCast3D.is_colliding():
			var collider = $Camera3D/RayCast3D.get_collider()
			
			if collider is BaseItem:
				if add_item_to_inv(collider.duplicate()):
					Network.rpc("_despawn_item", collider.get_path())
		
		if Input.is_action_just_pressed("inventory"):
			$"../CanvasLayer/Control/InventoryBG".visible = not $"../CanvasLayer/Control/InventoryBG".visible
			
			if $"../CanvasLayer/Control/InventoryBG".visible:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	move_and_slide()
	
	$"../CanvasLayer/Control/StaminaBar".max_value = max_stamina
	$"../CanvasLayer/Control/StaminaBar".value = stamina
	$"../CanvasLayer/Control/HealthBar".value = health
	
	var item_to_hold: bool = false
	
	if Input.is_key_pressed(KEY_1): current_hotbar_slot = 1
	elif Input.is_key_pressed(KEY_2): current_hotbar_slot = 2
	elif Input.is_key_pressed(KEY_3): current_hotbar_slot = 3
	elif Input.is_key_pressed(KEY_4): current_hotbar_slot = 4
	elif Input.is_key_pressed(KEY_5): current_hotbar_slot = 5
	
	for hotbar_slot in $"../CanvasLayer/Control/Hotbar".get_children():
		if hotbar_slot.name != str(current_hotbar_slot):
			hotbar_slot.color = Color.from_hsv(0, 0, 0, 0.4)
		else:
			hotbar_slot.color = Color.from_hsv(0.6, 1, 1, 0.4)
		
		if len(hotbar_items) >= hotbar_slot.name.to_int():
			var item = hotbar_items[hotbar_slot.name.to_int() - 1]
			
			hotbar_slot.get_node("TextureRect").texture = item.icon
			
			hotbar_slot.get_node("ItemCount").text = str(
				item.item_count
			) if item.stackable else ""

			if item is ToolItem:
				hotbar_slot.get_node("Durability").value = item.durability
				hotbar_slot.get_node("Durability").show()
				
				if str(current_hotbar_slot) == hotbar_slot.name:
					item_to_hold = true
					
					if $Hold.get_child_count() == 0 or ($Hold/Item and $Hold/Item.unique_id != item.unique_id):
						var node = load(item.scene).instantiate()
						node.freeze = true
						
						for child in $Hold.get_children():
							child.free()
						
						node.name = "Item"
						node.damage = item.damage
						node.attacking_reduces_dur_by = item.attacking_reduces_dur_by
						node.type = item.type
						node.harvestable_damage = item.harvestable_damage	
						node.harvesting_reduces_dur_by = item.harvesting_reduces_dur_by
						$Hold.add_child(node)
						
						Network.rpc("_set_holding", multiplayer.get_unique_id(), item.scene)
			else:
				hotbar_slot.get_node("Durability").hide()
		else:
			hotbar_slot.get_node("TextureRect").texture = null
			hotbar_slot.get_node("ItemCount").text = ""
			hotbar_slot.get_node("Durability").hide()
	
	if not item_to_hold:
		for child in $Hold.get_children():
			child.queue_free()
		
		Network.rpc("_set_holding", multiplayer.get_unique_id(), "")
	
	if $"../CanvasLayer/Control/InventoryBG".visible:
		for inventory_slot in $"../CanvasLayer/Control/InventoryBG/Inventory/GridContainer".get_children():
			if len(inventory_items) >= inventory_slot.name.to_int():
				inventory_slot.get_node("TextureRect").texture = inventory_items[inventory_slot.name.to_int() - 1].icon
				
				inventory_slot.get_node("ItemCount").text = str(
					inventory_items[inventory_slot.name.to_int() - 1].item_count
				) if inventory_items[inventory_slot.name.to_int() - 1].stackable else ""
			else:
				inventory_slot.get_node("ItemCount").text = ""
		
		for val in Recipes.recipes:
			var recipe = Recipes.recipes[val]
			var reqs_met: int = 0
			var remove_that_are_not = ["1"]
			
			for material in recipe.requires:
				for item in hotbar_items:
					if item.unique_id == material and item.item_count >= recipe.requires[material]:
						reqs_met += 1
						break
				
				for inv_item in inventory_items:
					if inv_item.unique_id == material and inv_item.item_count >= recipe.requires[material]:
						reqs_met += 1
						break
			
			if reqs_met == len(recipe.requires):
				var node = $"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer/1".duplicate()
				node.get_node("TextureBtn").texture_normal = load(recipe.icon)
				node.get_node("TextureBtn").pressed.connect((func ():
					add_item_to_inv(load(recipe.scene).instantiate())
					
					for material in recipe.requires:
						for item in hotbar_items:
							if item.unique_id == material and item.item_count >= recipe.requires[material]:
								item.item_count -= recipe.requires[material]
								
								if item.item_count == 0:
									hotbar_items.erase(item)
						
						for item in inventory_items:
							for inv_item in hotbar_items:
								if inv_item.unique_id == material and inv_item.item_count >= recipe.requires[material]:
									inv_item.item_count -= recipe.requires[material]
									
									if inv_item.item_count == 0:
										hotbar_items.erase(inv_item)
				))
				node.get_node("ItemCount").text = str(recipe.amount)
				node.name = val
				
				remove_that_are_not.append(val)
				
				$"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer".add_child(node)
				node.show()
			
			for child in $"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer".get_children():
				if child.name not in remove_that_are_not:
					child.queue_free()
	
	if Input.is_action_just_pressed("drop"):
		if len(hotbar_items) >= current_hotbar_slot:
			var item = hotbar_items[current_hotbar_slot - 1]
			
			var slot = get_node(
				"../CanvasLayer/Control/Hotbar/%s" % current_hotbar_slot
			)
			
			if hotbar_items[current_hotbar_slot - 1].stackable:
				hotbar_items[current_hotbar_slot - 1].item_count -= 1
				
				if hotbar_items[current_hotbar_slot - 1].item_count <= 0:
					hotbar_items.remove_at(current_hotbar_slot - 1)
					slot.get_node("TextureRect").texture = null
					slot.get_node("ItemCount").text = ""
			else:
				hotbar_items.remove_at(current_hotbar_slot - 1)
				slot.get_node("TextureRect").texture = null
				slot.get_node("ItemCount").text = ""
			
			var scene = load(item.scene).instantiate()
			scene.unique_id = item.unique_id
			scene.icon_path = item.icon_path
			scene.stackable = item.stackable
			scene.item_count = item.item_count
			scene.scene = item.scene
			
			get_parent().get_node("Items").add_child(scene)
			scene.global_position = global_position
			scene.global_position.y += 0.5
			scene.global_position += -global_transform.basis.z.normalized()
			
			Network.rpc(
				"_spawn_item", 
				scene.scene, scene.unique_id, 
				scene.icon_path, scene.stackable, 
				scene.item_count, scene.global_position,
				scene.name
			)
