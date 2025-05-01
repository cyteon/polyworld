extends CharacterBody3D

const JUMP_VELOCITY: float = 4.5

var normal_speed: float = 5.0
var speed: float = normal_speed

# the ones with @export is to expose to synchronizers
@export var health: int = 100
var standard_health_regen_rate: float = .4
# when regenerating it will remove this in addition to standard
var health_hunger_extra_reduction: float = .3

var max_stamina: int = 100
@export var stamina: float = max_stamina

@export var hunger: float = 100
var standard_hunger_reduction: float = .4
var fast_hunger_reduction: float = .6

var current_hotbar_slot: int = 1
var hotbar_items: Array[BaseItem] = []
var inventory_items: Array[BaseItem] = []

@export var target_pos: Vector3 = Vector3.ZERO

var enable_chat: bool = not Settings.config.get_value("multiplayer", "disable_chat", false)

func _ready() -> void:
	if is_multiplayer_authority():
		Network.take_damage.connect(_take_damage)
		Network.set_state.connect(_set_state)
	else:
		Network.rpc_id(name.to_int(), "_ready_to_send_to", multiplayer.get_unique_id())
		Network.set_holding.connect(_set_holding)
		Network.play_item_anim.connect(_play_item_anim)
	
	target_pos = global_position

func _set_state(pos: Vector3, health_: int, stamina_: float, hunger_: float, hotbar: PackedByteArray, inventory: PackedByteArray) -> void:
	global_position = pos if pos != Vector3(0, 0, 0) else $"../SpawnLoc".global_position
	health = health_
	stamina = stamina_
	hunger = hunger_
	
	hotbar_items = []
	inventory_items = []
	
	var h = bytes_to_var_with_objects(hotbar)
	var v = bytes_to_var_with_objects(inventory)
	
	if h:
		for h_item in h:
			var item = h_item.instantiate()
			hotbar_items.append(item)
	
	if v:
		for i_item in v:
			var item = i_item.instantiate()
			inventory_items.append(item)
	
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
			
			
			Util.set_owner_recursive(scene, scene)
			
			Network.rpc(
				"_spawn_item", 
				var_to_bytes_with_objects(scene),
				scene.name
			)
		
		# TODO: spawn loc or sum
		health = 100
		stamina = max_stamina
		speed = normal_speed
		
		global_position = $"../SpawnLoc".global_position

func _play_item_anim(peer: int) -> void:
	if peer == name.to_int():
		if $Hold.get_child_count() == 1:
			$Hold/Item/AnimationPlayer.play("use")

func _set_holding(peer: int, scene: String) -> void:
	if peer != multiplayer.get_remote_sender_id() and peer != 1:
		print("[Client] Denied 'set_holding' packet due to mismatch in peer ID")
		
	if is_multiplayer_authority() or peer != name.to_int(): 
		# is_multiplayer_authority() should be same as: if peer == multiplayer.get_unique_id()
		return
	
	for child in $Hold.get_children():
		child.free()
	
	if not scene or scene == "":
		return
	
	var node = load(scene).instantiate()
	node.name = "Item"
	node.freeze = true
	
	$Hold.add_child(node)

func is_blocking_ui_visible() -> bool:
	if $"../CanvasLayer/Control/InventoryBG".visible:
		return true
	
	if $"../CanvasLayer/Control/PauseMenu".visible:
		return true
	
	if $"../CanvasLayer/Control/Chatbox/Input/LineEdit".has_focus():
		return true
	
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if event is InputEventMouseButton and not $"../CanvasLayer/Control/InventoryBG".visible:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event.is_action_pressed("chat") and enable_chat and not is_blocking_ui_visible():
		$"../CanvasLayer/Control/Chatbox/Input/LineEdit".grab_focus()
	
	if event is InputEventMouseMotion and not is_blocking_ui_visible():
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
		if target_pos != Vector3.ZERO:
			position = position.lerp(target_pos, delta * 10)
		
		# to prevent large delay
		if target_pos.distance_to(position) > 2:
			position = target_pos
		
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Have this not inside the if not visible statement
	# so u still get stamina even if in pause menu cause it dosent actually pause
	if stamina < 100 and not Input.is_action_pressed("sprint"):
		stamina += 5 * delta
		hunger -= delta * fast_hunger_reduction
	else:
		hunger -= delta * standard_hunger_reduction
	
	if Input.is_action_just_pressed("pause"):
		if $"../CanvasLayer/Control/InventoryBG".visible:
			$"../CanvasLayer/Control/InventoryBG".hide()
		elif $"../CanvasLayer/Control/Chatbox/Input/LineEdit".has_focus():
			$"../CanvasLayer/Control/Chatbox/Input/LineEdit".release_focus()
		else:
			$"../CanvasLayer/Control/PauseMenu".visible = not $"../CanvasLayer/Control/PauseMenu".visible
			
			if $"../CanvasLayer/Control/PauseMenu".visible:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if not is_blocking_ui_visible():
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
		
		if Input.is_action_pressed("sprint") and stamina > 0 and velocity:
			speed = normal_speed * 1.5
			
			if velocity != Vector3.ZERO:
				stamina -= 10 * delta
		else:
			speed = normal_speed
		
		if Input.is_action_just_released("interact") and $Camera3D/RayCast3D.is_colliding():
			var collider = $Camera3D/RayCast3D.get_collider()
			
			if collider is BaseItem:
				if add_item_to_inv(collider.duplicate()):
					Network.rpc("_despawn_item", collider.get_path())
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	if Input.is_action_just_pressed("inventory") and (
		not $"../CanvasLayer/Control/PauseMenu".visible
		and not $"../CanvasLayer/Control/Chatbox/Input/LineEdit".has_focus()
	):
		$"../CanvasLayer/Control/InventoryBG".visible = not $"../CanvasLayer/Control/InventoryBG".visible
			
		if $"../CanvasLayer/Control/InventoryBG".visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	move_and_slide()
	target_pos = global_position
	
	#$"../CanvasLayer/Control/StaminaBar".max_value = max_stamina
	$"../CanvasLayer/Control/StaminaBar".value = stamina
	$"../CanvasLayer/Control/HealthBar".value = health
	$"../CanvasLayer/Control/HungerBar".value = hunger
	
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
			
			hotbar_slot.get_node("TextureRect").texture = load(item.icon_path)
			
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
			elif item is ConsumableItem:
				if str(current_hotbar_slot) == hotbar_slot.name:
					item_to_hold = true
					
					if $Hold.get_child_count() == 0 or ($Hold/Item and $Hold/Item.unique_id != item.unique_id):
						var node = hotbar_items[current_hotbar_slot - 1].duplicate()
						node.name = "Item"
						
						for child in $Hold.get_children():
							child.free()
						
						$Hold.add_child(node)
						
						Network.rpc("_set_holding", multiplayer.get_unique_id(), item.scene)
			else:
				hotbar_slot.get_node("Durability").hide()
		else:
			hotbar_slot.get_node("TextureRect").texture = null
			hotbar_slot.get_node("ItemCount").text = ""
			hotbar_slot.get_node("Durability").hide()
	
	if not item_to_hold:
		if $Hold.get_child_count() != 0:
			Network.rpc("_set_holding", multiplayer.get_unique_id(), "")
		
		for child in $Hold.get_children():
			child.queue_free()
	
	if $"../CanvasLayer/Control/InventoryBG".visible:
		for inventory_slot in $"../CanvasLayer/Control/InventoryBG/Inventory/GridContainer".get_children():
			if len(inventory_items) >= inventory_slot.name.to_int():
				inventory_slot.get_node("TextureRect").texture = load(inventory_items[inventory_slot.name.to_int() - 1].icon_path)
				
				inventory_slot.get_node("ItemCount").text = str(
					inventory_items[inventory_slot.name.to_int() - 1].item_count
				) if inventory_items[inventory_slot.name.to_int() - 1].stackable else ""
			else:
				inventory_slot.get_node("ItemCount").text = ""
		
		var remove_that_are_not = ["1"]
		
		for val in Recipes.recipes:
			var recipe = Recipes.recipes[val]
			var reqs_met: int = 0
			
			for material in recipe.requires:
				for item in hotbar_items:
					if item.unique_id == material and item.item_count >= recipe.requires[material].amount:
						reqs_met += 1
						break
				
				for inv_item in inventory_items:
					if inv_item.unique_id == material and inv_item.item_count >= recipe.requires[material].amount:
						reqs_met += 1
						break
			
			if reqs_met == len(recipe.requires):
				if $"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer".has_node(val):
					if $"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer".get_node("%s/CantCraft" % val).visible == true:
						$"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer".get_node(val).free()
				
				var node = $"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer/1".duplicate()
				node.get_node("TextureBtn").texture_normal = load(recipe.icon)
				
				node.get_node("TextureBtn").pressed.connect((func ():
					add_item_to_inv(load(recipe.scene).instantiate())
					
					for material in recipe.requires:
						for item in hotbar_items:
							if item.unique_id == material and item.item_count >= recipe.requires[material].amount:
								item.item_count -= recipe.requires[material].amount
								
								if item.item_count == 0:
									hotbar_items.erase(item)
						
						for inv_item in inventory_items:
							if inv_item.unique_id == material and inv_item.item_count >= recipe.requires[material].amount:
								inv_item.item_count -= recipe.requires[material].amount
								
								if inv_item.item_count == 0:
									inventory_items.erase(inv_item)
				))
				
				node.get_node("TextureBtn").mouse_entered.connect(func():
					$"../CanvasLayer/Control/InventoryBG/Crafting/Detail".show()
					$"../CanvasLayer/Control/InventoryBG/Crafting/Detail/VBoxContainer/Label".text = "Recipe: %s" % recipe.name
					$"../CanvasLayer/Control/InventoryBG/Crafting/Detail/VBoxContainer/Gives".text = "%s * %s\n" % [recipe.gives, recipe.amount]
					
					var list = ""
					
					for material in recipe.requires:
						list += "- %s * %s" % [recipe.requires[material].label, recipe.requires[material].amount]
					
					$"../CanvasLayer/Control/InventoryBG/Crafting/Detail/VBoxContainer/Requires".text = "Requires:\n%s" % list
				)
				
				node.get_node("TextureBtn").mouse_exited.connect(func():
					$"../CanvasLayer/Control/InventoryBG/Crafting/Detail".hide()
				)
				
				node.get_node("ItemCount").text = str(recipe.amount)
				node.name = val
				
				remove_that_are_not.append(val)
				
				$"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer".add_child(node)
				node.show()
			elif $"../CanvasLayer/Control/InventoryBG/Crafting/CheckBox".button_pressed:
				if $"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer".has_node(val):
					if $"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer".get_node("%s/CantCraft" % val).visible == false:
						$"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer".get_node(val).free()
				
				var node = $"../CanvasLayer/Control/InventoryBG/Crafting/ScrollContainer/GridContainer/1".duplicate()
				node.get_node("TextureBtn").texture_normal = load(recipe.icon)
				node.get_node("TextureBtn").disabled = true
				node.get_node("CantCraft").show()
				node.name = val
				
				node.get_node("CantCraft").mouse_entered.connect(func():
					$"../CanvasLayer/Control/InventoryBG/Crafting/Detail".show()
					$"../CanvasLayer/Control/InventoryBG/Crafting/Detail/VBoxContainer/Label".text = "Recipe: %s" % recipe.name

					$"../CanvasLayer/Control/InventoryBG/Crafting/Detail/VBoxContainer/Gives".text = "%s * %s\n" % [recipe.gives, recipe.amount]
					
					var list = ""
					
					for material in recipe.requires:
						list += "- %s * %s" % [recipe.requires[material].label, recipe.requires[material].amount]
					
					$"../CanvasLayer/Control/InventoryBG/Crafting/Detail/VBoxContainer/Requires".text = "Requires:\n%s" % list
				)
				
				node.get_node("CantCraft").mouse_exited.connect(func():
					$"../CanvasLayer/Control/InventoryBG/Crafting/Detail".hide()
				)
				
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
			
			var i = item.duplicate()
			i.item_count = 1
			
			get_parent().get_node("Items").add_child(i)
			i.global_position = global_position
			i.global_position.y += 0.5
			i.global_position += -global_transform.basis.z.normalized()
					
			for c in i.get_children():
				c.owner = i
			
			var p = PackedScene.new()
			p.pack(i)
			
			Network.rpc(
				"_spawn_item", 
				var_to_bytes_with_objects(p),
				i.name
			)

func _on_send_data_to_save_timeout() -> void:
	var encoded_hotbar = []
	var encoded_inv = []
	
	for h_item in hotbar_items:
		var item = h_item.duplicate()
		for c in item.get_children():
			c.owner = item
		
		var new = PackedScene.new()
		new.pack(item)
		encoded_hotbar.append(new)
	
	for i_item in inventory_items:
		var item = i_item.duplicate()
		for c in item.get_children():
			c.owner = item
		
		var new = PackedScene.new()
		new.pack(item)
		encoded_inv.append(new)
	
	Network.rpc_id(
		1,
		"_inv_data",
		var_to_bytes_with_objects(encoded_hotbar),
		var_to_bytes_with_objects(encoded_inv)
	)
