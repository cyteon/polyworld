extends CharacterBody3D

var normal_speed: float = 5.0
var speed: float = normal_speed
const JUMP_VELOCITY: float = 4.5

var health: int = 100

var max_stamina: int = 100
var stamina: float = max_stamina
var sprinting: bool = false

# temp
var stone = BaseItem.new()

var current_hotbar_slot: int = 1
var hotbar_items: Array[BaseItem] = [stone]

func _ready() -> void:
	if is_multiplayer_authority():
		$MultiplayerSynchronizer.set_multiplayer_authority(name.to_int())
	else:
		Network.rpc_id(name.to_int(), "_ready_to_send_to", multiplayer.get_unique_id())

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

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Have this so u still get stamina even if in pause menu cause it dosent actually paulse
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
	
	if Input.is_key_pressed(KEY_1): current_hotbar_slot = 1
	elif Input.is_key_pressed(KEY_2): current_hotbar_slot = 2
	elif Input.is_key_pressed(KEY_3): current_hotbar_slot = 3
	elif Input.is_key_pressed(KEY_4): current_hotbar_slot = 4
	elif Input.is_key_pressed(KEY_5): current_hotbar_slot = 5
