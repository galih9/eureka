class_name OceanWater
extends Node3D

## Infinite Ocean Water Controller for Godot 4.
## Manages ocean positioning, infinite grid-snapping to camera coordinates,
## and exposes runtime parameters for wave dynamics and storm intensity.

@export_group("Ocean Transform")
## Base vertical elevation of the water surface.
@export var water_level: float = -1.6
## If true, the ocean mesh shifts horizontally with the active camera to create an infinite ocean.
@export var follow_camera: bool = true
## Grid snapping increment in world units (matches or subdivides vertex spacing to eliminate vertex swimming).
@export_range(0.5, 20.0, 0.5) var grid_snap: float = 2.5
## Specific camera to follow. If null, automatically resolves the current 3D viewport camera.
@export var target_camera: Camera3D

@export_group("Wave Dynamics")
## Multiplier for overall wave propagation speed.
@export_range(0.0, 4.0, 0.05) var wave_speed: float = 1.0:
	set(value):
		wave_speed = value
		_update_shader_param(&"wave_speed", wave_speed)

## Multiplier for wave vertical crest and trough displacement.
@export_range(0.0, 3.0, 0.05) var wave_amplitude: float = 1.0:
	set(value):
		wave_amplitude = value
		_update_shader_param(&"wave_amplitude_mult", wave_amplitude * storm_intensity)

## Dynamic storm multiplier. Elevates waves and foam for dramatic storm effects.
@export_range(0.0, 3.0, 0.1) var storm_intensity: float = 1.0:
	set(value):
		storm_intensity = value
		_update_shader_param(&"wave_amplitude_mult", wave_amplitude * storm_intensity)

@export_group("References")
@export var ocean_mesh: MeshInstance3D

var _material: ShaderMaterial = null

func _ready() -> void:
	if ocean_mesh == null:
		ocean_mesh = get_node_or_null("OceanMesh") as MeshInstance3D
		
	if ocean_mesh != null:
		_material = ocean_mesh.get_active_material(0) as ShaderMaterial
		if _material == null and ocean_mesh.material_override is ShaderMaterial:
			_material = ocean_mesh.material_override as ShaderMaterial
			
	global_position.y = water_level
	_find_camera()

func _find_camera() -> void:
	if target_camera != null and is_instance_valid(target_camera):
		return
		
	var viewport = get_viewport()
	if viewport != null:
		target_camera = viewport.get_camera_3d()
		
	if target_camera == null:
		# Fallback: search root tree
		target_camera = get_tree().root.find_child("Camera3D", true, false) as Camera3D

func _process(_delta: float) -> void:
	if target_camera == null or not is_instance_valid(target_camera):
		_find_camera()
		if target_camera == null:
			return
			
	var cam_pos = target_camera.global_position if target_camera.is_inside_tree() else target_camera.position
	var snap = maxf(grid_snap, 0.1)
	var snapped_x = floorf(cam_pos.x / snap) * snap
	var snapped_z = floorf(cam_pos.z / snap) * snap
	
	if is_inside_tree():
		if absf(global_position.y - water_level) > 0.001:
			global_position.y = water_level
		if not follow_camera:
			return
		if global_position.x != snapped_x or global_position.z != snapped_z:
			global_position.x = snapped_x
			global_position.z = snapped_z
	else:
		if absf(position.y - water_level) > 0.001:
			position.y = water_level
		if not follow_camera:
			return
		if position.x != snapped_x or position.z != snapped_z:
			position.x = snapped_x
			position.z = snapped_z

func _update_shader_param(param_name: StringName, value: Variant) -> void:
	if _material != null:
		_material.set_shader_parameter(param_name, value)

## Calculates analytical Gerstner wave surface height at any world (X, Z) coordinate.
## Useful for aligning floating debris, water splash effects, or sound triggers.
func get_wave_height_at(world_pos: Vector2, time_offset: float = 0.0) -> float:
	var total_time = (Time.get_ticks_msec() / 1000.0) + time_offset
	var total_h = water_level
	
	# Evaluate 4 Gerstner waves matching shader parameters
	var waves = [
		Vector4(1.0, 0.25, 0.28, 45.0),
		Vector4(0.35, 0.95, 0.20, 26.0),
		Vector4(-0.65, 0.75, 0.14, 15.0),
		Vector4(-0.3, -1.0, 0.08, 8.0)
	]
	
	var amp_mult = wave_amplitude * storm_intensity
	for w in waves:
		var dir = Vector2(w.x, w.y).normalized()
		var a = w.z * amp_mult
		var l = maxf(w.w, 0.1)
		var k = (2.0 * PI) / l
		var c = sqrt(9.8 / k) * wave_speed
		var theta = k * dir.dot(world_pos) + c * k * total_time
		total_h += a * sin(theta)
		
	return total_h
