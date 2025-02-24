extends CharacterBody3D

var normal_speed: float = 5.0
var speed: float = normal_speed
const JUMP_VELOCITY: float = 4.5

var health: int = 100

var max_stamina: int = 100
var stamina: float = max_stamina
var sprinting: bool = false

func _ready() -> void:
	if is_multiplayer_authority():
		$MultiplayerSynchronizer.set_multiplayer_authority(name.to_int())

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
		
		if Input.is_action_pressed("sprint") && stamina > 0:
			speed = normal_speed * 1.5
			stamina -= 10 * delta
		else:
			speed = normal_speed
			
			if stamina < 100:
				stamina += 5 * delta

	move_and_slide()
	
	$"../CanvasLayer/Control/StaminaBar".max_value = max_stamina
	$"../CanvasLayer/Control/StaminaBar".value = stamina
	$"../CanvasLayer/Control/HealthBar".value = health
