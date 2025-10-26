extends Node2D

## Base entity that handles tweened movement shared by all creatures.
class_name Entity

signal health_changed(current_hp: int, max_hp: int)

const MOVE_DURATION := 0.1

var _move_tween: Tween
var _is_moving := false

var max_hp: int = 100
var current_hp: int = 100
var attack: int = 10
var defense: int = 0

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
	move_to_position(global_position + offset)

func _on_move_finished() -> void:
	_is_moving = false
	_move_tween = null

func take_damage(amount: int) -> int:
	var actual_damage : int = max(1, amount - defense)
	var previous_hp := current_hp
	current_hp = max(0, current_hp - actual_damage)
	if current_hp != previous_hp:
		_emit_health_changed()
	return actual_damage

func is_alive() -> bool:
	return current_hp > 0

func get_hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)

func restore_health(amount: int) -> int:
	var old_hp := current_hp
	current_hp = min(max_hp, current_hp + amount)
	if current_hp != old_hp:
		_emit_health_changed()
	return current_hp - old_hp

func _emit_health_changed() -> void:
	emit_signal("health_changed", current_hp, max_hp)
