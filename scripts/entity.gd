extends CharacterBody3D

@export var speed: int = 1
@export var run_speed: int = 3

@export var health: int = 50
@export var target_pos: Vector3 = Vector3.ZERO

@export var drops_scene: String = "res://scenes/items/raw_meat.tscn"

@export var drops_min: int = 1
@export var drops_max: int = 3

@onready var nav_region: NavigationRegion3D = $"../../NavigationRegion3D"

var navigation_started: bool = false

func _ready() -> void:
	set_multiplayer_authority(1)
	
	if is_multiplayer_authority():
		actor_setup.call_deferred()

func damage(damage_: int) -> void:
	health -= damage_
	
	if health <= 0:
		for i in range(randi_range(drops_min, drops_max)):
			var item: ConsumableItem = load(drops_scene).instantiate()
			
			get_parent().get_parent().get_node("Items").add_child(item)
			item.global_position = global_position
			Util.set_owner_recursive(item, item)
			
			var p = PackedScene.new()
			p.pack(item)

			Network.rpc(
				"_spawn_item",
				var_to_bytes_with_objects(p),
				item.name
			)

		Network.rpc(
			"_despawn_item",
			get_path()
		)

		queue_free()

func actor_setup() -> void:
	await get_tree().create_timer(1).timeout
	
	$NavigationAgent3D.target_position = NavigationServer3D.map_get_random_point(
		nav_region.get_navigation_map(), 1, true
	)
	
	print($NavigationAgent3D.target_position)
	
	$NavigationAgent3D.target_desired_distance = 1.0
	
	#$NavigationAgent3D.waypoint_reached.connect(func (details):
	#	print(details) # for debugging
	#)
	
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
		
		if global_position != $NavigationAgent3D.get_next_path_position():
			# there is one axis we cant modify cause it breaks shitw
			look_at($NavigationAgent3D.get_next_path_position())

	elif navigation_started:
		$NavigationAgent3D.target_position = NavigationServer3D.map_get_random_point(
			nav_region.get_navigation_map(), 1, true
		)
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	move_and_slide()
	target_pos = global_position
