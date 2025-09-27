extends Node3D

# Reference to the pumpkin scene (we'll load it dynamically)
var pumpkin_scene: PackedScene

# Timer for spawning pumpkins
var spawn_timer: Timer

# Spawn area boundaries (adjust these to fit your scene)
var spawn_area_min = Vector3(-5, -2, 0)
var spawn_area_max = Vector3(5, -2, 0)

# Cleanup threshold - remove pumpkins below this Y position
var cleanup_threshold = -10.0

# Lightning effect variables
var lightning_timer: Timer
var light_node: OmniLight3D
var original_light_energy: float
var lightning_active = false

# Thunder sound variables
var thunder_audio: AudioStreamPlayer3D
var thunder_sounds: Array[AudioStream] = []

# Pumpkin splitting variables
var pumpkin_bottom_scene: PackedScene
var pumpkin_top_scene: PackedScene
var pumpkin_left_scene: PackedScene
var pumpkin_right_scene: PackedScene
var camera: Camera3D


func _ready():
	# Load the pumpkin scene
	pumpkin_scene = load("res://assets/models/firstpumpkin.blend")
	
	# Get reference to the light node
	light_node = get_node("OmniLight3D")
	original_light_energy = light_node.light_energy
	
	# Get reference to the thunder audio player
	thunder_audio = get_node("ThunderAudio")
	
	# Load all thunder sound files
	load_thunder_sounds()
	
	# Load pumpkin part scenes
	pumpkin_bottom_scene = load("res://assets/models/firstpumpkinbottom.blend")
	pumpkin_top_scene = load("res://assets/models/firstpumpkintop.blend")
	pumpkin_left_scene = load("res://assets/models/firstpumpkinleft.blend")
	pumpkin_right_scene = load("res://assets/models/firstpumpkinright.blend")
	
	# Get camera reference for mouse picking
	camera = get_node("Camera3D")
	
	# Create and configure the spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 5.0  # 5 seconds
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.autostart = true
	add_child(spawn_timer)
	
	# Create and configure the lightning timer
	lightning_timer = Timer.new()
	lightning_timer.wait_time = randf_range(2.0, 8.0)  # Random interval between lightning strikes
	lightning_timer.timeout.connect(_on_lightning_timer_timeout)
	lightning_timer.autostart = true
	add_child(lightning_timer)
	
	# Spawn the first pumpkin immediately
	spawn_pumpkin()

func _process(delta):
	# Clean up pumpkins that have fallen below the threshold
	cleanup_fallen_pumpkins()
	
	# Handle mouse input for pumpkin splitting
	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		print("Mouse clicked!")
		handle_mouse_click()

func _on_spawn_timer_timeout():
	spawn_pumpkin()

func spawn_pumpkin():
	if pumpkin_scene == null:
		print("Pumpkin scene not loaded!")
		return
	
	# Create a RigidBody3D to hold the pumpkin
	var pumpkin_body = RigidBody3D.new()
	
	# Create a new pumpkin instance
	var pumpkin_instance = pumpkin_scene.instantiate()
	
	# Generate random position within spawn area
	var random_x = randf_range(spawn_area_min.x, spawn_area_max.x)
	var random_z = randf_range(spawn_area_min.z, spawn_area_max.z)
	var spawn_position = Vector3(random_x, spawn_area_min.y, random_z)
	
	# Set the pumpkin position
	pumpkin_body.position = spawn_position
	
	# Add some random rotation for variety
	var random_rotation = Vector3(
		randf_range(0, 2 * PI),
		randf_range(0, 2 * PI),
		randf_range(0, 2 * PI)
	)
	pumpkin_body.rotation = random_rotation
	
	# Add the pumpkin model as a child of the RigidBody3D
	pumpkin_body.add_child(pumpkin_instance)
	
	# Add collision shape to the pumpkin
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 1.0)  # Adjust size to match your pumpkin
	collision_shape.shape = box_shape
	pumpkin_body.add_child(collision_shape)
	
	# Configure physics properties
	pumpkin_body.mass = 1.0  # Mass of the pumpkin
	pumpkin_body.gravity_scale = 1.0  # Affected by gravity
	
	# Add upward velocity with some randomness
	var upward_force = randf_range(10.0, 15.0)  # Random upward velocity
	var horizontal_force_x = randf_range(-2.0, 2.0)  # Random horizontal velocity
	var horizontal_force_z = randf_range(-2.0, 2.0)  # Random horizontal velocity
	
	var initial_velocity = Vector3(horizontal_force_x, upward_force, horizontal_force_z)
	pumpkin_body.linear_velocity = initial_velocity
	
	# Add some random angular velocity for spinning
	var angular_velocity = Vector3(
		randf_range(-5.0, 5.0),
		randf_range(-5.0, 5.0),
		randf_range(-5.0, 5.0)
	)
	pumpkin_body.angular_velocity = angular_velocity
	
	# Mark this as an original pumpkin (not a split part)
	pumpkin_body.set_meta("is_original_pumpkin", true)
	
	# Add the pumpkin body to the scene
	add_child(pumpkin_body)
	
	print("Spawned pumpkin at position: ", spawn_position, " with velocity: ", initial_velocity)

func cleanup_fallen_pumpkins():
	# Get all RigidBody3D children (our pumpkin bodies and parts)
	var children = get_children()
	for child in children:
		if child is RigidBody3D:
			# Check if the pumpkin or pumpkin part has fallen below the threshold
			if child.position.y < cleanup_threshold:
				print("Removing fallen pumpkin/part at position: ", child.position)
				child.queue_free()  # Remove the pumpkin/part from the scene

func _on_lightning_timer_timeout():
	if not lightning_active:
		trigger_lightning()

func trigger_lightning():
	lightning_active = true
	print("Lightning strike!")
	
	# Play thunder sound
	play_thunder_sound()
	
	# Create a sequence of lightning flashes
	create_lightning_sequence()

func create_lightning_sequence():
	# First flash - bright and quick
	light_node.light_energy = original_light_energy * 10.0
	light_node.light_color = Color.WHITE
	
	# Schedule the next flash after a short delay
	await get_tree().create_timer(0.1).timeout
	
	# Second flash - slightly dimmer
	light_node.light_energy = original_light_energy * 4.5
	light_node.light_color = Color(0.9, 0.9, 1.0)  # Slightly blue tint
	
	await get_tree().create_timer(0.05).timeout
	
	# Third flash - even dimmer
	light_node.light_energy = original_light_energy * 2.0
	light_node.light_color = Color(0.8, 0.8, 1.0)
	
	await get_tree().create_timer(0.1).timeout
	
	# Fade back to normal
	light_node.light_energy = original_light_energy
	light_node.light_color = Color(0.941224, 0.904753, 0.916239, 1)  # Original color
	
	# Reset lightning state and set next random interval
	lightning_active = false
	lightning_timer.wait_time = randf_range(3.0, 10.0)  # Random interval for next lightning
	lightning_timer.start()

func load_thunder_sounds():
	# Load all available thunder sound files
	var thunder_files = ["res://sounds/thunder.mp3", "res://sounds/thunder2.mp3", "res://sounds/thunder3.mp3"]
	
	for file_path in thunder_files:
		var thunder_sound = load(file_path)
		if thunder_sound != null:
			thunder_sounds.append(thunder_sound)
			print("Loaded thunder sound: ", file_path)
		else:
			print("Could not load thunder sound: ", file_path)
	
	if thunder_sounds.size() == 0:
		print("No thunder sound files found!")

func play_thunder_sound():
	if thunder_sounds.size() > 0:
		# Select a random thunder sound
		var random_thunder = thunder_sounds[randi() % thunder_sounds.size()]
		thunder_audio.stream = random_thunder
		
		# Add some randomness to the thunder timing (slight delay after lightning)
		var thunder_delay = randf_range(0.1, 0.5)
		await get_tree().create_timer(thunder_delay).timeout
		
		# Play the thunder sound
		thunder_audio.play()
		
		# Add some pitch and volume variation for variety
		thunder_audio.pitch_scale = randf_range(0.8, 1.2)
		thunder_audio.volume_db = randf_range(-5.0, 10.0)
	else:
		print("No thunder sound files available!")

func handle_mouse_click():
	# Get mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Create a ray from camera through mouse position
	var space_state = get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	# Perform raycast
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_object = result.collider
		print("Hit object: ", hit_object.name, " Type: ", hit_object.get_class())
		# Check if we hit an original pumpkin (RigidBody3D with the meta tag)
		if hit_object is RigidBody3D and hit_object.has_meta("is_original_pumpkin"):
			print("Hit original pumpkin! Splitting...")
			split_pumpkin(hit_object, result.position)
		elif hit_object is RigidBody3D:
			print("Hit pumpkin part, not splitting")
		else:
			print("Hit something else, not a pumpkin")
	else:
		print("No hit detected")

func split_pumpkin(pumpkin_body: RigidBody3D, hit_position: Vector3):
	# Check if all pumpkin part scenes are loaded
	if pumpkin_bottom_scene == null or pumpkin_top_scene == null or pumpkin_left_scene == null or pumpkin_right_scene == null:
		print("Pumpkin part scenes not loaded!")
		return
	
	# Get the pumpkin's current position and velocity
	var pumpkin_pos = pumpkin_body.global_position
	var pumpkin_vel = pumpkin_body.linear_velocity
	var pumpkin_ang_vel = pumpkin_body.angular_velocity
	
	# Randomly choose between top/bottom or left/right splitting
	var split_vertically = randf() < 0.5  # 50% chance
	
	if split_vertically:
		# Split into top and bottom
		create_pumpkin_part(pumpkin_bottom_scene, pumpkin_pos + Vector3(0, -0.3, 0), pumpkin_vel + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), pumpkin_ang_vel)
		create_pumpkin_part(pumpkin_top_scene, pumpkin_pos + Vector3(0, 0.3, 0), pumpkin_vel + Vector3(randf_range(-2, 2), 2, randf_range(-2, 2)), pumpkin_ang_vel)
		print("Pumpkin split into top and bottom parts!")
	else:
		# Split into left and right
		create_pumpkin_part(pumpkin_left_scene, pumpkin_pos + Vector3(-0.3, 0, 0), pumpkin_vel + Vector3(-2, randf_range(-1, 1), randf_range(-2, 2)), pumpkin_ang_vel)
		create_pumpkin_part(pumpkin_right_scene, pumpkin_pos + Vector3(0.3, 0, 0), pumpkin_vel + Vector3(2, randf_range(-1, 1), randf_range(-2, 2)), pumpkin_ang_vel)
		print("Pumpkin split into left and right parts!")
	
	# Remove the original pumpkin
	pumpkin_body.queue_free()

func create_pumpkin_part(scene: PackedScene, position: Vector3, velocity: Vector3, angular_velocity: Vector3):
	# Create the pumpkin part body
	var part_body = RigidBody3D.new()
	var part_instance = scene.instantiate()
	part_body.add_child(part_instance)
	
	# Set position and physics
	part_body.global_position = position
	part_body.linear_velocity = velocity
	part_body.angular_velocity = angular_velocity
	part_body.mass = 0.5
	part_body.gravity_scale = 1.0
	
	# Add collision shape
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.5, 1.0, 1.0)  # Adjusted for left/right parts
	collision.shape = box
	part_body.add_child(collision)
	
	# Add to scene
	add_child(part_body)
