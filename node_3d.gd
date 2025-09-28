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

# Skull spawning variables
var skull_scene: PackedScene
var skull_spawn_timer: Timer

# Game state variables
var game_started = false
var score = 0
var score_goal = 100
var level = 1
var time_remaining = 60.0

# UI references
var game_start_button: Button
var score_label: Label
var score_goal_label: Label
var level_label: Label
var timer_label: Label
var game_over_label: Label

# Timer variables
var game_timer: Timer


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
	
	# Load skull scene
	skull_scene = load("res://assets/models/Skull.blend")
	
	# Get camera reference for mouse picking
	camera = get_node("Camera3D")
	
	# Get UI references
	game_start_button = get_node("UI/GameStartButton")
	score_label = get_node("UI/ScoreLabel")
	score_goal_label = get_node("UI/ScoreGoalLabel")
	level_label = get_node("UI/LevelLabel")
	timer_label = get_node("UI/TimerLabel")
	game_over_label = get_node("UI/GameOverLabel")
	
	# Connect the game start button
	game_start_button.pressed.connect(_on_game_start_button_pressed)
	
	# Initialize UI
	update_ui()
	
	# Create and configure the spawn timer (don't start until game begins)
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 5.0  # 5 seconds
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.autostart = false  # Don't start until game begins
	add_child(spawn_timer)
	
	# Create and configure the skull spawn timer (don't start until game begins)
	skull_spawn_timer = Timer.new()
	skull_spawn_timer.wait_time = randf_range(5.0, 10.0)  # Random 5-10 seconds
	skull_spawn_timer.timeout.connect(_on_skull_spawn_timer_timeout)
	skull_spawn_timer.autostart = false  # Don't start until game begins
	add_child(skull_spawn_timer)
	
	# Create and configure the lightning timer
	lightning_timer = Timer.new()
	lightning_timer.wait_time = randf_range(2.0, 8.0)  # Random interval between lightning strikes
	lightning_timer.timeout.connect(_on_lightning_timer_timeout)
	lightning_timer.autostart = true
	add_child(lightning_timer)
	
	# Create and configure the game timer (for countdown)
	game_timer = Timer.new()
	game_timer.wait_time = 1.0  # Update every second
	game_timer.timeout.connect(_on_game_timer_timeout)
	game_timer.autostart = false  # Don't start until game begins
	add_child(game_timer)
	
	# Don't spawn anything until game starts

func _process(delta):
	# Clean up pumpkins that have fallen below the threshold
	cleanup_fallen_pumpkins()
	
	# Handle mouse input for pumpkin splitting
	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		print("Mouse clicked!")
		handle_mouse_click()

func _on_spawn_timer_timeout():
	spawn_pumpkin()

func _on_skull_spawn_timer_timeout():
	spawn_skull()
	# Set next random interval
	skull_spawn_timer.wait_time = randf_range(5.0, 10.0)

func _on_game_timer_timeout():
	if game_started:
		time_remaining -= 1.0
		update_ui()
		
		if time_remaining <= 0:
			game_over()

func _on_game_start_button_pressed():
	if not game_started:
		start_game()

func start_game():
	game_started = true
	game_start_button.visible = false  # Hide the start button
	game_over_label.visible = false  # Hide game over label
	
	# Reset timer
	time_remaining = 60.0
	update_ui()
	
	# Start the spawn timers
	spawn_timer.start()
	skull_spawn_timer.start()
	game_timer.start()  # Start the countdown timer
	
	# Spawn the first pumpkin immediately
	spawn_pumpkin()
	
	print("Game started!")

func update_ui():
	score_label.text = "Score: " + str(score)
	score_goal_label.text = "Score Goal: " + str(score_goal)
	level_label.text = "Level: " + str(level)
	timer_label.text = "Time: " + str(int(time_remaining))

func add_score(points: int):
	score += points
	update_ui()
	
	# Check if score goal is reached
	if score >= score_goal:
		level_up()

func level_up():
	level += 1
	score_goal += 50  # Increase goal by 50 each level
	score = 0  # Reset score for new level
	time_remaining = 60.0  # Reset timer to 60 seconds
	update_ui()
	
	# Increase spawn rate slightly for higher levels
	spawn_timer.wait_time = max(2.0, spawn_timer.wait_time - 0.5)
	skull_spawn_timer.wait_time = max(3.0, skull_spawn_timer.wait_time - 0.5)
	
	print("Level up! Now on level " + str(level))

func game_over():
	game_started = false
	
	# Stop all timers
	spawn_timer.stop()
	skull_spawn_timer.stop()
	game_timer.stop()
	
	# Show game over message
	game_over_label.visible = true
	
	# Clear all spawned objects
	clear_all_objects()
	
	print("Game Over!")
	
	# Wait 5 seconds then show start button again
	await get_tree().create_timer(5.0).timeout
	game_over_label.visible = false
	game_start_button.visible = true
	
	# Reset game state
	score = 0
	level = 1
	score_goal = 100
	time_remaining = 60.0
	update_ui()

func clear_all_objects():
	# Remove all RigidBody3D children (pumpkins, skulls, and parts)
	var children = get_children()
	for child in children:
		if child is RigidBody3D:
			child.queue_free()

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
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 1.0 # Adjust size to match your pumpkin
	collision_shape.shape = sphere_shape
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

func spawn_skull():
	if skull_scene == null:
		print("Skull scene not loaded!")
		return
	
	# Create a RigidBody3D to hold the skull
	var skull_body = RigidBody3D.new()
	
	# Create a new skull instance
	var skull_instance = skull_scene.instantiate()
	
	# Generate random position within spawn area
	var random_x = randf_range(spawn_area_min.x, spawn_area_max.x)
	var random_z = randf_range(spawn_area_min.z, spawn_area_max.z)
	var spawn_position = Vector3(random_x, spawn_area_min.y, random_z)
	
	# Set the skull position
	skull_body.position = spawn_position
	
	# Add some random rotation for variety
	var random_rotation = Vector3(
		randf_range(0, 1 * PI),
		randf_range(0, 1 * PI),
		randf_range(0, 1 * PI)
	)
	skull_body.rotation = random_rotation
	
	# Add the skull model as a child of the RigidBody3D
	skull_body.add_child(skull_instance)
	
	# Scale the skull to be 5 times bigger
	skull_instance.scale = Vector3(10.0, 10.0, 10.0)
	
	# Add collision shape to the skull (scaled to match the larger skull)
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 1.0 # Scaled up to match the 5x larger skull
	collision_shape.shape = sphere_shape
	skull_body.add_child(collision_shape)
	
	# Configure physics properties
	skull_body.mass = 1.0  # Mass of the skull
	skull_body.gravity_scale = 1.0  # Affected by gravity
	
	# Add upward velocity with some randomness
	var upward_force = randf_range(10.0, 15.0)  # Random upward velocity
	var horizontal_force_x = randf_range(-2.0, 2.0)  # Random horizontal velocity
	var horizontal_force_z = randf_range(-2.0, 2.0)  # Random horizontal velocity
	
	var initial_velocity = Vector3(horizontal_force_x, upward_force, horizontal_force_z)
	skull_body.linear_velocity = initial_velocity
	
	# Add some random angular velocity for spinning
	var angular_velocity = Vector3(
		randf_range(-5.0, 5.0),
		randf_range(-5.0, 5.0),
		randf_range(-5.0, 5.0)
	)
	skull_body.angular_velocity = angular_velocity
	
	# Mark this as a skull (not a pumpkin)
	skull_body.set_meta("is_skull", true)
	
	# Add the skull body to the scene
	add_child(skull_body)
	
	print("Spawned skull at position: ", spawn_position, " with velocity: ", initial_velocity)

func cleanup_fallen_pumpkins():
	# Get all RigidBody3D children (our pumpkin bodies, parts, and skulls)
	var children = get_children()
	for child in children:
		if child is RigidBody3D:
			# Check if the pumpkin, pumpkin part, or skull has fallen below the threshold
			if child.position.y < cleanup_threshold:
				if child.has_meta("is_skull"):
					print("Removing fallen skull at position: ", child.position)
				else:
					print("Removing fallen pumpkin/part at position: ", child.position)
				child.queue_free()  # Remove the object from the scene

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
			add_score(10)  # +10 points for hitting a pumpkin
			split_pumpkin(hit_object, result.position)
		elif hit_object is RigidBody3D and hit_object.has_meta("is_skull"):
			print("Hit skull - skulls don't split!")
			add_score(-5)  # -5 points for hitting a skull
		elif hit_object is RigidBody3D:
			print("Hit pumpkin part, not splitting")
		else:
			print("Hit something else, not a pumpkin or skull")
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
