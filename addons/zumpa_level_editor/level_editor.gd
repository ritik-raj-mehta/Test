@tool
extends Control

const LevelDataScript = preload("res://game/scripts/data/LevelData.gd")
const ObjectDataScript = preload("res://game/scripts/data/ObjectData.gd")

@onready var canvas: Control = %Canvas
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var palette_container: VBoxContainer = %PaletteContainer

# Top Toolbar
@onready var new_btn: Button = %NewBtn
@onready var save_btn: Button = %SaveBtn
@onready var load_btn: Button = %LoadBtn
@onready var export_res_btn: Button = %ExportResBtn if has_node("%ExportResBtn") else null
@onready var export_tscn_btn: Button = %ExportTscnBtn if has_node("%ExportTscnBtn") else null
@onready var level_select_opt: OptionButton = %LevelSelectOpt

@onready var play_btn: Button = %PlayBtn
@onready var center_view_btn: Button = %CenterViewBtn
@onready var delete_btn: Button = %DeleteBtn
@onready var duplicate_btn: Button = %DuplicateBtn
@onready var undo_btn: Button = %UndoBtn if has_node("%UndoBtn") else null

var undo_stack: Array[Dictionary] = []
const MAX_UNDO_DEPTH: int = 50
@onready var snap_check: CheckBox = %SnapCheck
@onready var grid_size_opt: OptionButton = %GridSizeOpt
@onready var canvas_zoom_out_btn: Button = %CanvasZoomOutBtn
@onready var canvas_zoom_label: Label = %CanvasZoomLabel
@onready var canvas_zoom_in_btn: Button = %CanvasZoomInBtn
@onready var canvas_zoom_reset_btn: Button = %CanvasZoomResetBtn
@onready var toggle_left_btn: Button = %ToggleLeftBtn
@onready var toggle_right_btn: Button = %ToggleRightBtn
@onready var select_move_top_btn: Button = %SelectMoveTopBtn if has_node("%SelectMoveTopBtn") else null
@onready var left_panel: PanelContainer = %LeftPanel if has_node("%LeftPanel") else null

# Right Inspector
@onready var inspector_panel: PanelContainer = %InspectorPanel
@onready var type_label: Label = %TypeLabel
@onready var pos_x_spin: SpinBox = %PosXSpin
@onready var pos_y_spin: SpinBox = %PosYSpin
@onready var rot_spin: SpinBox = %RotSpin
@onready var scale_x_spin: SpinBox = %ScaleXSpin
@onready var scale_y_spin: SpinBox = %ScaleYSpin
@onready var prop_speed_row: HBoxContainer = %PropSpeedRow
@onready var rot_speed_spin: SpinBox = %RotSpeedSpin
@onready var prop_length_row: HBoxContainer = %PropLengthRow
@onready var length_spin: SpinBox = %LengthSpin
@onready var prop_breadth_row: HBoxContainer = %PropBreadthRow
@onready var breadth_spin: SpinBox = %BreadthSpin
@onready var prop_move_speed_row: HBoxContainer = %PropMoveSpeedRow
@onready var move_speed_spin: SpinBox = %MoveSpeedSpin
@onready var prop_move_angle_row: HBoxContainer = %PropMoveAngleRow
@onready var move_angle_spin: SpinBox = %MoveAngleSpin
@onready var prop_move_dist_pos_row: HBoxContainer = %PropMoveDistPosRow
@onready var move_dist_pos_spin: SpinBox = %MoveDistPosSpin
@onready var prop_move_dist_neg_row: HBoxContainer = %PropMoveDistNegRow
@onready var move_dist_neg_spin: SpinBox = %MoveDistNegSpin
@onready var prop_move_dir_row: HBoxContainer = %PropMoveDirRow
@onready var move_dir_opt: OptionButton = %MoveDirOpt
@onready var prop_loop_reset_row: HBoxContainer = %PropLoopResetRow
@onready var loop_reset_check: CheckBox = %LoopResetCheck
@onready var prop_gear_count_row: HBoxContainer = %PropGearCountRow
@onready var gear_count_spin: SpinBox = %GearCountSpin
@onready var prop_gear_spacing_row: HBoxContainer = %PropGearSpacingRow
@onready var gear_spacing_spin: SpinBox = %GearSpacingSpin
@onready var prop_move_delay_row: HBoxContainer = %PropMoveDelayRow if has_node("%PropMoveDelayRow") else null
@onready var move_delay_spin: SpinBox = %MoveDelaySpin if has_node("%MoveDelaySpin") else null
@onready var prop_enable_interval_row: HBoxContainer = %PropEnableIntervalRow if has_node("%PropEnableIntervalRow") else null
@onready var enable_interval_check: CheckBox = %EnableIntervalCheck if has_node("%EnableIntervalCheck") else null
@onready var prop_interval_time_row: HBoxContainer = %PropIntervalTimeRow if has_node("%PropIntervalTimeRow") else null
@onready var interval_time_spin: SpinBox = %IntervalTimeSpin if has_node("%IntervalTimeSpin") else null
@onready var prop_interval_speed_row: HBoxContainer = %PropIntervalSpeedRow if has_node("%PropIntervalSpeedRow") else null
@onready var interval_speed_spin: SpinBox = %IntervalSpeedSpin if has_node("%IntervalSpeedSpin") else null
@onready var prop_path_shape_row: HBoxContainer = %PropPathShapeRow if has_node("%PropPathShapeRow") else null
@onready var path_shape_opt: OptionButton = %PathShapeOpt if has_node("%PathShapeOpt") else null
@onready var prop_path_width_row: HBoxContainer = %PropPathWidthRow if has_node("%PropPathWidthRow") else null
@onready var path_width_spin: SpinBox = %PathWidthSpin if has_node("%PathWidthSpin") else null
@onready var prop_path_height_row: HBoxContainer = %PropPathHeightRow if has_node("%PropPathHeightRow") else null
@onready var path_height_spin: SpinBox = %PathHeightSpin if has_node("%PathHeightSpin") else null
@onready var prop_path_rot_row: HBoxContainer = %PropPathRotRow if has_node("%PropPathRotRow") else null
@onready var path_rot_spin: SpinBox = %PathRotSpin if has_node("%PathRotSpin") else null
@onready var prop_path_dir_row: HBoxContainer = %PropPathDirRow if has_node("%PropPathDirRow") else null
@onready var path_dir_opt: OptionButton = %PathDirOpt if has_node("%PathDirOpt") else null
@onready var prop_corner_delay_row: HBoxContainer = %PropCornerDelayRow if has_node("%PropCornerDelayRow") else null
@onready var corner_delay_spin: SpinBox = %CornerDelaySpin if has_node("%CornerDelaySpin") else null
@onready var prop_trigger_tag_row: HBoxContainer = %PropTriggerTagRow
@onready var trigger_tag_edit: LineEdit = %TriggerTagEdit
@onready var prop_fall_speed_row: HBoxContainer = %PropFallSpeedRow
@onready var fall_speed_spin: SpinBox = %FallSpeedSpin
@onready var prop_area_width_row: HBoxContainer = %PropAreaWidthRow
@onready var area_width_spin: SpinBox = %AreaWidthSpin
@onready var prop_area_height_row: HBoxContainer = %PropAreaHeightRow
@onready var area_height_spin: SpinBox = %AreaHeightSpin
@onready var prop_trigger_dist_row: HBoxContainer = %PropTriggerDistRow
@onready var trigger_dist_spin: SpinBox = %TriggerDistSpin
@onready var apply_btn: Button = %ApplyBtn

# Horizontal Zone Inspector Additions
var prop_end_offset_row: HBoxContainer
var end_offset_x_spin: SpinBox
var end_offset_y_spin: SpinBox

var prop_zone_margins_row: VBoxContainer
var zone_left_margin_spin: SpinBox
var zone_right_margin_spin: SpinBox
var zone_top_margin_spin: SpinBox
var zone_bot_margin_spin: SpinBox
var zone_h_enabled_check: CheckBox
var zone_v_enabled_check: CheckBox

# Booster Force Inspector Additions
var prop_booster_tier_row: HBoxContainer
var booster_tier_opt: OptionButton
var prop_booster_force_row: HBoxContainer
var booster_custom_force_spin: SpinBox

# ZigZag Track Inspector Additions
var prop_zigzag_box: VBoxContainer
var is_zigzag_check: CheckBox
var zigzag_width_spin: SpinBox
var zigzag_height_spin: SpinBox
var zigzag_angle_spin: SpinBox
var zigzag_count_spin: SpinBox
var zigzag_start_bottom_check: CheckBox
var enable_node_pause_check: CheckBox
var node_pause_time_spin: SpinBox
var _is_updating_inspector: bool = false


# Player Camera Drag Inspector
@onready var cam_drag_h_check: CheckBox = %CamDragHCheck if has_node("%CamDragHCheck") else null
@onready var cam_drag_v_check: CheckBox = %CamDragVCheck if has_node("%CamDragVCheck") else null
@onready var cam_left_margin_spin: SpinBox = %CamLeftMarginSpin if has_node("%CamLeftMarginSpin") else null
@onready var cam_top_margin_spin: SpinBox = %CamTopMarginSpin if has_node("%CamTopMarginSpin") else null
@onready var cam_right_margin_spin: SpinBox = %CamRightMarginSpin if has_node("%CamRightMarginSpin") else null
@onready var cam_bot_margin_spin: SpinBox = %CamBotMarginSpin if has_node("%CamBotMarginSpin") else null
@onready var cam_h_offset_spin: SpinBox = %CamHOffsetSpin if has_node("%CamHOffsetSpin") else null
@onready var cam_v_offset_spin: SpinBox = %CamVOffsetSpin if has_node("%CamVOffsetSpin") else null


# Tile Palette Inspector
@onready var atlas_x_spin: SpinBox = %AtlasXSpin
@onready var atlas_y_spin: SpinBox = %AtlasYSpin
@onready var tile_size_opt: OptionButton = %TileSizeOpt
@onready var atlas_picker: AtlasPalettePicker = %AtlasPicker
@onready var zoom_out_btn: Button = %ZoomOutBtn
@onready var zoom_label: Label = %ZoomLabel
@onready var zoom_in_btn: Button = %ZoomInBtn
@onready var zoom_fit_btn: Button = %ZoomFitBtn
@onready var atlas_scroll_container: ScrollContainer = %AtlasScrollContainer
@onready var tile_preview_rect: TextureRect = %TilePreviewRect
@onready var btn_grass_top: Button = %BtnGrassTop
@onready var btn_grass_left: Button = %BtnGrassLeft
@onready var btn_grass_right: Button = %BtnGrassRight
@onready var btn_dirt: Button = %BtnDirt
@onready var btn_sand: Button = %BtnSand
@onready var btn_stone: Button = %BtnStone

# Bottom Bar
@onready var level_id_edit: LineEdit = %LevelIDEdit
@onready var level_name_edit: LineEdit = %LevelNameEdit
@onready var world_theme_opt: OptionButton = %WorldThemeOpt
@onready var width_spin: SpinBox = %WidthSpin
@onready var height_spin: SpinBox = %HeightSpin
@onready var player_x_spin: SpinBox = %PlayerXSpin
@onready var player_y_spin: SpinBox = %PlayerYSpin

var current_level = null
var current_level_path: String = "res://game/assets/levels/level_001.tres"
var tool_buttons: Dictionary = {}
var level_paths_list: Array[String] = []
var world_theme_keys: Array[String] = []

func _ready() -> void:
	setup_grid_options()
	setup_world_theme_options()
	setup_palette()
	connect_signals()
	populate_level_selector()
	update_tile_preview()
	setup_dynamic_inspector_fields()

	# Load initial default level
	var existing_paths = LevelManager.get_all_level_paths()
	if existing_paths.size() > 0:
		var loaded = LevelManager.load_level_data(existing_paths[0])
		if loaded:
			load_level(loaded, existing_paths[0])
		else:
			new_level()
	else:
		new_level()

func setup_dynamic_inspector_fields() -> void:
	if not prop_area_height_row:
		return
	var parent_vbox = prop_area_height_row.get_parent()

	var target_index = parent_vbox.get_child_count()
	for child in parent_vbox.get_children():
		if child.name == "TileHeader" or child.name == "HSeparator2" or child == apply_btn:
			target_index = child.get_index()
			break

	# End Offset Row
	prop_end_offset_row = HBoxContainer.new()
	prop_end_offset_row.visible = false
	var lbl_end = Label.new()
	lbl_end.text = "End Offset X,Y"
	lbl_end.custom_minimum_size = Vector2(100, 0)
	end_offset_x_spin = SpinBox.new()
	end_offset_x_spin.min_value = -10000
	end_offset_x_spin.max_value = 10000
	end_offset_x_spin.step = 10.0
	end_offset_y_spin = SpinBox.new()
	end_offset_y_spin.min_value = -10000
	end_offset_y_spin.max_value = 10000
	end_offset_y_spin.step = 10.0
	prop_end_offset_row.add_child(lbl_end)
	prop_end_offset_row.add_child(end_offset_x_spin)
	prop_end_offset_row.add_child(end_offset_y_spin)
	parent_vbox.add_child(prop_end_offset_row)
	parent_vbox.move_child(prop_end_offset_row, target_index)
	target_index += 1

	# Zone Margins Row (VBox)
	prop_zone_margins_row = VBoxContainer.new()
	prop_zone_margins_row.visible = false

	var lbl_margins = Label.new()
	lbl_margins.text = "Target Camera Margins"
	prop_zone_margins_row.add_child(lbl_margins)

	var hbox_lr = HBoxContainer.new()
	zone_left_margin_spin = SpinBox.new()
	zone_left_margin_spin.min_value = 0
	zone_left_margin_spin.max_value = 1
	zone_left_margin_spin.step = 0.01
	zone_left_margin_spin.prefix = "L:"
	zone_right_margin_spin = SpinBox.new()
	zone_right_margin_spin.min_value = 0
	zone_right_margin_spin.max_value = 1
	zone_right_margin_spin.step = 0.01
	zone_right_margin_spin.prefix = "R:"
	hbox_lr.add_child(zone_left_margin_spin)
	hbox_lr.add_child(zone_right_margin_spin)
	prop_zone_margins_row.add_child(hbox_lr)

	var hbox_tb = HBoxContainer.new()
	zone_top_margin_spin = SpinBox.new()
	zone_top_margin_spin.min_value = 0
	zone_top_margin_spin.max_value = 1
	zone_top_margin_spin.step = 0.01
	zone_top_margin_spin.prefix = "T:"
	zone_bot_margin_spin = SpinBox.new()
	zone_bot_margin_spin.min_value = 0
	zone_bot_margin_spin.max_value = 1
	zone_bot_margin_spin.step = 0.01
	zone_bot_margin_spin.prefix = "B:"
	hbox_tb.add_child(zone_top_margin_spin)
	hbox_tb.add_child(zone_bot_margin_spin)
	prop_zone_margins_row.add_child(hbox_tb)

	var hbox_checks = HBoxContainer.new()
	zone_h_enabled_check = CheckBox.new()
	zone_h_enabled_check.text = "H Drag"
	zone_v_enabled_check = CheckBox.new()
	zone_v_enabled_check.text = "V Drag"
	hbox_checks.add_child(zone_h_enabled_check)
	hbox_checks.add_child(zone_v_enabled_check)
	prop_zone_margins_row.add_child(hbox_checks)

	parent_vbox.add_child(prop_zone_margins_row)
	parent_vbox.move_child(prop_zone_margins_row, target_index)
	target_index += 1

	# Booster Tier Row
	prop_booster_tier_row = HBoxContainer.new()
	prop_booster_tier_row.visible = false
	var lbl_bt = Label.new()
	lbl_bt.text = "Booster Force"
	lbl_bt.custom_minimum_size = Vector2(100, 0)
	booster_tier_opt = OptionButton.new()
	booster_tier_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	booster_tier_opt.add_item("Tier 1 - Low (650)", 1)
	booster_tier_opt.add_item("Tier 2 - Medium (950)", 2)
	booster_tier_opt.add_item("Tier 3 - High (1300)", 3)
	booster_tier_opt.add_item("Tier 4 - Super (1700)", 4)
	booster_tier_opt.add_item("Tier 5 - Mega (2200)", 5)
	booster_tier_opt.select(1)
	prop_booster_tier_row.add_child(lbl_bt)
	prop_booster_tier_row.add_child(booster_tier_opt)
	parent_vbox.add_child(prop_booster_tier_row)
	parent_vbox.move_child(prop_booster_tier_row, target_index)
	target_index += 1

	# Booster Custom Force Row
	prop_booster_force_row = HBoxContainer.new()
	prop_booster_force_row.visible = false
	var lbl_bf = Label.new()
	lbl_bf.text = "Custom Force"
	lbl_bf.custom_minimum_size = Vector2(100, 0)
	booster_custom_force_spin = SpinBox.new()
	booster_custom_force_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	booster_custom_force_spin.min_value = 0
	booster_custom_force_spin.max_value = 10000
	booster_custom_force_spin.step = 50.0
	prop_booster_force_row.add_child(lbl_bf)
	prop_booster_force_row.add_child(booster_custom_force_spin)
	parent_vbox.add_child(prop_booster_force_row)
	parent_vbox.move_child(prop_booster_force_row, target_index)
	target_index += 1

	# ZigZag Track Inspector Box
	prop_zigzag_box = VBoxContainer.new()
	prop_zigzag_box.name = "ZigZagControlBox"
	prop_zigzag_box.visible = false

	var lbl_zz_hdr = Label.new()
	lbl_zz_hdr.text = "⚡ ZigZag Track Settings"
	prop_zigzag_box.add_child(lbl_zz_hdr)

	is_zigzag_check = CheckBox.new()
	is_zigzag_check.text = "Enable ZigZag Path"
	prop_zigzag_box.add_child(is_zigzag_check)

	var hbox_zz_dim = HBoxContainer.new()
	zigzag_width_spin = SpinBox.new()
	zigzag_width_spin.min_value = 50
	zigzag_width_spin.max_value = 5000
	zigzag_width_spin.step = 10
	zigzag_width_spin.prefix = "Width:"
	zigzag_width_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	zigzag_height_spin = SpinBox.new()
	zigzag_height_spin.min_value = 20
	zigzag_height_spin.max_value = 2000
	zigzag_height_spin.step = 10
	zigzag_height_spin.prefix = "Height:"
	zigzag_height_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	hbox_zz_dim.add_child(zigzag_width_spin)
	hbox_zz_dim.add_child(zigzag_height_spin)
	prop_zigzag_box.add_child(hbox_zz_dim)

	var hbox_zz_cnt = HBoxContainer.new()
	var lbl_zz_cnt = Label.new()
	lbl_zz_cnt.text = "ZigZag Levels:"
	lbl_zz_cnt.custom_minimum_size = Vector2(90, 0)
	zigzag_count_spin = SpinBox.new()
	zigzag_count_spin.min_value = 1
	zigzag_count_spin.max_value = 30
	zigzag_count_spin.step = 1
	zigzag_count_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_zz_cnt.add_child(lbl_zz_cnt)
	hbox_zz_cnt.add_child(zigzag_count_spin)
	prop_zigzag_box.add_child(hbox_zz_cnt)

	var hbox_zz_ang = HBoxContainer.new()
	var lbl_zz_ang = Label.new()
	lbl_zz_ang.text = "Diagonal Angle:"
	lbl_zz_ang.custom_minimum_size = Vector2(90, 0)
	zigzag_angle_spin = SpinBox.new()
	zigzag_angle_spin.min_value = 10
	zigzag_angle_spin.max_value = 80
	zigzag_angle_spin.step = 1
	zigzag_angle_spin.suffix = "°"
	zigzag_angle_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_zz_ang.add_child(lbl_zz_ang)
	hbox_zz_ang.add_child(zigzag_angle_spin)
	prop_zigzag_box.add_child(hbox_zz_ang)

	zigzag_start_bottom_check = CheckBox.new()
	zigzag_start_bottom_check.text = "Start Gears from Bottom"
	prop_zigzag_box.add_child(zigzag_start_bottom_check)

	enable_node_pause_check = CheckBox.new()
	enable_node_pause_check.text = "Enable Node Interval Pause"
	prop_zigzag_box.add_child(enable_node_pause_check)

	var hbox_zz_p = HBoxContainer.new()
	var lbl_zz_p = Label.new()
	lbl_zz_p.text = "Node Pause Time:"
	lbl_zz_p.custom_minimum_size = Vector2(110, 0)
	node_pause_time_spin = SpinBox.new()
	node_pause_time_spin.min_value = 0.0
	node_pause_time_spin.max_value = 10.0
	node_pause_time_spin.step = 0.1
	node_pause_time_spin.suffix = "s"
	node_pause_time_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_zz_p.add_child(lbl_zz_p)
	hbox_zz_p.add_child(node_pause_time_spin)
	prop_zigzag_box.add_child(hbox_zz_p)

	parent_vbox.add_child(prop_zigzag_box)
	parent_vbox.move_child(prop_zigzag_box, target_index)
	target_index += 1

func setup_grid_options() -> void:
	grid_size_opt.clear()
	grid_size_opt.add_item("16 px", 16)
	grid_size_opt.add_item("32 px", 32)
	grid_size_opt.add_item("64 px", 64)
	grid_size_opt.add_item("128 px", 128)
	grid_size_opt.select(1) # 32px default

func setup_world_theme_options() -> void:
	world_theme_opt.clear()
	world_theme_keys.clear()
	var themes = WorldThemeRegistry.get_all_themes()
	var idx = 0
	for key in themes:
		world_theme_keys.append(key)
		world_theme_opt.add_item(themes[key].get("name", key), idx)
		idx += 1

func setup_palette() -> void:
	for child in palette_container.get_children():
		child.queue_free()
	tool_buttons.clear()

	# 1. PRIMARY TOOLS (Top)
	# Select/Move Tool
	var select_btn := Button.new()
	select_btn.text = "✋ Select / Move"
	select_btn.toggle_mode = true
	select_btn.button_pressed = true
	select_btn.pressed.connect(func(): set_active_tool("", select_btn))
	palette_container.add_child(select_btn)
	tool_buttons[""] = select_btn

	if select_move_top_btn:
		select_move_top_btn.toggle_mode = true
		select_move_top_btn.button_pressed = true
		if not select_move_top_btn.pressed.is_connected(set_active_tool):
			select_move_top_btn.pressed.connect(func(): set_active_tool("", select_move_top_btn))

	# Player Start Tool
	var p_btn := Button.new()
	p_btn.text = "🚩 Player Start"
	p_btn.toggle_mode = true
	p_btn.pressed.connect(func(): set_active_tool("player_start", p_btn))
	palette_container.add_child(p_btn)
	tool_buttons["player_start"] = p_btn

	# 2. OBSTACLES & ITEMS BUTTONS
	var entries = ObjectRegistry.get_all_entries()
	for id in entries:
		var entry = entries[id]
		var btn := Button.new()
		btn.text = "+ " + entry.get("name", id)
		btn.toggle_mode = true
		btn.clip_text = true
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(func(): set_active_tool(id, btn))
		palette_container.add_child(btn)
		tool_buttons[id] = btn

	# Separator before Tile Map Tools
	var sep_tile := HSeparator.new()
	palette_container.add_child(sep_tile)

	var tile_hdr := Label.new()
	tile_hdr.text = "TILE MAP TOOLS"
	tile_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	palette_container.add_child(tile_hdr)

	# 3. TILE MAP TOOLS (Bottom)
	# Tile Brush Tool
	var tb_btn := Button.new()
	tb_btn.text = "🧱 Draw Tile"
	tb_btn.toggle_mode = true
	tb_btn.pressed.connect(func(): set_active_tool("tile_brush", tb_btn))
	palette_container.add_child(tb_btn)
	tool_buttons["tile_brush"] = tb_btn

	# Tile Eraser Tool
	var te_btn := Button.new()
	te_btn.text = "🧹 Erase Tile"
	te_btn.toggle_mode = true
	te_btn.pressed.connect(func(): set_active_tool("tile_eraser", te_btn))
	palette_container.add_child(te_btn)
	tool_buttons["tile_eraser"] = te_btn

	# Area Select & Pattern Fill Tool
	var as_btn := Button.new()
	as_btn.text = "📐 Area Select & Fill"
	as_btn.toggle_mode = true
	as_btn.pressed.connect(func(): set_active_tool("area_select", as_btn))
	palette_container.add_child(as_btn)
	tool_buttons["area_select"] = as_btn

	# Tile Scatter Tool
	var ts_btn := Button.new()
	ts_btn.text = "🎲 Scatter Tiles"
	ts_btn.toggle_mode = true
	ts_btn.pressed.connect(func(): set_active_tool("tile_scatter", ts_btn))
	palette_container.add_child(ts_btn)
	tool_buttons["tile_scatter"] = ts_btn

	# Area Pattern & Fill Controls Container
	var area_box := VBoxContainer.new()
	area_box.name = "AreaPatternControls"

	var lbl_mode := Label.new()
	lbl_mode.text = "Fill Mode:"
	area_box.add_child(lbl_mode)

	var mode_opt := OptionButton.new()
	mode_opt.add_item("🎲 Random Pattern", 0)
	mode_opt.add_item("🧱 100% Solid Fill", 1)
	mode_opt.add_item("🎨 Multi-Tile Mix", 2)
	mode_opt.select(0)
	mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_opt.item_selected.connect(func(idx):
		if canvas:
			canvas.pattern_fill_mode = idx
			if canvas.has_selected_area:
				canvas.queue_redraw()
	)
	area_box.add_child(mode_opt)

	var scatter_row := HBoxContainer.new()
	var lbl_sc := Label.new()
	lbl_sc.text = "Tile Count:"
	lbl_sc.custom_minimum_size = Vector2(75, 0)
	var spin_sc := SpinBox.new()
	spin_sc.min_value = 1
	spin_sc.max_value = 2000
	spin_sc.step = 1
	spin_sc.value = 30
	spin_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_sc.value_changed.connect(func(v):
		if canvas:
			canvas.scatter_tile_count = int(v)
			if canvas.has_selected_area and canvas.pattern_fill_mode == 0:
				push_undo_snapshot()
				canvas.fill_selected_area()
	)
	scatter_row.add_child(lbl_sc)
	scatter_row.add_child(spin_sc)
	area_box.add_child(scatter_row)

	var btn_fill := Button.new()
	btn_fill.text = "🎲 Fill Area"
	btn_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_fill.pressed.connect(func():
		if canvas and canvas.has_selected_area:
			push_undo_snapshot()
			canvas.fill_selected_area()
	)
	area_box.add_child(btn_fill)

	var btn_reroll := Button.new()
	btn_reroll.text = "🔀 Re-roll Pattern"
	btn_reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reroll.pressed.connect(func():
		if canvas and canvas.has_selected_area:
			push_undo_snapshot()
			canvas.reroll_area_pattern()
	)
	area_box.add_child(btn_reroll)

	var btn_clear_tiles := Button.new()
	btn_clear_tiles.text = "🧹 Clear Tiles"
	btn_clear_tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_clear_tiles.pressed.connect(func():
		if canvas and canvas.has_selected_area:
			push_undo_snapshot()
			canvas.clear_tiles_in_selected_area()
	)
	area_box.add_child(btn_clear_tiles)

	var btn_deselect := Button.new()
	btn_deselect.text = "✕ Deselect Area"
	btn_deselect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_deselect.pressed.connect(func():
		if canvas:
			canvas.clear_selected_area()
	)
	area_box.add_child(btn_deselect)

	var btn_scatter_view := Button.new()
	btn_scatter_view.text = "📱 Scatter in View"
	btn_scatter_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_scatter_view.pressed.connect(func(): _scatter_in_current_view())
	area_box.add_child(btn_scatter_view)

	palette_container.add_child(area_box)

func populate_level_selector() -> void:
	level_select_opt.clear()
	level_paths_list = LevelManager.get_all_level_paths()

	var selected_idx = -1
	for i in range(level_paths_list.size()):
		var path = level_paths_list[i]
		var file_name = path.get_file()
		level_select_opt.add_item(file_name, i)
		if path == current_level_path:
			selected_idx = i

	if level_paths_list.size() > 0:
		if selected_idx >= 0:
			level_select_opt.select(selected_idx)
		else:
			level_select_opt.select(0)
	elif current_level:
		var unsaved_name = current_level_path.get_file() + " (Unsaved)"
		level_select_opt.add_item(unsaved_name, 0)
		level_select_opt.select(0)

func set_active_tool(id: String, active_btn: Button) -> void:
	canvas.active_placement_id = id
	for tool_id in tool_buttons:
		tool_buttons[tool_id].button_pressed = (tool_buttons[tool_id] == active_btn or (id == "" and tool_id == ""))

	if select_move_top_btn:
		select_move_top_btn.button_pressed = (id == "")

	# Deselect persistent area selection when switching away from area selection / scatter tools
	if id != "area_select" and id != "tile_scatter":
		if canvas and canvas.has_selected_area:
			canvas.clear_selected_area()

	if id == "player_start":
		set_camera_drag_section_visible(true)
	elif canvas.selected_object == null:
		set_camera_drag_section_visible(false)

func set_camera_drag_section_visible(vis: bool) -> void:
	var sep = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/HSeparatorCam") as Control
	if sep: sep.visible = vis
	var head = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/CamHeader") as Control
	if head: head.visible = vis

	if cam_drag_h_check and cam_drag_h_check.get_parent(): (cam_drag_h_check.get_parent() as Control).visible = vis
	if cam_drag_v_check and cam_drag_v_check.get_parent(): (cam_drag_v_check.get_parent() as Control).visible = vis
	if cam_left_margin_spin and cam_left_margin_spin.get_parent(): (cam_left_margin_spin.get_parent() as Control).visible = vis
	if cam_top_margin_spin and cam_top_margin_spin.get_parent(): (cam_top_margin_spin.get_parent() as Control).visible = vis
	if cam_right_margin_spin and cam_right_margin_spin.get_parent(): (cam_right_margin_spin.get_parent() as Control).visible = vis
	if cam_bot_margin_spin and cam_bot_margin_spin.get_parent(): (cam_bot_margin_spin.get_parent() as Control).visible = vis
	if cam_h_offset_spin and cam_h_offset_spin.get_parent(): (cam_h_offset_spin.get_parent() as Control).visible = vis
	if cam_v_offset_spin and cam_v_offset_spin.get_parent(): (cam_v_offset_spin.get_parent() as Control).visible = vis

func connect_signals() -> void:
	var new_popup = get_node_or_null("NewLevelPopupMenu") as PopupMenu
	if not new_popup:
		new_popup = PopupMenu.new()
		new_popup.name = "NewLevelPopupMenu"
		new_popup.add_item("📋 New from Template (Level 1 Starter)", 0)
		new_popup.add_item("📄 New Blank Level", 1)
		add_child(new_popup)
		new_popup.id_pressed.connect(func(id: int):
			if id == 0:
				new_level_from_template()
			elif id == 1:
				new_level_blank()
		)

	new_btn.pressed.connect(func():
		var btn_rect = new_btn.get_global_rect()
		new_popup.position = Vector2i(int(btn_rect.position.x), int(btn_rect.position.y + btn_rect.size.y + 4.0))
		new_popup.popup()
	)
	save_btn.pressed.connect(on_save_pressed)
	load_btn.pressed.connect(on_load_pressed)
	if export_res_btn:
		export_res_btn.pressed.connect(on_export_res_pressed)
	if export_tscn_btn:
		export_tscn_btn.pressed.connect(on_export_tscn_pressed)
	play_btn.pressed.connect(on_play_pressed)
	center_view_btn.pressed.connect(center_view_on_player)
	delete_btn.pressed.connect(delete_selected)
	duplicate_btn.pressed.connect(duplicate_selected)
	level_select_opt.item_selected.connect(on_level_selected_from_opt)


	snap_check.toggled.connect(func(toggled):
		canvas.grid_snap = toggled
		canvas.queue_redraw()
	)
	grid_size_opt.item_selected.connect(func(idx):
		canvas.grid_size = grid_size_opt.get_item_id(idx)
		canvas.queue_redraw()
	)

	if canvas:
		canvas.zoom_changed.connect(func(z):
			if canvas_zoom_label:
				canvas_zoom_label.text = " %d%% " % int(z * 100)
		)

	if canvas_zoom_out_btn:
		canvas_zoom_out_btn.pressed.connect(func():
			if canvas and scroll_container:
				canvas.zoom_at_center(1.0 / 1.2, scroll_container)
		)
	if canvas_zoom_in_btn:
		canvas_zoom_in_btn.pressed.connect(func():
			if canvas and scroll_container:
				canvas.zoom_at_center(1.2, scroll_container)
		)
	if canvas_zoom_reset_btn:
		canvas_zoom_reset_btn.pressed.connect(func():
			if canvas and scroll_container:
				canvas.set_zoom_level(1.0, scroll_container)
		)

	if toggle_left_btn:
		toggle_left_btn.toggled.connect(func(pressed):
			var items_hdr = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/ItemsHeader") as Control
			if items_hdr: items_hdr.visible = pressed
			var sep_items = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/HSeparatorItems") as Control
			if sep_items: sep_items.visible = pressed
			if palette_container: palette_container.visible = pressed
			var sep_end = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/HSeparatorItemsEnd") as Control
			if sep_end: sep_end.visible = pressed
		)

	if toggle_right_btn:
		toggle_right_btn.toggled.connect(func(pressed):
			var obj_hdr = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/Header") as Control
			if obj_hdr: obj_hdr.visible = pressed
			var type_row = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/TypeRow") as Control
			if type_row: type_row.visible = pressed
			var pos_x = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/PosXRow") as Control
			if pos_x: pos_x.visible = pressed
			var pos_y = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/PosYRow") as Control
			if pos_y: pos_y.visible = pressed
			var rot_r = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/RotRow") as Control
			if rot_r: rot_r.visible = pressed
			var sx_r = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/ScaleXRow") as Control
			if sx_r: sx_r.visible = pressed
			var sy_r = get_node_or_null("MainVBox/ContentHBox/InspectorPanel/InspectorScroll/VBox/ScaleYRow") as Control
			if sy_r: sy_r.visible = pressed
			if apply_btn: apply_btn.visible = pressed
		)

	resized.connect(on_container_resized)
	if scroll_container:
		scroll_container.resized.connect(on_container_resized)

	canvas.object_selected.connect(on_object_selected)
	canvas.object_moved.connect(update_inspector_values)
	canvas.player_start_changed.connect(on_player_start_changed)
	if canvas.has_signal("snapshot_requested"):
		canvas.snapshot_requested.connect(push_undo_snapshot)

	if not undo_btn and has_node("MainVBox/TopBarPanel/TopBar"):
		var top_bar = get_node("MainVBox/TopBarPanel/TopBar")
		undo_btn = Button.new()
		undo_btn.name = "UndoBtn"
		undo_btn.text = " ↩ Undo (Ctrl+Z) "
		undo_btn.disabled = true
		var save_node = top_bar.get_node_or_null("SaveBtn")
		if save_node:
			top_bar.add_child(undo_btn)
			top_bar.move_child(undo_btn, save_node.get_index() + 1)
		else:
			top_bar.add_child(undo_btn)

	if undo_btn:
		if not undo_btn.pressed.is_connected(undo_last_change):
			undo_btn.pressed.connect(undo_last_change)

	apply_btn.pressed.connect(apply_inspector_changes)

	pos_x_spin.value_changed.connect(func(_v): apply_inspector_changes())
	pos_y_spin.value_changed.connect(func(_v): apply_inspector_changes())
	rot_spin.value_changed.connect(func(_v): apply_inspector_changes())
	scale_x_spin.value_changed.connect(func(_v): apply_inspector_changes())
	scale_y_spin.value_changed.connect(func(_v): apply_inspector_changes())

	rot_speed_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if length_spin: length_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if breadth_spin: breadth_spin.value_changed.connect(func(_v): apply_inspector_changes())
	move_speed_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if move_angle_spin: move_angle_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if move_dist_pos_spin: move_dist_pos_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if move_dist_neg_spin: move_dist_neg_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if move_dir_opt: move_dir_opt.item_selected.connect(_on_move_dir_preset_selected)
	if loop_reset_check: loop_reset_check.toggled.connect(func(_t): apply_inspector_changes())
	if gear_count_spin: gear_count_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if gear_spacing_spin: gear_spacing_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if move_delay_spin: move_delay_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if path_shape_opt: path_shape_opt.item_selected.connect(func(_i): apply_inspector_changes())
	if path_width_spin: path_width_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if path_height_spin: path_height_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if path_rot_spin: path_rot_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if path_dir_opt: path_dir_opt.item_selected.connect(func(_i): apply_inspector_changes())
	if corner_delay_spin: corner_delay_spin.value_changed.connect(func(_v): apply_inspector_changes())
	trigger_tag_edit.text_changed.connect(func(_t): apply_inspector_changes())
	fall_speed_spin.value_changed.connect(func(_v): apply_inspector_changes())
	area_width_spin.value_changed.connect(func(_v): apply_inspector_changes())
	area_height_spin.value_changed.connect(func(_v): apply_inspector_changes())
	trigger_dist_spin.value_changed.connect(func(_v): apply_inspector_changes())

	if end_offset_x_spin: end_offset_x_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if end_offset_y_spin: end_offset_y_spin.value_changed.connect(func(_v): apply_inspector_changes())

	if zone_left_margin_spin: zone_left_margin_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if zone_right_margin_spin: zone_right_margin_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if zone_top_margin_spin: zone_top_margin_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if zone_bot_margin_spin: zone_bot_margin_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if zone_h_enabled_check: zone_h_enabled_check.toggled.connect(func(_t): apply_inspector_changes())
	if zone_v_enabled_check: zone_v_enabled_check.toggled.connect(func(_t): apply_inspector_changes())

	if booster_tier_opt: booster_tier_opt.item_selected.connect(func(_idx): apply_inspector_changes())
	if booster_custom_force_spin: booster_custom_force_spin.value_changed.connect(func(_v): apply_inspector_changes())

	if is_zigzag_check: is_zigzag_check.toggled.connect(func(_t): apply_inspector_changes())
	if zigzag_width_spin: zigzag_width_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if zigzag_height_spin: zigzag_height_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if zigzag_angle_spin: zigzag_angle_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if zigzag_count_spin: zigzag_count_spin.value_changed.connect(func(_v): apply_inspector_changes())
	if zigzag_start_bottom_check: zigzag_start_bottom_check.toggled.connect(func(_t): apply_inspector_changes())
	if enable_node_pause_check: enable_node_pause_check.toggled.connect(func(_t): apply_inspector_changes())
	if node_pause_time_spin: node_pause_time_spin.value_changed.connect(func(_v): apply_inspector_changes())

	# Tile Palette signals
	if atlas_picker:
		atlas_picker.tile_selected.connect(on_atlas_tile_selected)
		if atlas_picker.has_signal("multi_tiles_selected"):
			atlas_picker.multi_tiles_selected.connect(func(tiles):
				if canvas:
					canvas.current_palette_tiles = tiles
					if canvas.has_selected_area:
						push_undo_snapshot()
						canvas.fill_selected_area()
			)
		atlas_picker.zoom_changed.connect(func(z):
			if zoom_label:
				zoom_label.text = "%.1fx" % z
		)

		if atlas_scroll_container and atlas_scroll_container.get_parent():
			var p_node = atlas_scroll_container.get_parent()
			if not p_node.has_node("MultiSelectTileRow"):
				var ms_row := HBoxContainer.new()
				ms_row.name = "MultiSelectTileRow"
				var chk_ms := CheckBox.new()
				chk_ms.text = "Multi-Select Mode"
				chk_ms.toggled.connect(func(toggled):
					atlas_picker.multi_select_mode = toggled
				)
				var btn_single := Button.new()
				btn_single.text = " Reset (1 Tile) "
				btn_single.pressed.connect(func():
					atlas_picker.clear_tile_selection()
				)
				ms_row.add_child(chk_ms)
				ms_row.add_child(btn_single)
				p_node.add_child(ms_row)
				p_node.move_child(ms_row, atlas_scroll_container.get_index())

	if zoom_out_btn:
		zoom_out_btn.pressed.connect(func():
			if atlas_picker:
				atlas_picker.zoom_scale -= 0.5
		)
	if zoom_in_btn:
		zoom_in_btn.pressed.connect(func():
			if atlas_picker:
				atlas_picker.zoom_scale += 0.5
		)
	if zoom_fit_btn:
		zoom_fit_btn.pressed.connect(func():
			if atlas_picker and atlas_scroll_container and atlas_picker.texture:
				var cols = atlas_picker._get_cols()
				var avail_w = atlas_scroll_container.size.x - 10
				if cols > 0 and avail_w > 0:
					atlas_picker.zoom_scale = max(0.5, avail_w / (cols * 16.0))
		)

	atlas_x_spin.value_changed.connect(func(_v): update_tile_preview())
	atlas_y_spin.value_changed.connect(func(_v): update_tile_preview())

	if tile_size_opt:
		tile_size_opt.item_selected.connect(func(idx):
			var ts_id = tile_size_opt.get_item_id(idx)
			var theme_id = "world_1"
			if current_level:
				theme_id = current_level.world_theme
			WorldThemeRegistry.set_theme_tile_size(theme_id, Vector2i(ts_id, ts_id))
			update_tile_preview()
			if canvas:
				canvas.refresh_canvas()
		)

	btn_grass_top.pressed.connect(func(): _apply_preset_tile(6, 5))
	btn_grass_left.pressed.connect(func(): _apply_preset_tile(0, 3))
	btn_grass_right.pressed.connect(func(): _apply_preset_tile(1, 3))
	btn_dirt.pressed.connect(func(): _apply_preset_tile(6, 2))
	btn_sand.pressed.connect(func(): _apply_preset_tile(7, 1))
	btn_stone.pressed.connect(func(): _apply_preset_tile(11, 1))

	# Bottom bar edits
	level_id_edit.text_changed.connect(func(t): if current_level: current_level.level_id = t)
	level_name_edit.text_changed.connect(func(t): if current_level: current_level.level_name = t)
	world_theme_opt.item_selected.connect(func(idx):
		if current_level and idx >= 0 and idx < world_theme_keys.size():
			current_level.world_theme = world_theme_keys[idx]
			WorldThemeRegistry.set_current_theme(current_level.world_theme)
			var theme_info = WorldThemeRegistry.get_theme(current_level.world_theme)
			var def_atlas: Vector2i = theme_info.get("default_atlas_coords", Vector2i(1, 1))
			set_tile_atlas(def_atlas.x, def_atlas.y)
			canvas.refresh_canvas()
			canvas.queue_redraw()
	)
	width_spin.value_changed.connect(func(v):
		if current_level:
			current_level.level_size.x = v
			player_x_spin.max_value = max(5000.0, v)
			canvas.update_canvas_size()
			canvas.queue_redraw()
			call_deferred("center_view_on_player")
	)
	height_spin.value_changed.connect(func(v):
		if current_level:
			var old_h = current_level.level_size.y
			current_level.level_size.y = v
			canvas.refresh_canvas()
			if scroll_container and canvas:
				var delta_h = (v - old_h) * canvas.zoom_scale
				scroll_container.scroll_vertical += int(delta_h)
	)
	player_x_spin.value_changed.connect(func(v):
		if current_level:
			current_level.player_start.x = v
			canvas.refresh_canvas()
	)
	player_y_spin.value_changed.connect(func(v):
		if current_level:
			current_level.player_start.y = v
			canvas.refresh_canvas()
	)

	# Camera Drag Signals
	if cam_drag_h_check:
		cam_drag_h_check.toggled.connect(func(t): if current_level: current_level.camera_drag_horizontal_enabled = t)
	if cam_drag_v_check:
		cam_drag_v_check.toggled.connect(func(t): if current_level: current_level.camera_drag_vertical_enabled = t)
	if cam_left_margin_spin:
		cam_left_margin_spin.value_changed.connect(func(v): if current_level: current_level.camera_drag_left_margin = v)
	if cam_top_margin_spin:
		cam_top_margin_spin.value_changed.connect(func(v): if current_level: current_level.camera_drag_top_margin = v)
	if cam_right_margin_spin:
		cam_right_margin_spin.value_changed.connect(func(v): if current_level: current_level.camera_drag_right_margin = v)
	if cam_bot_margin_spin:
		cam_bot_margin_spin.value_changed.connect(func(v): if current_level: current_level.camera_drag_bottom_margin = v)
	if cam_h_offset_spin:
		cam_h_offset_spin.value_changed.connect(func(v): if current_level: current_level.camera_drag_horizontal_offset = v)
	if cam_v_offset_spin:
		cam_v_offset_spin.value_changed.connect(func(v): if current_level: current_level.camera_drag_vertical_offset = v)


func on_atlas_tile_selected(coords: Vector2i) -> void:
	set_tile_atlas(coords.x, coords.y)
	if canvas:
		canvas.current_tile_atlas = coords
		if atlas_picker:
			canvas.current_palette_tiles = atlas_picker.selected_tiles
		if canvas.has_selected_area and (canvas.active_placement_id == "area_select" or canvas.active_placement_id == "tile_scatter"):
			push_undo_snapshot()
			canvas.fill_selected_area()
			return
	if canvas and (canvas.active_placement_id == "tile_scatter" or canvas.active_placement_id == "area_select"):
		return
	if tool_buttons.has("tile_brush"):
		set_active_tool("tile_brush", tool_buttons["tile_brush"])

func _apply_preset_tile(ax: int, ay: int) -> void:
	set_tile_atlas(ax, ay)
	if canvas:
		canvas.current_tile_atlas = Vector2i(ax, ay)
		canvas.current_palette_tiles = [Vector2i(ax, ay)]
		if canvas.has_selected_area and (canvas.active_placement_id == "area_select" or canvas.active_placement_id == "tile_scatter"):
			push_undo_snapshot()
			canvas.fill_selected_area()

func _scatter_in_current_view() -> void:
	if not canvas or not current_level:
		return
	push_undo_snapshot()
	var screen_w: float = 1080.0
	var screen_h: float = 1920.0
	var player_pos: Vector2 = current_level.player_start
	var top_w_y: float = player_pos.y - 1300.0
	var rect := Rect2(player_pos.x - (screen_w / 2.0), top_w_y, screen_w, screen_h)
	canvas.scatter_random_tiles_in_rect(rect, canvas.scatter_tile_count)

func set_tile_atlas(ax: int, ay: int) -> void:
	atlas_x_spin.value = ax
	atlas_y_spin.value = ay
	if atlas_picker:
		atlas_picker.selected_coords = Vector2i(ax, ay)
		atlas_picker.ensure_selected_visible(atlas_scroll_container)
	update_tile_preview()

func update_tile_preview() -> void:
	var ax = int(atlas_x_spin.value)
	var ay = int(atlas_y_spin.value)
	canvas.current_tile_atlas = Vector2i(ax, ay)

	var theme_id = "world_1"
	if current_level:
		theme_id = current_level.world_theme
	var theme_info = WorldThemeRegistry.get_theme(theme_id)
	var tex_path: String = WorldThemeRegistry.resolve_texture_path(theme_info.get("platform_texture", "res://game/assets/sprites/atlases/tiles/Green.png"))
	var t_size: Vector2i = theme_info.get("tile_size", Vector2i(16, 16))

	if tile_size_opt:
		for i in range(tile_size_opt.item_count):
			if tile_size_opt.get_item_id(i) == t_size.x:
				tile_size_opt.select(i)
				break

	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path)
		if atlas_picker:
			atlas_picker.tile_size = t_size
			if atlas_picker.texture != tex:
				atlas_picker.texture = tex
			atlas_picker.selected_coords = Vector2i(ax, ay)

		var atlas_tex := AtlasTexture.new()
		atlas_tex.atlas = tex
		atlas_tex.region = Rect2(ax * t_size.x, ay * t_size.y, t_size.x, t_size.y)
		tile_preview_rect.texture = atlas_tex

func on_level_selected_from_opt(idx: int) -> void:
	if idx >= 0 and idx < level_paths_list.size():
		var path = level_paths_list[idx]
		var loaded = LevelManager.load_level_data(path)
		if loaded:
			load_level(loaded, path)

func get_next_level_info() -> Dictionary:
	var existing = LevelManager.get_all_level_paths()
	var max_num = 0
	for path in existing:
		var file_name = path.get_file().get_basename()
		if file_name.begins_with("level_"):
			var num_str = file_name.replace("level_", "")
			if num_str.is_valid_int():
				var num = num_str.to_int()
				if num > max_num:
					max_num = num
	var new_num = max_num + 1
	var new_id = "level_%03d" % new_num
	var target_path = "res://game/assets/levels/%s.tres" % new_id
	return {"num": new_num, "id": new_id, "path": target_path}

func new_level_from_template() -> void:
	var info = get_next_level_info()
	var new_num: int = info.num
	var new_id: String = info.id
	var target_path: String = info.path

	var tpl_path = "res://game/assets/levels/level_Template.tres"
	var tpl: LevelData = null
	if ResourceLoader.exists(tpl_path):
		tpl = ResourceLoader.load(tpl_path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelData
	elif ResourceLoader.exists("res://game/assets/levels/level_001.tres"):
		tpl = ResourceLoader.load("res://game/assets/levels/level_001.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as LevelData

	current_level = LevelDataScript.new()
	current_level.level_id = new_id
	current_level.level_name = "Level %d" % new_num

	if tpl:
		current_level.world_theme = tpl.world_theme
		current_level.level_size = tpl.level_size
		current_level.player_start = tpl.player_start
		current_level.camera_drag_horizontal_enabled = tpl.camera_drag_horizontal_enabled
		current_level.camera_drag_vertical_enabled = tpl.camera_drag_vertical_enabled
		current_level.camera_drag_horizontal_offset = tpl.camera_drag_horizontal_offset
		current_level.camera_drag_vertical_offset = tpl.camera_drag_vertical_offset
		current_level.camera_drag_left_margin = tpl.camera_drag_left_margin
		current_level.camera_drag_top_margin = tpl.camera_drag_top_margin
		current_level.camera_drag_right_margin = tpl.camera_drag_right_margin
		current_level.camera_drag_bottom_margin = tpl.camera_drag_bottom_margin
		current_level.packed_tiles = tpl.packed_tiles.duplicate()
		for obj in tpl.objects:
			if obj:
				current_level.add_object(obj.duplicate_data())
	else:
		current_level.world_theme = "world_1"
		current_level.level_size = Vector2(1080, 2500)
		current_level.player_start = Vector2(540, 1135)
		current_level.camera_drag_horizontal_enabled = true
		current_level.camera_drag_vertical_enabled = true
		current_level.camera_drag_left_margin = 0.8
		current_level.camera_drag_top_margin = 0.6
		current_level.camera_drag_right_margin = 0.8
		current_level.camera_drag_bottom_margin = 0.2
		var goal_obj = ObjectDataScript.new("goal", Vector2(540, -627))
		current_level.add_object(goal_obj)
		var start_tiles: Array[int] = [6, 25, 1, 1, 7, 25, 1, 1, 8, 25, 1, 1, 9, 25, 1, 1, 10, 25, 1, 1, 11, 25, 1, 1, 12, 25, 1, 1, 13, 25, 1, 1, 14, 25, 1, 1, 15, 25, 1, 1, 16, 25, 1, 1]
		current_level.packed_tiles = PackedInt32Array(start_tiles)

	load_level(current_level, target_path)
	push_undo_snapshot()

func new_level_blank() -> void:
	var info = get_next_level_info()
	var new_num: int = info.num
	var new_id: String = info.id
	var target_path: String = info.path

	current_level = LevelDataScript.new()
	current_level.level_id = new_id
	current_level.level_name = "Level %d" % new_num
	current_level.world_theme = "world_1"
	current_level.level_size = Vector2(1080, 3000)
	var center_x = current_level.level_size.x / 2.0
	current_level.player_start = Vector2(center_x, 1135)

	# Add default win area at center
	var win = ObjectDataScript.new("goal", Vector2(center_x, -627))
	current_level.add_object(win)

	load_level(current_level, target_path)
	push_undo_snapshot()

func new_level() -> void:
	new_level_from_template()

func load_level(lvl, path: String) -> void:
	current_level = lvl
	current_level_path = path
	LevelManager.active_level_path = path
	LevelManager.current_level_data = lvl
	canvas.set_level_data(lvl)

	level_id_edit.text = lvl.level_id
	level_name_edit.text = lvl.level_name

	# Select world theme in option button
	var theme_idx = world_theme_keys.find(lvl.world_theme)
	if theme_idx != -1:
		world_theme_opt.select(theme_idx)
	else:
		world_theme_opt.select(0)

	var theme_info = WorldThemeRegistry.get_theme(lvl.world_theme)
	var def_atlas: Vector2i = theme_info.get("default_atlas_coords", Vector2i(1, 1))
	set_tile_atlas(def_atlas.x, def_atlas.y)

	width_spin.value = lvl.level_size.x
	height_spin.value = lvl.level_size.y
	player_x_spin.max_value = max(5000.0, lvl.level_size.x)
	player_x_spin.value = lvl.player_start.x
	player_y_spin.value = lvl.player_start.y

	if cam_drag_h_check: cam_drag_h_check.button_pressed = lvl.camera_drag_horizontal_enabled
	if cam_drag_v_check: cam_drag_v_check.button_pressed = lvl.camera_drag_vertical_enabled
	if cam_left_margin_spin: cam_left_margin_spin.value = lvl.camera_drag_left_margin
	if cam_top_margin_spin: cam_top_margin_spin.value = lvl.camera_drag_top_margin
	if cam_right_margin_spin: cam_right_margin_spin.value = lvl.camera_drag_right_margin
	if cam_bot_margin_spin: cam_bot_margin_spin.value = lvl.camera_drag_bottom_margin
	if cam_h_offset_spin: cam_h_offset_spin.value = lvl.camera_drag_horizontal_offset
	if cam_v_offset_spin: cam_v_offset_spin.value = lvl.camera_drag_vertical_offset

	populate_level_selector()
	on_object_selected(null)
	call_deferred("center_view_on_player")


func on_container_resized() -> void:
	if canvas:
		canvas.update_canvas_size()
		canvas.queue_redraw()

func center_view_on_player() -> void:
	if not current_level or not scroll_container or not canvas:
		return
	var target_c_x = canvas.world_to_canvas(current_level.player_start).x
	var target_c_y = canvas.world_to_canvas(current_level.player_start).y
	var scroll_val_x = int(target_c_x - scroll_container.size.x / 2.0)
	var scroll_val_y = int(target_c_y - scroll_container.size.y / 2.0)
	scroll_container.scroll_horizontal = max(0, scroll_val_x)
	scroll_container.scroll_vertical = max(0, scroll_val_y)

func _on_move_dir_preset_selected(idx: int) -> void:
	if _is_updating_inspector:
		return
	match idx:
		1: # +X & -X (Horiz 0°)
			if move_angle_spin: move_angle_spin.value = 0.0
		2: # +X Only (Right)
			if move_angle_spin: move_angle_spin.value = 0.0
			if move_dist_neg_spin: move_dist_neg_spin.value = 0.0
		3: # -X Only (Left)
			if move_angle_spin: move_angle_spin.value = 0.0
			if move_dist_pos_spin: move_dist_pos_spin.value = 0.0
		4: # +Y & -Y (Vert 90°)
			if move_angle_spin: move_angle_spin.value = 90.0
		5: # +Y Only (Down)
			if move_angle_spin: move_angle_spin.value = 90.0
			if move_dist_neg_spin: move_dist_neg_spin.value = 0.0
		6: # -Y Only (Up)
			if move_angle_spin: move_angle_spin.value = 90.0
			if move_dist_pos_spin: move_dist_pos_spin.value = 0.0
		7: # Diagonal 45°
			if move_angle_spin: move_angle_spin.value = 45.0
		8: # Diagonal -45°
			if move_angle_spin: move_angle_spin.value = -45.0
	apply_inspector_changes()

func on_object_selected(obj) -> void:
	if not obj:
		type_label.text = "None Selected"
		pos_x_spin.editable = false
		pos_y_spin.editable = false
		rot_spin.editable = false
		scale_x_spin.editable = false
		scale_y_spin.editable = false
		prop_speed_row.visible = false
		if prop_length_row: prop_length_row.visible = false
		if prop_breadth_row: prop_breadth_row.visible = false
		prop_move_speed_row.visible = false
		if prop_move_angle_row: prop_move_angle_row.visible = false
		if prop_move_dist_pos_row: prop_move_dist_pos_row.visible = false
		if prop_move_dist_neg_row: prop_move_dist_neg_row.visible = false
		prop_move_dir_row.visible = false
		if prop_loop_reset_row: prop_loop_reset_row.visible = false
		if prop_gear_count_row: prop_gear_count_row.visible = false
		if prop_gear_spacing_row: prop_gear_spacing_row.visible = false
		if prop_move_delay_row: prop_move_delay_row.visible = false
		if prop_path_shape_row: prop_path_shape_row.visible = false
		if prop_path_width_row: prop_path_width_row.visible = false
		if prop_path_height_row: prop_path_height_row.visible = false
		if prop_path_rot_row: prop_path_rot_row.visible = false
		if prop_path_dir_row: prop_path_dir_row.visible = false
		if prop_corner_delay_row: prop_corner_delay_row.visible = false
		prop_trigger_tag_row.visible = false
		prop_fall_speed_row.visible = false
		prop_area_width_row.visible = false
		prop_area_height_row.visible = false
		prop_trigger_dist_row.visible = false
		if prop_end_offset_row: prop_end_offset_row.visible = false
		if prop_zone_margins_row: prop_zone_margins_row.visible = false
		if prop_booster_tier_row: prop_booster_tier_row.visible = false
		if prop_booster_force_row: prop_booster_force_row.visible = false
		apply_btn.disabled = true
		delete_btn.disabled = true
		duplicate_btn.disabled = true

		if canvas and canvas.active_placement_id == "player_start":
			set_camera_drag_section_visible(true)
		else:
			set_camera_drag_section_visible(false)
		return

	type_label.text = obj.object_id
	pos_x_spin.editable = true
	pos_y_spin.editable = true
	rot_spin.editable = true
	scale_x_spin.editable = true
	scale_y_spin.editable = true
	apply_btn.disabled = false
	delete_btn.disabled = false
	duplicate_btn.disabled = false

	update_inspector_values(obj)

func update_inspector_values(obj) -> void:
	if not obj:
		return
	_is_updating_inspector = true
	pos_x_spin.value = obj.position.x
	pos_y_spin.value = obj.position.y
	rot_spin.value = obj.rotation
	scale_x_spin.value = obj.scale.x
	scale_y_spin.value = obj.scale.y

	if obj.properties.has("rotation_speed"):
		prop_speed_row.visible = true
		rot_speed_spin.value = obj.properties["rotation_speed"]
	else:
		prop_speed_row.visible = false

	if obj.properties.has("length"):
		if prop_length_row: prop_length_row.visible = true
		if length_spin: length_spin.value = float(obj.properties["length"])
		if prop_breadth_row: prop_breadth_row.visible = true
		if breadth_spin: breadth_spin.value = float(obj.properties.get("breadth", obj.properties.get("width", 8.0)))
	elif obj.properties.has("breadth") or obj.properties.has("width"):
		if prop_length_row: prop_length_row.visible = false
		if prop_breadth_row: prop_breadth_row.visible = true
		if breadth_spin: breadth_spin.value = float(obj.properties.get("breadth", obj.properties.get("width", 8.0)))
	else:
		if prop_length_row: prop_length_row.visible = false
		if prop_breadth_row: prop_breadth_row.visible = false

	var has_movement = obj.properties.has("move_speed") or obj.properties.has("move_distance") or obj.properties.has("move_dist_pos") or obj.properties.has("move_angle") or obj.properties.has("move_direction")

	if has_movement:
		prop_move_speed_row.visible = true
		move_speed_spin.value = float(obj.properties.get("move_speed", 100.0))

		if prop_move_angle_row: prop_move_angle_row.visible = true
		if prop_move_dist_pos_row: prop_move_dist_pos_row.visible = true
		if prop_move_dist_neg_row: prop_move_dist_neg_row.visible = true
		if prop_move_dir_row: prop_move_dir_row.visible = true

		var angle = float(obj.properties.get("move_angle", 0.0))
		var pos_dist = float(obj.properties.get("move_dist_pos", -1.0))
		var neg_dist = float(obj.properties.get("move_dist_neg", -1.0))

		if pos_dist < 0.0 or neg_dist < 0.0:
			var legacy_dist = float(obj.properties.get("move_distance", 200.0))
			var legacy_dir = str(obj.properties.get("move_direction", "X")).to_upper()
			match legacy_dir:
				"+X", "RIGHT":
					angle = 0.0
					pos_dist = legacy_dist
					neg_dist = 0.0
				"-X", "LEFT":
					angle = 0.0
					pos_dist = 0.0
					neg_dist = legacy_dist
				"Y", "BOTH_Y", "+Y & -Y":
					angle = 90.0
					pos_dist = legacy_dist
					neg_dist = legacy_dist
				"+Y", "DOWN":
					angle = 90.0
					pos_dist = legacy_dist
					neg_dist = 0.0
				"-Y", "UP":
					angle = 90.0
					pos_dist = 0.0
					neg_dist = legacy_dist
				_:
					angle = 0.0
					pos_dist = legacy_dist
					neg_dist = legacy_dist

		if move_angle_spin: move_angle_spin.value = angle
		if move_dist_pos_spin: move_dist_pos_spin.value = pos_dist
		if move_dist_neg_spin: move_dist_neg_spin.value = neg_dist

		# Determine matching preset in move_dir_opt
		if move_dir_opt:
			if is_equal_approx(angle, 0.0):
				if pos_dist > 0.0 and neg_dist > 0.0 and is_equal_approx(pos_dist, neg_dist):
					move_dir_opt.select(1)
				elif pos_dist > 0.0 and neg_dist <= 0.0:
					move_dir_opt.select(2)
				elif pos_dist <= 0.0 and neg_dist > 0.0:
					move_dir_opt.select(3)
				else:
					move_dir_opt.select(0)
			elif is_equal_approx(angle, 90.0):
				if pos_dist > 0.0 and neg_dist > 0.0 and is_equal_approx(pos_dist, neg_dist):
					move_dir_opt.select(4)
				elif pos_dist > 0.0 and neg_dist <= 0.0:
					move_dir_opt.select(5)
				elif pos_dist <= 0.0 and neg_dist > 0.0:
					move_dir_opt.select(6)
				else:
					move_dir_opt.select(0)
			elif is_equal_approx(angle, 45.0):
				move_dir_opt.select(7)
			elif is_equal_approx(angle, -45.0):
				move_dir_opt.select(8)
			else:
				move_dir_opt.select(0)
	else:
		prop_move_speed_row.visible = false
		if prop_move_angle_row: prop_move_angle_row.visible = false
		if prop_move_dist_pos_row: prop_move_dist_pos_row.visible = false
		if prop_move_dist_neg_row: prop_move_dist_neg_row.visible = false
		if prop_move_dir_row: prop_move_dir_row.visible = false

	if obj.object_id == "spike" or obj.properties.has("spike_count") or obj.properties.has("wall_distance"):
		if prop_loop_reset_row: prop_loop_reset_row.visible = false
		if prop_gear_count_row:
			prop_gear_count_row.visible = true
			var count_lbl = prop_gear_count_row.get_node_or_null("Lbl")
			if count_lbl: count_lbl.text = "Spike Count: "
			if gear_count_spin: gear_count_spin.value = int(obj.properties.get("spike_count", obj.properties.get("count", 1)))
		if prop_gear_spacing_row:
			prop_gear_spacing_row.visible = true
			var dist_lbl = prop_gear_spacing_row.get_node_or_null("Lbl")
			if dist_lbl: dist_lbl.text = "Wall Distance: "
			if gear_spacing_spin: gear_spacing_spin.value = float(obj.properties.get("wall_distance", obj.properties.get("spacing", 46.0)))
	elif obj.object_id in ["gear_with_rod", "gear_m"] or obj.properties.has("gear_count") or obj.properties.has("loop_reset"):
		if prop_loop_reset_row:
			prop_loop_reset_row.visible = (obj.object_id == "gear_with_rod" or obj.properties.has("loop_reset"))
			if loop_reset_check: loop_reset_check.button_pressed = bool(obj.properties.get("loop_reset", true))
		if prop_gear_count_row:
			prop_gear_count_row.visible = true
			var count_lbl = prop_gear_count_row.get_node_or_null("Lbl")
			if count_lbl: count_lbl.text = "Gear Count: "
			if gear_count_spin: gear_count_spin.value = int(obj.properties.get("gear_count", 1))
		if prop_gear_spacing_row:
			prop_gear_spacing_row.visible = true
			var dist_lbl = prop_gear_spacing_row.get_node_or_null("Lbl")
			if dist_lbl: dist_lbl.text = "Gear Spacing: "
			if gear_spacing_spin: gear_spacing_spin.value = float(obj.properties.get("gear_spacing", 100.0))
		if prop_breadth_row and (obj.object_id == "gear_with_rod" or obj.properties.has("rod_breadth")):
			prop_breadth_row.visible = true
			if breadth_spin: breadth_spin.value = float(obj.properties.get("rod_breadth", obj.properties.get("breadth", 8.0)))
	else:
		if prop_loop_reset_row: prop_loop_reset_row.visible = false
		if prop_gear_count_row: prop_gear_count_row.visible = false
		if prop_gear_spacing_row: prop_gear_spacing_row.visible = false

	if obj.object_id in ["gear_m", "gear_with_rod", "gear_path"] or obj.properties.has("enable_interval_movement") or obj.properties.has("interval_time"):
		if prop_enable_interval_row:
			prop_enable_interval_row.visible = true
			if enable_interval_check: enable_interval_check.button_pressed = bool(obj.properties.get("enable_interval_movement", false))
		if prop_interval_time_row:
			prop_interval_time_row.visible = true
			if interval_time_spin: interval_time_spin.value = float(obj.properties.get("interval_time", 3.0))
		if prop_interval_speed_row:
			prop_interval_speed_row.visible = true
			if interval_speed_spin: interval_speed_spin.value = float(obj.properties.get("interval_speed", obj.properties.get("move_speed", 150.0)))
	else:
		if prop_enable_interval_row: prop_enable_interval_row.visible = false
		if prop_interval_time_row: prop_interval_time_row.visible = false
		if prop_interval_speed_row: prop_interval_speed_row.visible = false

	if obj.object_id == "gear_m" or obj.properties.has("direction_change_delay") or obj.properties.has("delay"):
		if prop_move_delay_row:
			prop_move_delay_row.visible = true
			if move_delay_spin: move_delay_spin.value = float(obj.properties.get("direction_change_delay", obj.properties.get("delay", 0.0)))
	else:
		if prop_move_delay_row: prop_move_delay_row.visible = false

	if obj.object_id == "gear_path" or obj.properties.has("path_shape"):
		if prop_path_shape_row:
			prop_path_shape_row.visible = true
			var shape_str = str(obj.properties.get("path_shape", "Diamond")).to_upper()
			match shape_str:
				"CIRCLE": path_shape_opt.select(0)
				"RECTANGLE": path_shape_opt.select(1)
				"SQUARE": path_shape_opt.select(2)
				"TRIANGLE": path_shape_opt.select(3)
				"DIAMOND", _: path_shape_opt.select(4)
		if prop_path_width_row:
			prop_path_width_row.visible = true
			path_width_spin.value = float(obj.properties.get("path_width", 300.0))
		if prop_path_height_row:
			prop_path_height_row.visible = true
			path_height_spin.value = float(obj.properties.get("path_height", 300.0))
		if prop_path_rot_row:
			prop_path_rot_row.visible = true
			path_rot_spin.value = float(obj.properties.get("path_rotation", 0.0))
		if prop_path_dir_row:
			prop_path_dir_row.visible = true
			var dir_str = str(obj.properties.get("move_direction", "Clockwise")).to_upper()
			match dir_str:
				"COUNTER-CLOCKWISE", "COUNTER_CLOCKWISE": path_dir_opt.select(1)
				"ALTERNATING": path_dir_opt.select(2)
				_: path_dir_opt.select(0)
		if prop_corner_delay_row:
			prop_corner_delay_row.visible = true
			corner_delay_spin.value = float(obj.properties.get("corner_delay", 0.0))
		if prop_gear_count_row:
			prop_gear_count_row.visible = true
			gear_count_spin.value = int(obj.properties.get("gear_count", 2))
		if prop_move_speed_row:
			prop_move_speed_row.visible = true
			move_speed_spin.value = float(obj.properties.get("move_speed", 150.0))
	else:
		if prop_path_shape_row: prop_path_shape_row.visible = false
		if prop_path_width_row: prop_path_width_row.visible = false
		if prop_path_height_row: prop_path_height_row.visible = false
		if prop_path_rot_row: prop_path_rot_row.visible = false
		if prop_path_dir_row: prop_path_dir_row.visible = false
		if prop_corner_delay_row: prop_corner_delay_row.visible = false

	if obj.properties.has("trigger_tag"):
		prop_trigger_tag_row.visible = true
		trigger_tag_edit.text = str(obj.properties["trigger_tag"])
	else:
		prop_trigger_tag_row.visible = false

	if obj.properties.has("fall_speed"):
		prop_fall_speed_row.visible = true
		fall_speed_spin.value = float(obj.properties["fall_speed"])
	else:
		prop_fall_speed_row.visible = false

	if obj.properties.has("area_width"):
		prop_area_width_row.visible = true
		area_width_spin.value = float(obj.properties["area_width"])
	else:
		prop_area_width_row.visible = false

	if obj.properties.has("area_height"):
		prop_area_height_row.visible = true
		area_height_spin.value = float(obj.properties["area_height"])
	else:
		prop_area_height_row.visible = false

	if obj.properties.has("trigger_distance_y"):
		prop_trigger_dist_row.visible = true
		trigger_dist_spin.value = float(obj.properties["trigger_distance_y"])
	else:
		prop_trigger_dist_row.visible = false

	if prop_end_offset_row:
		if obj.properties.has("end_offset_x"):
			prop_end_offset_row.visible = true
			end_offset_x_spin.value = float(obj.properties["end_offset_x"])
			end_offset_y_spin.value = float(obj.properties.get("end_offset_y", 0.0))
		else:
			prop_end_offset_row.visible = false

	if prop_zone_margins_row:
		if obj.properties.has("target_drag_left_margin"):
			prop_zone_margins_row.visible = true
			zone_left_margin_spin.value = float(obj.properties["target_drag_left_margin"])
			zone_right_margin_spin.value = float(obj.properties["target_drag_right_margin"])
			zone_top_margin_spin.value = float(obj.properties["target_drag_top_margin"])
			zone_bot_margin_spin.value = float(obj.properties["target_drag_bottom_margin"])
			zone_h_enabled_check.button_pressed = bool(obj.properties.get("horizontal_drag_enabled", true))
			zone_v_enabled_check.button_pressed = bool(obj.properties.get("vertical_drag_enabled", true))
		else:
			prop_zone_margins_row.visible = false

	if prop_booster_tier_row and prop_booster_force_row:
		if obj.object_id == "booster" or obj.properties.has("force_tier"):
			prop_booster_tier_row.visible = true
			prop_booster_force_row.visible = true
			var tier = int(obj.properties.get("force_tier", 2))
			for i in range(booster_tier_opt.item_count):
				if booster_tier_opt.get_item_id(i) == tier:
					booster_tier_opt.select(i)
					break
			booster_custom_force_spin.value = float(obj.properties.get("custom_force", 0.0))
		else:
			prop_booster_tier_row.visible = false
			prop_booster_force_row.visible = false

	if prop_zigzag_box:
		if obj.object_id == "gear_zigzag" or obj.properties.has("is_zigzag") or obj.properties.has("zigzag_width"):
			prop_zigzag_box.visible = true
			is_zigzag_check.button_pressed = bool(obj.properties.get("is_zigzag", true))
			zigzag_width_spin.value = float(obj.properties.get("zigzag_width", 400.0))
			zigzag_height_spin.value = float(obj.properties.get("zigzag_height", 180.0))
			zigzag_angle_spin.value = float(obj.properties.get("zigzag_angle", 45.0))
			zigzag_count_spin.value = int(obj.properties.get("zigzag_count", 4))
			zigzag_start_bottom_check.button_pressed = bool(obj.properties.get("zigzag_start_from_bottom", false))
			enable_node_pause_check.button_pressed = bool(obj.properties.get("enable_node_pause", false))
			node_pause_time_spin.value = float(obj.properties.get("node_pause_time", 0.5))
		else:
			prop_zigzag_box.visible = false

	var is_cam_drag_obj = (obj.object_id == "horizontal_zone_start" or obj.object_id == "horizontal_zone_end" or obj.object_id == "horizontal_zone_trigger")
	var is_player = (canvas and canvas.active_placement_id == "player_start")
	set_camera_drag_section_visible(is_cam_drag_obj or is_player)
	_is_updating_inspector = false

func apply_inspector_changes() -> void:
	if _is_updating_inspector or not canvas or not canvas.selected_object:
		return
	var obj = canvas.selected_object
	obj.position = Vector2(pos_x_spin.value, pos_y_spin.value)
	obj.rotation = rot_spin.value
	obj.scale = Vector2(scale_x_spin.value, scale_y_spin.value)

	if prop_speed_row.visible:
		obj.properties["rotation_speed"] = rot_speed_spin.value
	if prop_length_row and prop_length_row.visible:
		obj.properties["length"] = length_spin.value
	if prop_breadth_row and prop_breadth_row.visible:
		obj.properties["breadth"] = breadth_spin.value
		obj.properties["width"] = breadth_spin.value
	if prop_move_speed_row.visible:
		obj.properties["move_speed"] = move_speed_spin.value
	if prop_move_angle_row and prop_move_angle_row.visible:
		obj.properties["move_angle"] = move_angle_spin.value
	if prop_move_dist_pos_row and prop_move_dist_pos_row.visible:
		obj.properties["move_dist_pos"] = move_dist_pos_spin.value
	if prop_move_dist_neg_row and prop_move_dist_neg_row.visible:
		obj.properties["move_dist_neg"] = move_dist_neg_spin.value
		# Backward compatibility values
		obj.properties["move_distance"] = max(move_dist_pos_spin.value, move_dist_neg_spin.value)
		if is_equal_approx(move_angle_spin.value, 0.0):
			if move_dist_pos_spin.value > 0 and move_dist_neg_spin.value == 0:
				obj.properties["move_direction"] = "+X"
			elif move_dist_pos_spin.value == 0 and move_dist_neg_spin.value > 0:
				obj.properties["move_direction"] = "-X"
			else:
				obj.properties["move_direction"] = "X"
		elif is_equal_approx(move_angle_spin.value, 90.0):
			if move_dist_pos_spin.value > 0 and move_dist_neg_spin.value == 0:
				obj.properties["move_direction"] = "+Y"
			elif move_dist_pos_spin.value == 0 and move_dist_neg_spin.value > 0:
				obj.properties["move_direction"] = "-Y"
			else:
				obj.properties["move_direction"] = "Y"
		else:
			obj.properties["move_direction"] = "CUSTOM"

	if prop_gear_count_row and prop_gear_count_row.visible:
		if obj.object_id == "spike" or obj.properties.has("spike_count"):
			obj.properties["spike_count"] = int(gear_count_spin.value)
		else:
			obj.properties["gear_count"] = int(gear_count_spin.value)
	if prop_gear_spacing_row and prop_gear_spacing_row.visible:
		if obj.object_id == "spike" or obj.properties.has("wall_distance"):
			obj.properties["wall_distance"] = gear_spacing_spin.value
		else:
			obj.properties["gear_spacing"] = gear_spacing_spin.value
	if prop_move_delay_row and prop_move_delay_row.visible:
		obj.properties["direction_change_delay"] = move_delay_spin.value
	if prop_enable_interval_row and prop_enable_interval_row.visible:
		obj.properties["enable_interval_movement"] = enable_interval_check.button_pressed
	if prop_interval_time_row and prop_interval_time_row.visible:
		obj.properties["interval_time"] = interval_time_spin.value
	if prop_interval_speed_row and prop_interval_speed_row.visible:
		obj.properties["interval_speed"] = interval_speed_spin.value

	if prop_path_shape_row and prop_path_shape_row.visible:
		var shapes = ["Circle", "Rectangle", "Square", "Triangle", "Diamond"]
		obj.properties["path_shape"] = shapes[path_shape_opt.selected] if path_shape_opt.selected < shapes.size() else "Diamond"
	if prop_path_width_row and prop_path_width_row.visible:
		obj.properties["path_width"] = path_width_spin.value
	if prop_path_height_row and prop_path_height_row.visible:
		obj.properties["path_height"] = path_height_spin.value
	if prop_path_rot_row and prop_path_rot_row.visible:
		obj.properties["path_rotation"] = path_rot_spin.value
	if prop_path_dir_row and prop_path_dir_row.visible:
		var dirs = ["Clockwise", "Counter-Clockwise", "Alternating"]
		obj.properties["move_direction"] = dirs[path_dir_opt.selected] if path_dir_opt.selected < dirs.size() else "Clockwise"
	if prop_corner_delay_row and prop_corner_delay_row.visible:
		obj.properties["corner_delay"] = corner_delay_spin.value

	if prop_loop_reset_row and prop_loop_reset_row.visible:
		obj.properties["loop_reset"] = loop_reset_check.button_pressed
		if prop_breadth_row and prop_breadth_row.visible:
			obj.properties["rod_breadth"] = breadth_spin.value

	if prop_trigger_tag_row.visible:
		obj.properties["trigger_tag"] = trigger_tag_edit.text
	if prop_fall_speed_row.visible:
		obj.properties["fall_speed"] = fall_speed_spin.value
	if prop_area_width_row.visible:
		obj.properties["area_width"] = area_width_spin.value
	if prop_area_height_row.visible:
		obj.properties["area_height"] = area_height_spin.value
	if prop_trigger_dist_row.visible:
		obj.properties["trigger_distance_y"] = trigger_dist_spin.value

	if prop_end_offset_row and prop_end_offset_row.visible:
		obj.properties["end_offset_x"] = end_offset_x_spin.value
		obj.properties["end_offset_y"] = end_offset_y_spin.value

	if prop_zone_margins_row and prop_zone_margins_row.visible:
		obj.properties["target_drag_left_margin"] = zone_left_margin_spin.value
		obj.properties["target_drag_right_margin"] = zone_right_margin_spin.value
		obj.properties["target_drag_top_margin"] = zone_top_margin_spin.value
		obj.properties["target_drag_bottom_margin"] = zone_bot_margin_spin.value
		obj.properties["horizontal_drag_enabled"] = zone_h_enabled_check.button_pressed
		obj.properties["vertical_drag_enabled"] = zone_v_enabled_check.button_pressed

	if prop_booster_tier_row and prop_booster_tier_row.visible:
		obj.properties["force_tier"] = booster_tier_opt.get_selected_id()
	if prop_booster_force_row and prop_booster_force_row.visible:
		obj.properties["custom_force"] = booster_custom_force_spin.value

	if prop_zigzag_box and prop_zigzag_box.visible:
		obj.properties["is_zigzag"] = is_zigzag_check.button_pressed
		obj.properties["zigzag_width"] = zigzag_width_spin.value
		obj.properties["zigzag_height"] = zigzag_height_spin.value
		obj.properties["zigzag_angle"] = zigzag_angle_spin.value
		obj.properties["zigzag_count"] = int(zigzag_count_spin.value)
		obj.properties["zigzag_start_from_bottom"] = zigzag_start_bottom_check.button_pressed
		obj.properties["enable_node_pause"] = enable_node_pause_check.button_pressed
		obj.properties["node_pause_time"] = node_pause_time_spin.value

	canvas.refresh_canvas()

func on_player_start_changed(pos: Vector2) -> void:
	player_x_spin.value = pos.x
	player_y_spin.value = pos.y

func delete_selected() -> void:
	if canvas and canvas.selected_object and current_level:
		push_undo_snapshot()
		current_level.remove_object(canvas.selected_object)
		canvas.selected_object = null
		canvas.refresh_canvas()
		on_object_selected(null)

func duplicate_selected() -> void:
	if canvas and canvas.selected_object and current_level:
		push_undo_snapshot()
		var dup = canvas.selected_object.duplicate_data()
		dup.position += Vector2(40, 40)
		current_level.add_object(dup)
		canvas.selected_object = dup
		canvas.refresh_canvas()
		on_object_selected(dup)

func snapshot_level_state() -> Dictionary:
	if not current_level:
		return {}
	var objs_copy: Array = []
	for obj in current_level.objects:
		objs_copy.append(obj.duplicate_data())

	return {
		"level_id": current_level.level_id,
		"level_name": current_level.level_name,
		"world_theme": current_level.world_theme,
		"player_start": current_level.player_start,
		"level_size": current_level.level_size,
		"camera_drag_horizontal_enabled": current_level.camera_drag_horizontal_enabled,
		"camera_drag_vertical_enabled": current_level.camera_drag_vertical_enabled,
		"camera_drag_left_margin": current_level.camera_drag_left_margin,
		"camera_drag_top_margin": current_level.camera_drag_top_margin,
		"camera_drag_right_margin": current_level.camera_drag_right_margin,
		"camera_drag_bottom_margin": current_level.camera_drag_bottom_margin,
		"camera_drag_horizontal_offset": current_level.camera_drag_horizontal_offset,
		"camera_drag_vertical_offset": current_level.camera_drag_vertical_offset,
		"packed_tiles": current_level.packed_tiles.duplicate(),
		"objects": objs_copy
	}

func push_undo_snapshot() -> void:
	if not current_level:
		return
	var snap = snapshot_level_state()
	undo_stack.append(snap)
	if undo_stack.size() > MAX_UNDO_DEPTH:
		undo_stack.remove_at(0)
	if undo_btn:
		undo_btn.disabled = false

func undo_last_change() -> void:
	if undo_stack.is_empty():
		return
	var last_snap = undo_stack.pop_back()
	restore_level_snapshot(last_snap)
	if undo_btn:
		undo_btn.disabled = undo_stack.is_empty()

func restore_level_snapshot(snap: Dictionary) -> void:
	if snap.is_empty() or not current_level:
		return
	current_level.level_id = snap.get("level_id", "level_001")
	current_level.level_name = snap.get("level_name", "Level 1")
	current_level.world_theme = snap.get("world_theme", "world_1")
	current_level.player_start = snap.get("player_start", Vector2(529, 1135))
	current_level.level_size = snap.get("level_size", Vector2(1080, 2500))
	current_level.camera_drag_horizontal_enabled = snap.get("camera_drag_horizontal_enabled", true)
	current_level.camera_drag_vertical_enabled = snap.get("camera_drag_vertical_enabled", true)
	current_level.camera_drag_left_margin = snap.get("camera_drag_left_margin", 0.8)
	current_level.camera_drag_top_margin = snap.get("camera_drag_top_margin", 0.6)
	current_level.camera_drag_right_margin = snap.get("camera_drag_right_margin", 0.8)
	current_level.camera_drag_bottom_margin = snap.get("camera_drag_bottom_margin", 0.2)
	current_level.camera_drag_horizontal_offset = snap.get("camera_drag_horizontal_offset", 0.0)
	current_level.camera_drag_vertical_offset = snap.get("camera_drag_vertical_offset", 0.0)
	current_level.packed_tiles = (snap.get("packed_tiles", PackedInt32Array()) as PackedInt32Array).duplicate()

	current_level.clear_objects()
	var objs_snap: Array = snap.get("objects", [])
	for obj_data in objs_snap:
		if obj_data is ObjectData:
			current_level.add_object(obj_data.duplicate_data())

	if canvas:
		canvas.selected_object = null
		canvas.refresh_canvas()
	on_object_selected(null)

func on_save_pressed() -> void:
	if current_level_path != "":
		save_level_to_file(current_level_path)
	else:
		_show_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, save_level_to_file)

func save_level_to_file(path: String) -> void:
	if current_level:
		LevelManager.save_level_data(current_level, path)
		current_level_path = path

		# Auto-sync: Always update matching .tscn and .res files so gameplay matches editor 100%
		var base_path = path.get_basename()
		var res_path = base_path + ".res"
		if ResourceLoader.exists(res_path) or FileAccess.file_exists(res_path):
			LevelManager.bake_level_to_res(current_level, res_path)

		var tscn_path = base_path + ".tscn"
		LevelManager.bake_level_to_tscn(current_level, tscn_path)

		populate_level_selector()

func on_export_res_pressed() -> void:
	if current_level and current_level_path != "":
		save_level_to_file(current_level_path)
		var res_path = current_level_path.get_basename() + ".res"
		var err = LevelManager.bake_level_to_res(current_level, res_path)
		if err == OK:
			print("LevelEditor: Exported binary resource -> %s" % res_path)
	elif current_level:
		on_save_pressed()

func on_export_tscn_pressed() -> void:
	if current_level and current_level_path != "":
		save_level_to_file(current_level_path)
		var tscn_path = current_level_path.get_basename() + ".tscn"
		var err = LevelManager.bake_level_to_tscn(current_level, tscn_path)
		if err == OK:
			print("LevelEditor: Exported pre-baked scene -> %s" % tscn_path)
	elif current_level:
		on_save_pressed()

func on_load_pressed() -> void:
	_show_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, load_level_from_file)

func _show_file_dialog(mode: FileDialog.FileMode, callback: Callable) -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.current_dir = "res://game/assets/levels/"
	dialog.filters = PackedStringArray(["*.tres ; Godot Resource File", "*.res ; Binary Level File", "*.tscn ; Scene File"])
	dialog.file_selected.connect(func(path: String) -> void:
		dialog.queue_free()
		callback.call(path)
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 550))



func load_level_from_file(path: String) -> void:
	var loaded = LevelManager.load_level_data(path)
	if loaded:
		load_level(loaded, path)

func on_play_pressed() -> void:
	if current_level and current_level_path != "":
		save_level_to_file(current_level_path)
		LevelManager.set_active_level_path(current_level_path)
		LevelManager.current_level_data = current_level
	elif current_level:
		on_save_pressed()
		LevelManager.set_active_level_path(current_level_path)
		LevelManager.current_level_data = current_level

	# Ensure latest level is baked to .tscn
	if current_level and current_level_path != "":
		var tscn_p = current_level_path.get_basename() + ".tscn"
		LevelManager.bake_level_to_tscn(current_level, tscn_p)

	var scene_path: String = ScenePaths.GAMEPLAY if ResourceLoader.exists(ScenePaths.GAMEPLAY) else "res://game/scenes/gameplay/GamePLay.tscn"
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_iface = Engine.get_singleton("EditorInterface")
		if editor_iface and editor_iface.has_method("play_custom_scene"):
			editor_iface.play_custom_scene(scene_path)
		else:
			get_tree().change_scene_to_file(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var ke := event as InputEventKey
		if ke.keycode == KEY_Z and ke.ctrl_pressed:
			undo_last_change()
			get_viewport().set_input_as_handled()
			return
		elif ke.keycode == KEY_ESCAPE:
			if canvas and canvas.has_selected_area:
				canvas.clear_selected_area()
				get_viewport().set_input_as_handled()
				return
		elif ke.keycode == KEY_R and not ke.ctrl_pressed:
			var focus_owner = get_viewport().gui_get_focus_owner()
			if not (focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox):
				if canvas and canvas.has_selected_area:
					push_undo_snapshot()
					canvas.reroll_area_pattern()
					get_viewport().set_input_as_handled()
					return
		elif ke.keycode == KEY_DELETE or ke.keycode == KEY_BACKSPACE:
			var focus_owner = get_viewport().gui_get_focus_owner()
			if not (focus_owner is LineEdit or focus_owner is TextEdit):
				if canvas and canvas.selected_object:
					delete_selected()
					get_viewport().set_input_as_handled()
					return
				elif canvas and canvas.has_selected_area:
					push_undo_snapshot()
					canvas.clear_tiles_in_selected_area()
					get_viewport().set_input_as_handled()
					return
		elif ke.keycode == KEY_D and ke.ctrl_pressed:
			duplicate_selected()
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_S and ke.ctrl_pressed:
			on_save_pressed()
			get_viewport().set_input_as_handled()
		elif ke.ctrl_pressed and (ke.keycode == KEY_EQUAL or ke.keycode == KEY_KP_ADD or ke.keycode == KEY_PLUS):
			if canvas and scroll_container:
				canvas.zoom_at_center(1.2, scroll_container)
			get_viewport().set_input_as_handled()
		elif ke.ctrl_pressed and (ke.keycode == KEY_MINUS or ke.keycode == KEY_KP_SUBTRACT):
			if canvas and scroll_container:
				canvas.zoom_at_center(1.0 / 1.2, scroll_container)
			get_viewport().set_input_as_handled()
		elif ke.ctrl_pressed and (ke.keycode == KEY_0 or ke.keycode == KEY_KP_0):
			if canvas and scroll_container:
				canvas.set_zoom_level(1.0, scroll_container)
			get_viewport().set_input_as_handled()
		elif ke.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			var focus_owner = get_viewport().gui_get_focus_owner()
			if not (focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox):
				if canvas and canvas.selected_object:
					nudge_selected_object(ke.keycode, ke.shift_pressed)
					get_viewport().set_input_as_handled()
					return

func nudge_selected_object(keycode: int, shift_pressed: bool) -> void:
	if not canvas or not canvas.selected_object or not current_level:
		return

	push_undo_snapshot()

	var obj = canvas.selected_object
	var step: float = 1.0
	if canvas.grid_snap and canvas.grid_size > 0:
		step = float(canvas.grid_size)
	elif shift_pressed:
		step = 10.0

	var move_vec := Vector2.ZERO
	match keycode:
		KEY_UP:
			move_vec.y = -step
		KEY_DOWN:
			move_vec.y = step
		KEY_LEFT:
			move_vec.x = -step
		KEY_RIGHT:
			move_vec.x = step

	obj.position += move_vec
	if canvas.grid_snap:
		obj.position = canvas.snap_pos(obj.position)

	if canvas.preview_nodes.has(obj):
		canvas.preview_nodes[obj].position = canvas.world_to_canvas(obj.position)

	update_inspector_values(obj)
	canvas.queue_redraw()
	emit_signal("level_data_modified")
