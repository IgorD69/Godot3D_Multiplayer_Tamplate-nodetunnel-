extends Node3D

#@export var PLAYER_SCENE = preload("uid://bb3qcv0kbqbo6")
@export var PLAYER_SCENE = preload("uid://bb3qcv0kbqbo6")

#signal Send_Name_to_Label(str)

var showCanvas = true
var is_lan_mode: bool = false
@onready var ui: CanvasLayer = $UI
@onready var control: Control = %Control
@onready var id_label: Label = %IDLabel
@onready var join: Button = $UI/Control/Join
@onready var host: Button = $UI/Control/Host

var peer: NodeTunnelPeer

func _ready() -> void:
	peer = NodeTunnelPeer.new()
	#peer.debug_enabled = true # Enable debugging if needed
	
	# Always set the global peer *before* attempting to connect
	multiplayer.multiplayer_peer = peer
	
	host.disabled = true
	join.disabled = true
	
	# Connect to the public relay
	peer.connect_to_relay("relay.nodetunnel.io", 9998)
	
	# Wait until we have connected to the relay
	await peer.relay_connected
	
	# Attach peer_connected signal
	peer.peer_connected.connect(_add_player)
	
	# Attach peer_disconnected signal
	peer.peer_disconnected.connect(_remove_player)
	
	# Attach room_left signal
	peer.room_left.connect(_show_main_menu)
	
	# At this point, we can access the online ID that the server generated for us
	%IDLabel.text = peer.online_id
	
	# ACUM arată și activează butoanele după ce ai primit ID-ul
	host.visible = true
	host.disabled = false
	join.visible = true
	join.disabled = false
	

func _on_host_pressed() -> void:
	print("Online ID: ", peer.online_id)
	
	# Host a game, must be done *after* relay connection is made
	peer.host()
	
	# Copy online id to clipboard
	DisplayServer.clipboard_set(peer.online_id)
	
	# Wait until peer has started hosting
	await peer.hosting
	
	# Spawn the host player CU ID-UL CORECT
	_add_player(multiplayer.get_unique_id())
	
	# Hide the UI
	%Control.hide()

	
func _on_join_pressed() -> void:
	peer.join(%HostID.text)
	
	# Wait until peer has finished joining
	await peer.joined
	
	%Control.hide()

func _add_player(peer_id: int = 1) -> void:
	if !multiplayer.is_server(): 
		print("NOT SERVER - Skipping spawn for peer: ", peer_id)
		return
	
	print("=== STARTING SPAWN for peer: ", peer_id, " ===")
	
	var spawn_position = Vector3(randf_range(-5, 5), 2, randf_range(-5, 5))
	print("Generated spawn position: ", spawn_position)
	
	var player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	
	print("Player created, setting position BEFORE add_child")
	player.position = spawn_position
	print("Player position after setting: ", player.position)
	
	player.set_multiplayer_authority(peer_id)
	
	add_child(player)
	
	print("Player added to tree")
	await get_tree().process_frame
	print("Player position after add_child: ", player.position)
	print("Player global_position after add_child: ", player.global_position)
	
	print("=== SPAWN COMPLETE for peer: ", peer_id, " ===")
	

func _remove_player(peer_id: int) -> void:
	if !multiplayer.is_server(): return
	
	var player = get_node(str(peer_id))
	player.queue_free()

func _on_leave_room_pressed() -> void:
	peer.leave_room()
	
func _show_main_menu() -> void:
	showCanvas = !showCanvas
	
	if showCanvas:
		%Control.show()
		# Eliberăm mouse-ul pentru a putea da click pe butoane
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		%Control.hide()
		# Blocăm mouse-ul în centrul ecranului pentru a roti camera
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	

func _on_button_pressed() -> void:
	DisplayServer.clipboard_set(id_label.text.replace("Your ID: ", ""))
	print("Copied ID to clipboard:", DisplayServer.clipboard_get())

func _on_exit_button_pressed() -> void:
	get_tree().quit()


#func _ready() -> void:
	#control.visible = false
	
	
func _input(event: InputEvent) -> void:
	
	if event.is_action_pressed("force_close"):
		get_tree().quit()
		
	if event.is_action_pressed("esc"):
		_show_main_menu()
		
func _on_menu_pressed() -> void:
	ui.visible = true
	_on_leave_room_pressed()

#
#func _on_lan_pressed() -> void:
	#is_lan_mode = !is_lan_mode
	#if is_lan_mode:
		#%LanButton.text = "MODE: LAN (Local)"
		#%IDLabel.text = "LAN Mode Active - Use IP to Join"
	#else:
		#%LanButton.text = "MODE: STEAM"
		#var steam_id = Steam.getSteamID()
		#%IDLabel.text = "Steam ID: " + str(steam_id)
