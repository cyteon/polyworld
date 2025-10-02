extends CharacterBody3D
 
const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var update_rate_hz: int = 20
var timer: float = 0.0

var last_rot_y: float = 0
var target_rot_y: float
var last_pos: Vector3 = Vector3.ZERO
var target_pos: Vector3

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))
	
	if multiplayer.get_unique_id() == int(name):
		$Camera3D.current = true
		position.y += 2
	else:
		Network.state_change.connect(func(bitmask: int, values: Array): 
			var i = 0
			
			if bitmask & (1 << 0):
				target_rot_y = values[i]
				i += 1
			if bitmask & (1 << 1):
				target_pos = values[i]
		)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	if Input.is_key_pressed(KEY_ESCAPE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseButton:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * .1))
		
		$Camera3D.rotate_x(deg_to_rad(-event.relative.y * .1))
		$Camera3D.rotation.x = clamp($Camera3D.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		if target_pos:
			position = position.lerp(target_pos, delta * 10)
		if target_rot_y:
			rotation.y = lerpf(rotation.y, target_rot_y, delta * 10)
		
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	timer += delta
	if timer >= 1.0 / update_rate_hz:
		timer = 0
		
		var bitmask = 0
		var values = []
	
		if rotation.y != last_rot_y:
			bitmask |= 1 << 0
			values.append(rotation.y)
			#last_rot_y = rotation.y
		if position != last_pos:
			bitmask |= 1 << 1
			values.append(position)
			#last_pos = position
		
		if values.size() > 0:
			Network.rpc("_state_change", bitmask, values)
