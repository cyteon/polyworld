extends CharacterBody3D

@export var speed: int = 1
@export var run_speed: int = 3

@export var health: int = 50
@export var target_pos: Vector3 = Vector3.ZERO

@onready var nav_region: NavigationRegion3D = $"../../NavigationRegion3D"

var navigation_started: bool = false

func _ready() -> void:
	set_multiplayer_authority(1)
	
	if is_multiplayer_authority():
		actor_setup.call_deferred()

func actor_setup() -> void:
	await get_tree().physics_frame
	
	$NavigationAgent3D.target_position = NavigationServer3D.map_get_random_point(
		nav_region.get_navigation_map(), 1, true
	)
	
	$NavigationAgent3D.target_desired_distance = 1.0
	
	$NavigationAgent3D.waypoint_reached.connect(func (details):
		print(details)
	)
	
	navigation_started = true

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		if target_pos != Vector3.ZERO:
			position = position.lerp(target_pos, delta * 10)
		
		# to prevent large delay
		if target_pos.distance_to(position) > 2:
			position = target_pos
		
		return
	
	if not $NavigationAgent3D.is_navigation_finished():
		velocity = global_position.direction_to(
			$NavigationAgent3D.get_next_path_position()
		) * speed
		
		look_at($NavigationAgent3D.get_next_path_position())
	elif navigation_started:
		$NavigationAgent3D.target_position = NavigationServer3D.map_get_random_point(
			nav_region.get_navigation_map(), 1, true
		)
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	move_and_slide()
	target_pos = global_position
