@tool
class_name RainEffect
extends Node3D

## 3D Particle Rain System inspired by Watt Interactive.
## Features velocity-aligned RibbonTrailMesh particles, collision interaction,
## configurable easterly wind lean, and customizable intensity/crowdedness presets.

enum WindOrigin {
	EAST,   ## Wind blows from East (+X) toward West (-X)
	WEST,   ## Wind blows from West (-X) toward East (+X)
	NORTH,  ## Wind blows from North (-Z) toward South (+Z)
	SOUTH,  ## Wind blows from South (+Z) toward North (-Z)
	CUSTOM  ## Custom wind source vector
}

enum WeatherIntensity {
	DRIZZLE,   ## Very sparse, delicate drizzle (250 drops, thin, subtle)
	LIGHT,     ## Pleasant, clean light rain (500 drops, standard default)
	MODERATE,  ## Noticeable steady rainfall (900 drops)
	HEAVY,     ## Intense downpour (1600 drops)
	STORM,     ## Torrential storm deluge (2500 drops)
	CUSTOM     ## Custom manual values
}

@export_group("Weather Preset")
## Predefined rain intensity profiles. Selecting a preset adjusts density, opacity, and width.
@export var weather_intensity: WeatherIntensity = WeatherIntensity.LIGHT:
	set(value):
		weather_intensity = value
		if weather_intensity != WeatherIntensity.CUSTOM:
			_apply_preset(value)
		_update_rain_parameters()

@export_group("Intensity & Crowdedness")
## Total active rain streaks. Lower values (200-600) reduce crowding and clutter.
@export_range(50, 4000, 25) var rain_density: int = 500:
	set(value):
		rain_density = value
		_update_rain_parameters()

## Opacity / transparency of the rain streaks (0.05 = faint mist, 0.3 = subtle, 1.0 = opaque).
@export_range(0.02, 1.0, 0.02) var rain_opacity: float = 0.28:
	set(value):
		rain_opacity = value
		_update_rain_parameters()

## Thickness / width of each rain ribbon streak in meters.
@export_range(0.005, 0.05, 0.001) var streak_width: float = 0.016:
	set(value):
		streak_width = value
		_update_rain_parameters()

## Trail duration (streak length in seconds). Lower = shorter droplet streaks.
@export_range(0.02, 0.25, 0.01) var streak_trail_lifetime: float = 0.08:
	set(value):
		streak_trail_lifetime = value
		_update_rain_parameters()

## Base tint color of the raindrops.
@export var rain_tint: Color = Color(0.82, 0.90, 1.0):
	set(value):
		rain_tint = value
		_update_rain_parameters()

@export_group("Wind Settings")
## Cardinal direction the wind originates from.
## For "wind blown from the east", set to EAST (pushes rain westward along -X).
@export var wind_origin: WindOrigin = WindOrigin.EAST:
	set(value):
		wind_origin = value
		_update_rain_parameters()

## Custom wind direction origin (where the wind comes from) when wind_origin is CUSTOM.
@export var custom_wind_from: Vector3 = Vector3(1.0, 0.0, 0.0):
	set(value):
		custom_wind_from = value
		_update_rain_parameters()

## Angle (in degrees) that the rain leans from vertical due to the wind.
## Default 18.0° gives an authentic wind-blown slant.
@export_range(0.0, 60.0, 0.5) var wind_lean_angle_deg: float = 18.0:
	set(value):
		wind_lean_angle_deg = value
		_update_rain_parameters()

@export_group("Rain Physics & Volume")
## Fall velocity (m/s) of the raindrops.
@export_range(5.0, 50.0, 0.5) var fall_speed: float = 18.0:
	set(value):
		fall_speed = value
		_update_rain_parameters()

## Horizontal coverage area in meters (Width X, Depth Z).
@export var area_extents: Vector2 = Vector2(36.0, 36.0):
	set(value):
		area_extents = value
		_update_rain_parameters()

## Elevation (meters) above this node where raindrops spawn.
@export_range(5.0, 50.0, 1.0) var emitter_height: float = 16.0:
	set(value):
		emitter_height = value
		_update_rain_parameters()

## Angular spread (in degrees). Kept narrow for parallel wind streaks.
@export_range(0.0, 15.0, 0.5) var streak_spread_deg: float = 2.5:
	set(value):
		streak_spread_deg = value
		_update_rain_parameters()

@export_group("Collisions & Splashes")
## Enable secondary splash particles when raindrops strike collision surfaces.
@export var enable_splashes: bool = true:
	set(value):
		enable_splashes = value
		_update_rain_parameters()

@export_group("Camera / Player Tracking")
## Optional node (e.g. Camera3D or Player) to smoothly track on the X/Z plane.
@export var follow_target: Node3D = null

@onready var rain_particles: GPUParticles3D = $RainParticles
@onready var splash_particles: GPUParticles3D = $SplashParticles

func _ready() -> void:
	_update_rain_parameters()

func _process(_delta: float) -> void:
	if follow_target and is_instance_valid(follow_target):
		var target_pos: Vector3 = follow_target.global_position
		global_position.x = target_pos.x
		global_position.z = target_pos.z

## Configures parameters based on selected preset profile.
func _apply_preset(preset: WeatherIntensity) -> void:
	match preset:
		WeatherIntensity.DRIZZLE:
			rain_density = 250
			rain_opacity = 0.20
			streak_width = 0.012
			streak_trail_lifetime = 0.06
			fall_speed = 15.0
		WeatherIntensity.LIGHT:
			rain_density = 500
			rain_opacity = 0.28
			streak_width = 0.016
			streak_trail_lifetime = 0.08
			fall_speed = 18.0
		WeatherIntensity.MODERATE:
			rain_density = 900
			rain_opacity = 0.35
			streak_width = 0.020
			streak_trail_lifetime = 0.10
			fall_speed = 20.0
		WeatherIntensity.HEAVY:
			rain_density = 1600
			rain_opacity = 0.45
			streak_width = 0.024
			streak_trail_lifetime = 0.12
			fall_speed = 22.0
		WeatherIntensity.STORM:
			rain_density = 2500
			rain_opacity = 0.55
			streak_width = 0.028
			streak_trail_lifetime = 0.14
			fall_speed = 25.0
		WeatherIntensity.CUSTOM:
			pass

## Computes the normalized 3D velocity vector incorporating wind slant.
func get_calculated_direction() -> Vector3:
	var horiz_dir := Vector3.ZERO
	match wind_origin:
		WindOrigin.EAST:
			# Wind comes from East (+X), pushing rain West (-X)
			horiz_dir = Vector3(-1.0, 0.0, 0.0)
		WindOrigin.WEST:
			# Wind comes from West (-X), pushing rain East (+X)
			horiz_dir = Vector3(1.0, 0.0, 0.0)
		WindOrigin.NORTH:
			# Wind comes from North (-Z), pushing rain South (+Z)
			horiz_dir = Vector3(0.0, 0.0, 1.0)
		WindOrigin.SOUTH:
			# Wind comes from South (+Z), pushing rain North (-Z)
			horiz_dir = Vector3(0.0, 0.0, -1.0)
		WindOrigin.CUSTOM:
			if custom_wind_from.length_squared() > 0.001:
				var flat_wind = Vector3(custom_wind_from.x, 0.0, custom_wind_from.z).normalized()
				horiz_dir = -flat_wind
			else:
				horiz_dir = Vector3(-1.0, 0.0, 0.0)

	var angle_rad := deg_to_rad(clampf(wind_lean_angle_deg, 0.0, 60.0))
	var sin_a := sin(angle_rad)
	var cos_a := cos(angle_rad)

	# Combine downward velocity with horizontal wind deflection
	var dir := Vector3(horiz_dir.x * sin_a, -cos_a, horiz_dir.z * sin_a)
	return dir.normalized()

## Applies exported properties to the GPU particle emitters and meshes.
func _update_rain_parameters() -> void:
	if not rain_particles:
		rain_particles = get_node_or_null("RainParticles") as GPUParticles3D
	if not splash_particles:
		splash_particles = get_node_or_null("SplashParticles") as GPUParticles3D
	if not rain_particles:
		return

	# Reposition emitter height and amount
	rain_particles.position = Vector3(0.0, emitter_height, 0.0)
	rain_particles.amount = rain_density
	rain_particles.trail_lifetime = streak_trail_lifetime

	# Calculate lifetime so particles reach ground + buffer
	var vertical_speed: float = maxf(fall_speed * cos(deg_to_rad(wind_lean_angle_deg)), 5.0)
	var travel_time: float = (emitter_height / vertical_speed) * 1.3
	rain_particles.lifetime = clampf(travel_time, 0.5, 4.0)
	rain_particles.preprocess = rain_particles.lifetime

	# Update visibility AABB to encompass slanted spawn & travel area
	var half_w: float = area_extents.x * 0.75
	var half_d: float = area_extents.y * 0.75
	var aabb_size := Vector3(half_w * 2.0 + 10.0, emitter_height + 5.0, half_d * 2.0 + 10.0)
	var aabb_pos := Vector3(-half_w - 5.0, -emitter_height - 2.0, -half_d - 5.0)
	rain_particles.visibility_aabb = AABB(aabb_pos, aabb_size)

	# Update RibbonTrailMesh width and material color/opacity
	var mesh = rain_particles.draw_pass_1 as RibbonTrailMesh
	if mesh:
		if not mesh.resource_local_to_scene:
			mesh = mesh.duplicate() as RibbonTrailMesh
			rain_particles.draw_pass_1 = mesh
		mesh.size = streak_width

		var ribbon_mat = mesh.material as StandardMaterial3D
		if ribbon_mat:
			if not ribbon_mat.resource_local_to_scene:
				ribbon_mat = ribbon_mat.duplicate() as StandardMaterial3D
				mesh.material = ribbon_mat
			var col = rain_tint
			col.a = rain_opacity
			ribbon_mat.albedo_color = col

	# Process Material
	var mat = rain_particles.process_material as ParticleProcessMaterial
	if mat:
		if not mat.resource_local_to_scene:
			mat = mat.duplicate() as ParticleProcessMaterial
			rain_particles.process_material = mat

		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(area_extents.x * 0.5, 0.5, area_extents.y * 0.5)
		mat.direction = get_calculated_direction()
		mat.spread = streak_spread_deg
		mat.initial_velocity_min = fall_speed * 0.95
		mat.initial_velocity_max = fall_speed * 1.05
		mat.gravity = Vector3.ZERO

		var p_col = rain_tint
		p_col.a = rain_opacity
		mat.color = p_col

		# Collision and sub-emitter setup
		mat.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
		mat.collision_friction = 0.0
		mat.collision_bounce = 0.0

		if enable_splashes and splash_particles:
			mat.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
			mat.sub_emitter_amount_at_collision = 1
			mat.sub_emitter_keep_velocity = false
			rain_particles.sub_emitter = rain_particles.get_path_to(splash_particles)
			splash_particles.visible = true
			splash_particles.amount = int(clampf(rain_density * 1.5, 100.0, 3000.0))
		else:
			mat.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_DISABLED
			if splash_particles:
				splash_particles.visible = false
