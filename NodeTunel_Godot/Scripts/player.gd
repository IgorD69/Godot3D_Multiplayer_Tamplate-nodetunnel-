extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_moving_state: bool = false 
var camera_v_rot: float = 0.0
var current_anim: String = ""

@onready var camera_pivot: SpringArm3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var PortalAnim: AnimationPlayer = $CameraPivot/Camera3D/Portal_Gun2/AnimationPlayer
@onready var MouseAnim: AnimationPlayer = $MOUSE/AnimationPlayer
@onready var model: MeshInstance3D = $MOUSE/Model

var hand: Marker3D

func _enter_tree() -> void:
	var id = name.to_int()
	if id > 0:
		set_multiplayer_authority(id)

func _ready():
	add_to_group("Players")
	# Caută sau creează nodul "hand"
	if camera:
		hand = camera.get_node_or_null("hand")
		if hand == null:
			hand = Marker3D.new()
			hand.name = "hand"
			hand.position = Vector3(0, 0, -1.5)
			camera.add_child(hand)
			print("Hand marker created for player: ", name)
		else:
			print("Hand marker found for player: ", name)
	else:
		print("ERROR: Camera not found for player: ", name)
	
	if is_multiplayer_authority():
		if camera:
			camera.make_current()
		model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		
		# Amână capturarea mouse-ului până când fereastra este în focus
		call_deferred("_setup_mouse_capture")
	else:
		if camera:
			camera.current = false
		set_process_input(false)

func _setup_mouse_capture():
	# Așteaptă un frame și verifică dacă fereastra este în focus
	await get_tree().process_frame
	if DisplayServer.window_is_focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# Dacă nu e în focus, încearcă din nou când devine
		get_viewport().gui_focus_changed.connect(_on_focus_gained, CONNECT_ONE_SHOT)

func _on_focus_gained():
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	if is_multiplayer_authority():
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		
		var current_target_speed = SPEED
		if Input.is_action_pressed("sprint"):
			current_target_speed = SPRINT_SPEED
		
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			velocity.x = direction.x * current_target_speed
			velocity.z = direction.z * current_target_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_target_speed)
			velocity.z = move_toward(velocity.z, 0, current_target_speed)
		
		move_and_slide()
		
		# Animații
		var current_speed = Vector3(velocity.x, 0, velocity.z).length()
		var next_anim = "Idle"
		if current_speed > 0.1:
			if Input.is_action_pressed("sprint"):
				next_anim = "FastRun"
			else:
				next_anim = "Walk"
		else:
			next_anim = "Idle"
		
		if current_anim != next_anim:
			current_anim = next_anim
			play_animation_rpc.rpc(next_anim)

func _input(event):
	if !is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		camera_v_rot -= event.relative.y * MOUSE_SENSITIVITY
		camera_v_rot = clamp(camera_v_rot, deg_to_rad(-80), deg_to_rad(80))
		
		camera_pivot.rotation.x = camera_v_rot
		update_camera_rotation.rpc(camera_v_rot)
	
	if event.is_action_pressed("L_Click"):
		play_shoot_animation.rpc("Shoot")

@rpc("any_peer", "call_local", "reliable")
func play_animation_rpc(anim_name: String):
	if MouseAnim and MouseAnim.has_animation(anim_name):
		MouseAnim.play(anim_name, 0.2)

@rpc("any_peer", "unreliable")
func update_camera_rotation(vertical_rotation: float):
	if not is_multiplayer_authority():
		camera_pivot.rotation.x = vertical_rotation

@rpc("any_peer", "call_local", "reliable")
func play_run_rpc(anim_name: String):
	if MouseAnim:
		if MouseAnim.current_animation != anim_name:
			MouseAnim.play(anim_name)

@rpc("any_peer", "call_local", "reliable")
func play_idle_rpc():
	if MouseAnim: 
		MouseAnim.play("Idle")

@rpc("any_peer", "call_local", "reliable")
func play_shoot_animation(_tip: String):
	if PortalAnim:
		PortalAnim.stop()
		PortalAnim.play("Shoot")
