extends CharacterBody3D

var normal_speed: float = 5.0
var speed: float = normal_speed
const JUMP_VELOCITY: float = 4.5

var health: int = 100

var max_stamina: int = 100
var stamina: float = max_stamina
var sprinting: bool = false

var current_hotbar_slot: int = 1
var hotbar_items: Array[BaseItem] = []
var inventory_items: Array[BaseItem] = []

func _ready() -> void:
	if is_multiplayer_authority():
		$MultiplayerSynchronizer.set_multiplayer_authority(name.to_int())
	else:
		Network.rpc_id(name.to_int(), "_ready_to_send_to", multiplayer.get_unique_id())
	
	#var a = BaseItem.new(); a.unique_id = "a"
	#var b = BaseItem.new(); b.unique_id = "b"
	#var c = BaseItem.new(); c.unique_id = "c"
	#var d = BaseItem.new(); d.unique_id = "d"
	#var e = BaseItem.new(); e.unique_id = "e"
	#hotbar_items = [a, b, c, d, e]

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if event is InputEventMouseButton:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * .1))
		
		$Camera3D.rotate_x(deg_to_rad(-event.relative.y * .1))
		$Camera3D.rotation.x = clamp($Camera3D.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func add_item_to_inv(item: BaseItem) -> bool:
	for slot in hotbar_items:
		if slot.unique_id == item.unique_id and item.stackable:
			slot.item_count += 1
			return true
	
	if len(hotbar_items) == 5:
		for slot in inventory_items:
			if slot.unique_id == item.unique_id and item.stackable:
				slot.item_count += 1
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
	
	# Have this so u still get stamina even if in pause menu cause it dosent actually pause
	if stamina < 100 and not Input.is_action_pressed("sprint"):
		stamina += 5 * delta

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
				var item = BaseItem.new()
				item.unique_id = collider.unique_id
				item.icon = collider.icon
				item.stackable = collider.stackable
				item.item_count = collider.item_count
				item.scene = collider.scene
				
				if add_item_to_inv(item):
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
	
	for hotbar_slot in $"../CanvasLayer/Control/Hotbar".get_children():
		if hotbar_slot.name != str(current_hotbar_slot):
			hotbar_slot.color = Color.from_hsv(0, 0, 0, 0.4)
		else:
			hotbar_slot.color = Color.from_hsv(0.6, 1, 1, 0.4)
		
		if len(hotbar_items) >= hotbar_slot.name.to_int():
			hotbar_slot.get_node("TextureRect").texture = hotbar_items[hotbar_slot.name.to_int() - 1].icon
			
			hotbar_slot.get_node("ItemCount").text = str(
				hotbar_items[hotbar_slot.name.to_int() - 1].item_count
			) if hotbar_items[hotbar_slot.name.to_int() - 1].stackable else ""
		else:
			hotbar_slot.get_node("ItemCount").text = ""
	
	for inventory_slot in $"../CanvasLayer/Control/InventoryBG/Inventory/GridContainer".get_children():
		if len(inventory_items) >= inventory_slot.name.to_int():
			inventory_slot.get_node("TextureRect").texture = inventory_items[inventory_slot.name.to_int() - 1].icon
			
			inventory_slot.get_node("ItemCount").text = str(
				inventory_items[inventory_slot.name.to_int() - 1].item_count
			) if inventory_items[inventory_slot.name.to_int() - 1].stackable else ""
		else:
			inventory_slot.get_node("ItemCount").text = ""
	
	if Input.is_key_pressed(KEY_1): current_hotbar_slot = 1
	elif Input.is_key_pressed(KEY_2): current_hotbar_slot = 2
	elif Input.is_key_pressed(KEY_3): current_hotbar_slot = 3
	elif Input.is_key_pressed(KEY_4): current_hotbar_slot = 4
	elif Input.is_key_pressed(KEY_5): current_hotbar_slot = 5
	
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
				slot.get_node("TextureRect").textur = null
				slot.get_node("ItemCount").text = ""
			
			var scene = load(item.scene).instantiate()
			scene.unique_id = item.unique_id
			scene.icon = item.icon
			scene.stackable = item.stackable
			scene.item_count = item.item_count
			scene.scene = item.scene
			
			get_parent().get_node("Items").add_child(scene)
			scene.global_position = global_position
			scene.global_position.y += 0.5
			scene.global_position += -global_transform.basis.z.normalized()
