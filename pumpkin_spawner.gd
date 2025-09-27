extends Node3D

# Reference to the pumpkin scene (we'll load it dynamically)
var pumpkin_scene: PackedScene

# Timer for spawning pumpkins
var spawn_timer: Timer

# Spawn area boundaries (adjust these to fit your scene)
var spawn_area_min = Vector3(-10, 0, -10)
var spawn_area_max = Vector3(10, 0, 10)

func _ready():
	# Load the pumpkin scene
	pumpkin_scene = load("res://assets/models/firstpumpkin.blend")
	
	# Create and configure the timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 5.0  # 5 seconds
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.autostart = true
	add_child(spawn_timer)
	
	# Spawn the first pumpkin immediately
	spawn_pumpkin()

func _on_spawn_timer_timeout():
	spawn_pumpkin()

func spawn_pumpkin():
	if pumpkin_scene == null:
		print("Pumpkin scene not loaded!")
		return
	
	# Create a new pumpkin instance
	var pumpkin_instance = pumpkin_scene.instantiate()
	
	# Generate random position within spawn area
	var random_x = randf_range(spawn_area_min.x, spawn_area_max.x)
	var random_z = randf_range(spawn_area_min.z, spawn_area_max.z)
	var spawn_position = Vector3(random_x, spawn_area_min.y, random_z)
	
	# Set the pumpkin position
	pumpkin_instance.position = spawn_position
	
	# Add some random rotation for variety
	var random_rotation = Vector3(
		randf_range(0, 2 * PI),
		randf_range(0, 2 * PI),
		randf_range(0, 2 * PI)
	)
	pumpkin_instance.rotation = random_rotation
	
	# Add the pumpkin to the scene
	add_child(pumpkin_instance)
	
	print("Spawned pumpkin at position: ", spawn_position)
