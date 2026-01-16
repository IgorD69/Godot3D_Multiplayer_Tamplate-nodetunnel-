extends Node3D

func _process(_delta: float) -> void:
	# Doar jucătorul care apasă tasta pe calculatorul lui închide instanța lui
	if Input.is_action_just_pressed("force_close"):
		get_tree().quit()
