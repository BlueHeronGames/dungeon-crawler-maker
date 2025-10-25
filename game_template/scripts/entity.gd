extends CharacterBody2D

## Base entity that handles tweened movement shared by all creatures.
class_name Entity

const MOVE_DURATION := 0.1

var _move_tween: Tween
var _is_moving := false

func can_accept_movement() -> bool:
	return not _is_moving

func move_to_position(target_position: Vector2) -> void:
	if _move_tween and _move_tween.is_running():
		_move_tween.kill()

	_is_moving = true
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_LINEAR)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(self, "global_position", target_position, MOVE_DURATION)
	_move_tween.finished.connect(_on_move_finished)

func move_by_offset(offset: Vector2) -> void:
	if offset == Vector2.ZERO:
		return
	var collision := move_and_collide(offset, true, 0.0, false) # zero-margin probe to see if a collider blocks the step
	if collision:
		return
	move_to_position(global_position + offset)

func _on_move_finished() -> void:
	_is_moving = false
	_move_tween = null
