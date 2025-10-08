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

# Background music
var background_music: AudioStreamPlayer

# Sound effects
var clang_audio: AudioStreamPlayer
var woosh_audio: AudioStreamPlayer
var break_audio: AudioStreamPlayer
var evil_laugh_audio: AudioStreamPlayer

# Network references
var udp_server: UDPServer
var udp_peer: PacketPeerUDP

# Chip spawning variables
var chip_scene: PackedScene

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
var skull_penalty_label: Label
var final_score_label: Label

# Instruction UI references
var instructions_container: Control
var pumpkin_instruction: VBoxContainer
var skull_instruction: VBoxContainer
var pumpkin_model_viewport: SubViewport
var skull_model_viewport: SubViewport

# Spinning models
var spinning_pumpkin: Node3D
var spinning_skull: Node3D

# Timer variables
var game_timer: Timer

# Particle system reference
var pumpkin_particles: GPUParticles3D


func _ready():
	# Load the pumpkin scene
	pumpkin_scene = load("res://assets/models/firstpumpkin.blend")
	
	# Get reference to the light node
	light_node = get_node("OmniLight3D")
	original_light_energy = light_node.light_energy
	
	# Get reference to the thunder audio player
	thunder_audio = get_node("ThunderAudio")
	
	# Get reference to the background music player
	background_music = get_node("BackgroundMusic")
	
	# Get reference to the clang audio player
	clang_audio = get_node("ClangAudio")
	
	# Get reference to the woosh audio player
	woosh_audio = get_node("WooshAudio")
	
	# Get reference to the break audio player
	break_audio = get_node("BreakAudio")
	
	# Get reference to the evil laugh audio player
	evil_laugh_audio = get_node("EvilLaughAudio")
	
	# Load all thunder sound files
	load_thunder_sounds()
	
	# Load and setup background music
	setup_background_music()
	
	# Load sound effects
	setup_clang_sound()
	setup_woosh_sound()
	setup_break_sound()
	setup_evil_laugh_sound()
	
	# Load chip scene
	chip_scene = load("res://assets/models/chip.blend")
	
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
	skull_penalty_label = get_node("UI/SkullPenaltyLabel")
	final_score_label = get_node("UI/FinalScoreLabel")
	
	# Get instruction UI references
	instructions_container = get_node("UI/InstructionsContainer")
	pumpkin_instruction = get_node("UI/InstructionsContainer/PumpkinInstruction")
	skull_instruction = get_node("UI/InstructionsContainer/SkullInstruction")
	pumpkin_model_viewport = get_node("UI/InstructionsContainer/PumpkinInstruction/PumpkinModel")
	skull_model_viewport = get_node("UI/InstructionsContainer/SkullInstruction/SkullModel")
	
	# Get particle system reference
	pumpkin_particles = get_node("GPUParticles3D")
	setup_particle_system()
	
	# Connect the game start button
	game_start_button.pressed.connect(_on_game_start_button_pressed)
	
	# Initialize UI
	update_ui()
	
	# Setup instruction models
	setup_instruction_models()
	
	# Create and configure the spawn timer (don't start until game begins)
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 2.5  # 2.5 seconds (doubled frequency)
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
	
	# Setup UDP server for network slicing
	setup_udp_server()
	
	# Don't spawn anything until game starts


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
	skull_penalty_label.visible = false  # Hide penalty label
	instructions_container.visible = false  # Hide instructions
	
	# Hide the spinning instruction models
	if spinning_pumpkin != null:
		spinning_pumpkin.visible = false
	if spinning_skull != null:
		spinning_skull.visible = false
	
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
	score_goal += (level+1) * 50  # Increase goal each level
	# Keep current score - don't reset to 0
	time_remaining = 60.0  # Reset timer to 60 seconds
	update_ui()
	
	# Increase spawn rate slightly for higher levels
	spawn_timer.wait_time = max(1.0, spawn_timer.wait_time - 0.25)  # Faster pumpkin spawning
	skull_spawn_timer.wait_time = max(2.0, skull_spawn_timer.wait_time * 0.5)  # 50% faster skull spawning
	
	print("Level up! Now on level " + str(level) + " - Score goal increased to " + str(score_goal))

func show_skull_penalty(world_position: Vector3):
	# Convert 3D world position to 2D screen position
	var screen_pos = camera.unproject_position(world_position)
	skull_penalty_label.position = screen_pos
	skull_penalty_label.visible = true
	# Hide the penalty after 1 second
	await get_tree().create_timer(1.0).timeout
	skull_penalty_label.visible = false

func game_over():
	game_started = false
	
	# Stop all timers
	spawn_timer.stop()
	skull_spawn_timer.stop()
	game_timer.stop()
	
	# Play evil laugh sound
	play_evil_laugh_sound()
	
	# Show game over message and final score
	game_over_label.visible = true
	final_score_label.text = "Your Score: " + str(score)
	final_score_label.visible = true
	skull_penalty_label.visible = false  # Hide penalty label
	
	# Clear all spawned objects
	clear_all_objects()
	
	print("Game Over!")
	
	# Wait 5 seconds then show start button again
	await get_tree().create_timer(5.0).timeout
	game_over_label.visible = false
	final_score_label.visible = false
	game_start_button.visible = true
	instructions_container.visible = true  # Show instructions again
	
	# Show the spinning instruction models again
	if spinning_pumpkin != null:
		spinning_pumpkin.visible = true
	if spinning_skull != null:
		spinning_skull.visible = true
	
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
	
	# Mark this as a skull (not a pumpkin) and track if it's been hit
	skull_body.set_meta("is_skull", true)
	skull_body.set_meta("has_been_hit", false)
	
	# Add the skull body to the scene
	add_child(skull_body)
	
	print("Spawned skull at position: ", spawn_position, " with velocity: ", initial_velocity)

func cleanup_fallen_pumpkins():
	# Get all RigidBody3D children (our pumpkin bodies, parts, skulls, and chips)
	var children = get_children()
	for child in children:
		if child is RigidBody3D:
			# Check if the object has fallen below the threshold
			if child.position.y < cleanup_threshold:
				if child.has_meta("is_skull"):
					print("Removing fallen skull at position: ", child.position)
				elif child.has_meta("is_chip"):
					print("Removing fallen chip at position: ", child.position)
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

func setup_background_music():
	# Load the crickets sound file
	var crickets_sound = load("res://sounds/crickets.mp3")
	if crickets_sound != null:
		background_music.stream = crickets_sound
		background_music.volume_db = 5.0  # Set volume lower for background
		background_music.autoplay = true
		background_music.play()
		print("Background music loaded and playing")
	else:
		print("Could not load crickets.m4a background music")

func setup_clang_sound():
	# Load the clang sound file
	var clang_sound = load("res://sounds/clang.mp3")
	if clang_sound != null:
		clang_audio.stream = clang_sound
		clang_audio.volume_db = 0.0
		print("Clang sound effect loaded")
	else:
		print("Could not load clang.mp3 sound effect")

func setup_woosh_sound():
	# Load the woosh sound file
	var woosh_sound = load("res://sounds/woosh.wav")
	if woosh_sound != null:
		woosh_audio.stream = woosh_sound
		woosh_audio.volume_db = 0.0
		print("Woosh sound effect loaded")
	else:
		print("Could not load woosh.wav sound effect")

func play_clang_sound():
	if clang_audio.stream != null:
		# Add random pitch variation
		clang_audio.pitch_scale = randf_range(0.8, 1.2)
		clang_audio.play()

func setup_break_sound():
	# Load the break sound file
	var break_sound = load("res://sounds/break.wav")
	if break_sound != null:
		break_audio.stream = break_sound
		break_audio.volume_db = 0.0
		print("Break sound effect loaded")
	else:
		print("Could not load break.wav sound effect")

func play_woosh_sound():
	if woosh_audio.stream != null:
		# Add random pitch variation
		woosh_audio.pitch_scale = randf_range(0.7, 1.3)
		woosh_audio.play()

func play_break_sound():
	if break_audio.stream != null:
		# Add random pitch variation
		break_audio.pitch_scale = randf_range(0.8, 1.2)
		break_audio.play()

func setup_evil_laugh_sound():
	# Load the evil laugh sound file
	var evil_laugh_sound = load("res://sounds/evillaugh.mp3")
	if evil_laugh_sound != null:
		evil_laugh_audio.stream = evil_laugh_sound
		evil_laugh_audio.volume_db = 0.0
		print("Evil laugh sound effect loaded")
	else:
		print("Could not load evillaugh.mp3 sound effect")

func play_evil_laugh_sound():
	if evil_laugh_audio.stream != null:
		evil_laugh_audio.play()

func setup_instruction_models():
	# Make instruction container not intercept mouse events
	instructions_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Setup pumpkin model in viewport
	var pumpkin_scene_instance = pumpkin_scene.instantiate()
	spinning_pumpkin = pumpkin_scene_instance
	pumpkin_model_viewport.add_child(spinning_pumpkin)
	
	# Position and scale pumpkin
	spinning_pumpkin.position = Vector3(0, 2, 2)  # +1 in Y direction
	spinning_pumpkin.scale = Vector3(1.0, 1.0, 1.0)
	
	# Setup skull model in viewport
	var skull_scene_instance = skull_scene.instantiate()
	spinning_skull = skull_scene_instance
	skull_model_viewport.add_child(spinning_skull)
	
	# Position and scale skull
	spinning_skull.position = Vector3(0, -2, 2)  # -2 in Y direction
	spinning_skull.scale = Vector3(6.0, 6.0, 6.0)  # 6x bigger (3x * 2x)
	
	# Add cameras to viewports
	var pumpkin_camera = Camera3D.new()
	pumpkin_camera.position = Vector3(0, 0, 5)
	pumpkin_model_viewport.add_child(pumpkin_camera)
	
	var skull_camera = Camera3D.new()
	skull_camera.position = Vector3(0, 0, 5)
	skull_model_viewport.add_child(skull_camera)
	
	print("Instruction models setup complete")

func _process(delta):
	# Clean up pumpkins that have fallen below the threshold
	cleanup_fallen_pumpkins()
	
	# Rotate instruction models
	if spinning_pumpkin != null:
		spinning_pumpkin.rotation.y += delta * 1.0  # Slow rotation
	
	if spinning_skull != null:
		spinning_skull.rotation.y += delta * 1.0  # Slow rotation
	
	# Process network packets
	process_network_packets()
	
	# Handle mouse input for pumpkin splitting
	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_pos = get_viewport().get_mouse_position()
		print("Mouse clicked! Coordinates: ", mouse_pos)
		handle_mouse_click()


func break_skull(skull_body: RigidBody3D, _hit_position: Vector3):
	if chip_scene == null:
		print("Chip scene not loaded!")
		return
	
	# Get the skull's current position and velocity
	var skull_pos = skull_body.global_position
	var skull_vel = skull_body.linear_velocity
	var _skull_ang_vel = skull_body.angular_velocity
	
	# Create 12 chips in a sphere pattern around the skull
	for i in range(12):
		# Calculate position around the skull
		var angle = (i * 2 * PI) / 12.0  # Evenly distribute around circle
		var radius = 1.0  # Distance from center
		var chip_offset = Vector3(
			cos(angle) * radius,
			randf_range(-0.5, 0.5),  # Random height variation
			sin(angle) * radius
		)
		
		# Create chip body
		var chip_body = RigidBody3D.new()
		var chip_instance = chip_scene.instantiate()
		
		# Scale the chip to be 4 times smaller
		chip_instance.scale = Vector3(0.15, 0.15, 0.15)
		
		chip_body.add_child(chip_instance)
		
		# Set position and physics (use position instead of global_position before adding to tree)
		chip_body.position = skull_pos + chip_offset
		
		# Add random velocity away from center
		var chip_velocity = chip_offset.normalized() * randf_range(3.0, 8.0)
		chip_velocity.y += randf_range(2.0, 6.0)  # Add upward velocity
		chip_body.linear_velocity = skull_vel + chip_velocity
		
		# Add random angular velocity
		chip_body.angular_velocity = Vector3(
			randf_range(-10.0, 10.0),
			randf_range(-10.0, 10.0),
			randf_range(-10.0, 10.0)
		)
		
		# Add collision shape
		var collision = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.5, 0.5, 0.5)  # 4x smaller chip collision
		collision.shape = box
		chip_body.add_child(collision)
		
		# Configure physics
		chip_body.mass = 0.1  # Light chips
		chip_body.gravity_scale = 1.0
		
		# Mark as chip
		chip_body.set_meta("is_chip", true)
		
		# Add to scene
		add_child(chip_body)
	
	# Remove the original skull
	skull_body.queue_free()
	
	print("Skull broken into 12 chips!")

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
			play_woosh_sound()  # Play woosh sound effect
			split_pumpkin(hit_object, result.position)
		elif hit_object is RigidBody3D and hit_object.has_meta("is_skull"):
			if not hit_object.has_meta("has_been_hit") or not hit_object.get_meta("has_been_hit"):
				print("Hit skull - breaking into chips!")
				add_score(-5)  # -5 points for hitting a skull
				hit_object.set_meta("has_been_hit", true)  # Mark as hit
				show_skull_penalty(result.position)  # Show -10s penalty at click location
				time_remaining = max(0, time_remaining - 10)  # Deduct 10 seconds
				play_break_sound()  # Play break sound effect
				break_skull(hit_object, result.position)  # Break skull into chips
				update_ui()
			else:
				print("Skull already hit - no points!")
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
	
	# Trigger particle explosion at hit position
	trigger_pumpkin_particles(hit_position)
	
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

func create_pumpkin_part(scene: PackedScene, part_position: Vector3, velocity: Vector3, angular_velocity: Vector3):
	# Create the pumpkin part body
	var part_body = RigidBody3D.new()
	var part_instance = scene.instantiate()
	part_body.add_child(part_instance)
	
	# Set position and physics (use position instead of global_position before adding to tree)
	part_body.position = part_position
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



# Network functions
func setup_udp_server():
	"""Setup UDP server to listen on port 8090 for slice coordinates"""
	udp_server = UDPServer.new()
	udp_peer = PacketPeerUDP.new()
	
	var result = udp_server.listen(8090, "0.0.0.0")
	if result == OK:
		print("UDP server listening on port 8090")
	else:
		print("Failed to start UDP server on port 8090")


func process_network_packets():
	"""Process incoming UDP packets for slice coordinates"""
	if udp_server == null:
		return
		
	# Poll for new connections
	udp_server.poll()
	
	# Check for new packets
	if udp_server.is_connection_available():
		var peer = udp_server.take_connection()
		var packet = peer.get_packet()
		var packet_string = packet.get_string_from_utf8()
		
		print("Received packet: ", packet_string)
		
		# Parse JSON packet
		var json = JSON.new()
		var parse_result = json.parse(packet_string)
		
		if parse_result == OK:
			var data = json.data
			if data.has("slice") and data.slice is Array and data.slice.size() == 2:
				var x = data.slice[0]
				var y = data.slice[1]
				print("Network slice coordinates: ", x, ", ", y)
				
				# Convert network coordinates to world coordinates and perform slice
				network_slice_at_coordinates(x, y)
			else:
				print("Invalid slice packet format")
		else:
			print("Failed to parse JSON packet")


func network_slice_at_coordinates(net_x: int, net_y: int):
	"""Convert network coordinates to world coordinates and perform slice"""
	# Convert network coordinates to world coordinates
	# Assuming network coordinates are screen coordinates (0-1920, 0-1080)
	# We need to convert to world coordinates for raycasting
	var screen_size = get_viewport().get_visible_rect().size
	var normalized_x = float(net_x) / screen_size.x
	var normalized_y = float(net_y) / screen_size.y
	
	# Convert to viewport coordinates
	var viewport_pos = Vector2(normalized_x * screen_size.x, normalized_y * screen_size.y)
	
	print("Converted coordinates: ", viewport_pos)
	
	# First check if we hit the Game Start button (only if game not started)
	if not game_started and game_start_button.visible:
		var button_rect = game_start_button.get_rect()
		if button_rect.has_point(viewport_pos):
			print("Network slice hit Game Start button!")
			_on_game_start_button_pressed()
			return
	
	# If game is started, perform 3D raycast for game objects
	if game_started:
		# Perform raycast from camera through the viewport position
		var from = camera.project_ray_origin(viewport_pos)
		var to = from + camera.project_ray_normal(viewport_pos) * 1000.0
		
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)
		
		if result:
			var hit_object = result.collider
			print("Network slice hit: ", hit_object.name)
			
			# Handle the hit using existing logic
			handle_network_slice_hit(hit_object, result.position)
		else:
			print("Network slice hit nothing")
	else:
		print("Game not started and no UI hit detected")


func handle_network_slice_hit(hit_object: Node3D, hit_position: Vector3):
	"""Handle network slice hit using existing game logic"""
	# Check if it's a pumpkin
	if hit_object.get_meta("is_original_pumpkin", false):
		add_score(10)
		split_pumpkin(hit_object, hit_position)
		play_woosh_sound()
		print("Network sliced pumpkin!")
		
	# Check if it's a skull (first hit only)
	elif hit_object.get_meta("is_skull", false):
		if not hit_object.get_meta("has_been_hit", false):
			add_score(-5)
			hit_object.set_meta("has_been_hit", true)
			show_skull_penalty(hit_position)
			time_remaining = max(0, time_remaining - 10)
			play_break_sound()
			break_skull(hit_object, hit_position)
			update_ui()
			print("Network hit skull!")
		else:
			print("Network hit already-hit skull - no points!")

func setup_particle_system():
	"""Configure the particle system properties"""
	if pumpkin_particles == null:
		print("Particle system not found!")
		return
	
	# Don't emit at start
	pumpkin_particles.emitting = false
	pumpkin_particles.one_shot = true  # Only emit once when triggered
	
	# Configure particle properties
	pumpkin_particles.amount = 50
	pumpkin_particles.lifetime = 0.5  # Emit for 0.5 seconds
	pumpkin_particles.explosiveness = 1.0  # All particles emit at once
	
	# Get the process material to configure it
	var material = pumpkin_particles.process_material as ParticleProcessMaterial
	if material == null:
		print("Particle material not found!")
		return
	
	# Configure emission - sphere for random directions
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.3
	
	# Direction and spread
	material.direction = Vector3(0, 1, 0)  # Upward bias
	material.spread = 180.0  # Full sphere spread
	
	# Velocity
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 8.0
	
	# Gravity
	material.gravity = Vector3(0, -9.8, 0)
	
	# Scale
	material.scale_min = 0.05
	material.scale_max = 0.15
	
	# Create color gradient: bright red to faded yellow
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 0, 0, 1))  # Bright red at start
	gradient.add_point(0.5, Color(1, 0.5, 0, 0.8))  # Orange midway
	gradient.add_point(1.0, Color(1, 1, 0, 0))  # Faded yellow at end (transparent)
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	
	print("Particle system configured!")

func trigger_pumpkin_particles(hitpos: Vector3):
	"""Trigger particle explosion at the specified position"""
	if pumpkin_particles == null:
		print("Particle system not available!")
		return
	
	# Move particles to hit position and emit
	pumpkin_particles.global_position = hitpos
	pumpkin_particles.emitting = true
	pumpkin_particles.restart()
	
	print("Triggered particles at position: ", hitpos)
