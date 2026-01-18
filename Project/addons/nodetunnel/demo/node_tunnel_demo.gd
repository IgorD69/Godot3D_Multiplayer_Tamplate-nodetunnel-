extends Node3D

@export var PLAYER_SCENE = preload("uid://bb3qcv0kbqbo6")

var showCanvas = true
var is_lan_mode: bool = false
var TabName: String = ""  # Salvăm numele aici

@onready var ui: CanvasLayer = $UI
@onready var control: Control = %Control
@onready var id_label: Label = %IDLabel
@onready var join: Button = $UI/Control/Join
@onready var host: Button = $UI/Control/Host
@onready var name_field: LineEdit = $UI/Control/NameField

var peer: NodeTunnelPeer

# Dictionary pentru a stoca numele tuturor jucătorilor
var player_names: Dictionary = {}

func _ready() -> void:
	peer = NodeTunnelPeer.new()
	
	multiplayer.multiplayer_peer = peer
	
	host.disabled = true
	join.disabled = true
	
	name_field.text_changed.connect(_on_name_field_text_changed)
	
	peer.connect_to_relay("relay.nodetunnel.io", 9998)
	
	await peer.relay_connected
	
	peer.peer_connected.connect(_add_player)
	peer.peer_disconnected.connect(_remove_player)
	peer.room_left.connect(_show_main_menu)
	
	%IDLabel.text = peer.online_id
	
	_validate_buttons()


func _on_name_field_text_changed(new_text: String) -> void:
	TabName = new_text  # Actualizăm TabName când se schimbă textul
	_validate_buttons()


func _validate_buttons() -> void:
	var has_name = !name_field.text.is_empty()
	host.disabled = !has_name
	join.disabled = !has_name


func _on_host_pressed() -> void:
	print("Online ID: ", peer.online_id)
	
	TabName = name_field.text  # Salvăm numele înainte de a hosta
	
	peer.host()
	DisplayServer.clipboard_set(peer.online_id)
	
	await peer.hosting
	
	_add_player(multiplayer.get_unique_id())
	
	%Control.hide()

	
func _on_join_pressed() -> void:
	TabName = name_field.text  # Salvăm numele înainte de a ne alătura
	
	peer.join(%HostID.text)
	
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


# Funcție helper pentru a obține numele jucătorului local
func get_player_name() -> String:
	return TabName
	

func _remove_player(peer_id: int) -> void:
	if !multiplayer.is_server(): return
	
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
	
	# Ștergem numele din dicționar
	player_names.erase(peer_id)


func _on_leave_room_pressed() -> void:
	peer.leave_room()
	

func _show_main_menu() -> void:
	showCanvas = !showCanvas
	
	if showCanvas:
		%Control.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		%Control.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	

func _on_button_pressed() -> void:
	DisplayServer.clipboard_set(id_label.text.replace("Your ID: ", ""))
	print("Copied ID to clipboard:", DisplayServer.clipboard_get())


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("force_close"):
		get_tree().quit()
		
	if event.is_action_pressed("esc"):
		_show_main_menu()
		

func _on_menu_pressed() -> void:
	ui.visible = true
	_on_leave_room_pressed()
