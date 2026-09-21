extends Node3D

@onready var rain_effect: RainEffect = $RainEffect

@onready var preset_option: OptionButton = %PresetOption
@onready var density_slider: HSlider = %DensitySlider
@onready var density_val_label: Label = %DensityValLabel
@onready var opacity_slider: HSlider = %OpacitySlider
@onready var opacity_val_label: Label = %OpacityValLabel
@onready var width_slider: HSlider = %WidthSlider
@onready var width_val_label: Label = %WidthValLabel
@onready var angle_slider: HSlider = %AngleSlider
@onready var angle_val_label: Label = %AngleValLabel
@onready var splash_check: CheckBox = %SplashCheck

func _ready() -> void:
	if not rain_effect:
		return
		
	# Populate preset dropdown
	preset_option.clear()
	preset_option.add_item("Drizzle (Sparse)", 0)
	preset_option.add_item("Light (Default, Clean)", 1)
	preset_option.add_item("Moderate (Steady)", 2)
	preset_option.add_item("Heavy (Downpour)", 3)
	preset_option.add_item("Storm (Deluge)", 4)
	preset_option.select(1)
	preset_option.item_selected.connect(_on_preset_selected)

	# Initial values from rain effect
	_sync_ui_from_effect()

	# Connect slider signals
	density_slider.value_changed.connect(func(v: float):
		rain_effect.rain_density = int(v)
		density_val_label.text = str(int(v))
	)

	opacity_slider.value_changed.connect(func(v: float):
		rain_effect.rain_opacity = v
		opacity_val_label.text = "%.2f" % v
	)

	width_slider.value_changed.connect(func(v: float):
		rain_effect.streak_width = v
		width_val_label.text = "%.3fm" % v
	)

	angle_slider.value_changed.connect(func(v: float):
		rain_effect.wind_lean_angle_deg = v
		angle_val_label.text = "%.1f°" % v
	)

	splash_check.toggled.connect(func(t: bool):
		rain_effect.enable_splashes = t
	)

func _on_preset_selected(idx: int) -> void:
	rain_effect.weather_intensity = idx as RainEffect.WeatherIntensity
	_sync_ui_from_effect()

func _sync_ui_from_effect() -> void:
	density_slider.set_value_no_signal(rain_effect.rain_density)
	density_val_label.text = str(rain_effect.rain_density)

	opacity_slider.set_value_no_signal(rain_effect.rain_opacity)
	opacity_val_label.text = "%.2f" % rain_effect.rain_opacity

	width_slider.set_value_no_signal(rain_effect.streak_width)
	width_val_label.text = "%.3fm" % rain_effect.streak_width

	angle_slider.set_value_no_signal(rain_effect.wind_lean_angle_deg)
	angle_val_label.text = "%.1f°" % rain_effect.wind_lean_angle_deg

	splash_check.set_pressed_no_signal(rain_effect.enable_splashes)
