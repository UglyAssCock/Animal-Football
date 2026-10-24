extends Node

const MeshFactory = preload("res://scripts/MeshFactory.gd")
const MatchEngine = preload("res://scripts/MatchEngine.gd")

var bg_3d_root: Node3D
var bg_preview_animal: Node3D
var bg_preview_ball: Node3D
var bg_camera: Camera3D
var bg_stadium: Node3D
var bg_spin_time: float = 0.0

var match_engine: Node3D = null
var ui_layer: CanvasLayer
var screen_root: Control
var modal_label: Label
var modal_panel: PanelContainer

var current_screen: String = "MAIN_MENU"
var current_custom_tab: String = "Skins"

var hud_score_lbl: Label
var hud_clock_lbl: Label
var hud_down_lbl: Label
var hud_stamina_bar: ProgressBar
var hud_ability_btn: Button
var hud_pass_btn: Button
var hud_tackle_btn: Button
var hud_banner_lbl: Label
var play_call_panel: PanelContainer
var play_cards_box: HBoxContainer
var fourth_down_box: HBoxContainer

var joy_touch_idx: int = -1
var swipe_touch_idx: int = -1
var swipe_start_pos := Vector2.ZERO
var joy_pad_control: Control
var joy_knob_rect: Panel

func _ready() -> void:
	_setup_3d_showcase()
	_setup_ui_layer()
	show_screen("MAIN_MENU")

func _process(delta: float) -> void:
	bg_spin_time += delta
	if bg_3d_root and bg_3d_root.visible:
		if bg_preview_animal:
			bg_preview_animal.rotation.y = sin(bg_spin_time * 1.2) * 0.55 if current_screen == "MAIN_MENU" else bg_spin_time * 1.1
			MeshFactory.animate_character(bg_preview_animal, bg_spin_time, 1.5 if current_screen == "MAIN_MENU" else 0.3, false)
		if bg_preview_ball:
			bg_preview_ball.rotation.y = bg_spin_time * 1.8
			bg_preview_ball.position.y = 1.15 + sin(bg_spin_time * 3.0) * 0.12

func _setup_3d_showcase() -> void:
	bg_3d_root = Node3D.new()
	bg_3d_root.name = "Showcase3D"
	add_child(bg_3d_root)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0B1A33")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.1
	we.environment = env
	bg_3d_root.add_child(we)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -28, 0)
	light.light_energy = 1.35
	bg_3d_root.add_child(light)

	bg_camera = Camera3D.new()
	bg_camera.position = Vector3(0.0, 2.0, 4.8)
	bg_3d_root.add_child(bg_camera)
	bg_camera.current = true
	bg_camera.look_at(Vector3(0.0, 1.3, 0.0), Vector3.UP)

	_refresh_showcase_models()

func _refresh_showcase_models() -> void:
	if bg_preview_animal:
		bg_preview_animal.queue_free()
	if bg_preview_ball:
		bg_preview_ball.queue_free()
	if bg_stadium:
		bg_stadium.queue_free()

	var team := GameData.get_selected_team()
	var stadium := GameData.get_selected_stadium()
	var next_tid: int = (int(team["id"]) + 1) % 8
	bg_stadium = MeshFactory.build_stadium(stadium, team, GameData.TEAMS[next_tid])
	bg_stadium.position = Vector3(0, -0.1, -12.0)
	bg_3d_root.add_child(bg_stadium)

	var skin_col := GameData.get_equipped_color("Skins", Color(team["primary"]))
	var helm_col := GameData.get_equipped_color("Helmets", Color(team["secondary"]))
	var ball_col := GameData.get_equipped_color("Balls", Color("#A84A18"))

	bg_preview_animal = MeshFactory.build_animal_player(team, "12", skin_col, helm_col)
	bg_preview_animal.position = Vector3(1.55 if current_screen == "MAIN_MENU" else -1.35, 0.0, 0.8)
	bg_3d_root.add_child(bg_preview_animal)

	bg_preview_ball = MeshFactory.build_football(ball_col)
	bg_preview_ball.position = Vector3(0.65 if current_screen == "MAIN_MENU" else -0.35, 1.15, 1.4)
	bg_3d_root.add_child(bg_preview_ball)

func _make_style(bg: Color, border_col: Color, border_w: int = 3, radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _make_button(text: String, min_size: Vector2 = Vector2(180, 52), gold_highlight: bool = false, bg_col: Color = GameData.COLOR_NAVY_LIGHT) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE if not gold_highlight else GameData.COLOR_NAVY)
	var fill := GameData.COLOR_GOLD if gold_highlight else bg_col
	var outline := GameData.COLOR_GOLD
	btn.add_theme_stylebox_override("normal", _make_style(fill, outline, 3, 14))
	btn.add_theme_stylebox_override("hover", _make_style(fill.lightened(0.12), outline, 4, 14))
	btn.add_theme_stylebox_override("pressed", _make_style(fill.darkened(0.15), Color.WHITE, 4, 14))
	return btn

func _make_label(text: String, size: int = 22, col: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = align
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color("#050D1A"))
	lbl.add_theme_constant_override("outline_size", 5)
	return lbl

func _setup_ui_layer() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(screen_root)

	modal_panel = PanelContainer.new()
	modal_panel.visible = false
	modal_panel.custom_minimum_size = Vector2(460, 210)
	modal_panel.position = Vector2(410, 250)
	modal_panel.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_NAVY, GameData.COLOR_GOLD, 4, 18))
	var mv := VBoxContainer.new()
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_theme_constant_override("separation", 18)
	modal_label = _make_label("Coming Soon!", 24, GameData.COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	modal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mv.add_child(modal_label)
	var ok_btn := _make_button("OK", Vector2(150, 48), true)
	ok_btn.pressed.connect(func(): modal_panel.visible = false)
	mv.add_child(ok_btn)
	modal_panel.add_child(mv)
	ui_layer.add_child(modal_panel)

func _show_popup(msg: String) -> void:
	modal_label.text = msg
	modal_panel.visible = true

func _clear_screen() -> void:
	for c in screen_root.get_children():
		c.queue_free()

func show_screen(screen_name: String) -> void:
	current_screen = screen_name
	_clear_screen()
	if match_engine != null and screen_name != "MATCH":
		match_engine.queue_free()
		match_engine = null
		Engine.time_scale = 1.0

	bg_3d_root.visible = (screen_name != "MATCH")
	if bg_3d_root.visible:
		if bg_camera:
			bg_camera.current = true
		_refresh_showcase_models()

	match screen_name:
		"MAIN_MENU": _build_main_menu()
		"TEAMS": _build_teams_screen()
		"CUSTOMIZE": _build_customize_screen()
		"STADIUMS": _build_stadiums_screen()
		"TOURNAMENT": _build_tournament_screen()
		"SETTINGS": _build_settings_screen()

func _add_top_bar(title_text: String) -> void:
	var bar := PanelContainer.new()
	bar.position = Vector2(20, 14)
	bar.size = Vector2(1240, 64)
	bar.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_NAVY, GameData.COLOR_GOLD, 3, 14))
	screen_root.add_child(bar)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	bar.add_child(hb)

	var home_btn := _make_button("MENU", Vector2(110, 44))
	home_btn.pressed.connect(func(): show_screen("MAIN_MENU"))
	hb.add_child(home_btn)

	var title := _make_label(title_text, 28, GameData.COLOR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(title)

	var coin_lbl := _make_label("COINS: " + str(GameData.coins), 24, GameData.COLOR_GOLD)
	hb.add_child(coin_lbl)

	var plus_btn := _make_button("+", Vector2(52, 44), true)
	plus_btn.pressed.connect(func():
		GameData.coins += 250
		GameData.save_data()
		_show_popup("Coin Store & Rewarded Ads: Coming Soon!\n(Granted +250 Free Tester Coins!)")
		show_screen(current_screen)
	)
	hb.add_child(plus_btn)

func _add_bottom_tabs(active_tab: String) -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(40, 646)
	bar.size = Vector2(1200, 58)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 18)
	screen_root.add_child(bar)

	var tabs := [
		{"name": "Teams", "screen": "TEAMS"},
		{"name": "Players", "screen": "CUSTOMIZE", "sub": "Skins"},
		{"name": "Balls", "screen": "CUSTOMIZE", "sub": "Balls"},
		{"name": "Stadiums", "screen": "STADIUMS"},
		{"name": "Trophies", "screen": "TOURNAMENT"}
	]
	for t in tabs:
		var t_ref: Dictionary = t
		var is_sel: bool = (str(t_ref["name"]) == active_tab)
		var b := _make_button(str(t_ref["name"]).to_upper(), Vector2(215, 52), is_sel)
		b.pressed.connect(func():
			if t_ref.has("sub"):
				current_custom_tab = str(t_ref["sub"])
			show_screen(str(t_ref["screen"]))
		)
		bar.add_child(b)

func _build_main_menu() -> void:
	var header := PanelContainer.new()
	header.position = Vector2(44, 28)
	header.size = Vector2(680, 115)
	header.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_NAVY, GameData.COLOR_GOLD, 4, 18))
	screen_root.add_child(header)

	var hv := VBoxContainer.new()
	header.add_child(hv)
	hv.add_child(_make_label("ANIMAL FOOTBALL", 46, GameData.COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var team := GameData.get_selected_team()
	hv.add_child(_make_label("ACTIVE TEAM: %s (%s)  |  COINS: %d" % [team["name"], team["ability_name"], GameData.coins], 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))

	var menu_col := VBoxContainer.new()
	menu_col.position = Vector2(54, 165)
	menu_col.size = Vector2(380, 520)
	menu_col.add_theme_constant_override("separation", 14)
	screen_root.add_child(menu_col)

	var btn_play := _make_button("PLAY QUICK MATCH", Vector2(380, 64), true)
	btn_play.pressed.connect(func(): _launch_match(false))
	menu_col.add_child(btn_play)

	var btn_teams := _make_button("TEAMS (8 COUNTRIES)", Vector2(380, 56))
	btn_teams.pressed.connect(func(): show_screen("TEAMS"))
	menu_col.add_child(btn_teams)

	var btn_tourn := _make_button("TOURNAMENT & DAILY", Vector2(380, 56))
	btn_tourn.pressed.connect(func(): show_screen("TOURNAMENT"))
	menu_col.add_child(btn_tourn)

	var btn_cust := _make_button("CUSTOMIZE #12", Vector2(380, 56))
	btn_cust.pressed.connect(func(): show_screen("CUSTOMIZE"))
	menu_col.add_child(btn_cust)

	var btn_stad := _make_button("STADIUMS", Vector2(380, 56))
	btn_stad.pressed.connect(func(): show_screen("STADIUMS"))
	menu_col.add_child(btn_stad)

	var row_bottom := HBoxContainer.new()
	row_bottom.add_theme_constant_override("separation", 12)
	var btn_set := _make_button("SETTINGS", Vector2(184, 52))
	btn_set.pressed.connect(func(): show_screen("SETTINGS"))
	row_bottom.add_child(btn_set)

	var btn_online := _make_button("ONLINE (SOON)", Vector2(184, 52))
	btn_online.pressed.connect(func(): _show_popup("Online Multiplayer & Ranked Leagues: Coming Soon!"))
	row_bottom.add_child(btn_online)
	menu_col.add_child(row_bottom)

func _build_teams_screen() -> void:
	_add_top_bar("SELECT YOUR ANIMAL TEAM")
	_add_bottom_tabs("Teams")

	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(36, 92)
	grid.size = Vector2(1208, 535)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	screen_root.add_child(grid)

	for t in GameData.TEAMS:
		var is_sel: bool = (int(t["id"]) == GameData.selected_team_id)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(288, 255)
		var border_col := GameData.COLOR_GOLD if is_sel else Color("#2B4C7E")
		var border_w := 5 if is_sel else 2
		card.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_CARD, border_col, border_w, 16))

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)

		var badge := ColorRect.new()
		badge.custom_minimum_size = Vector2(256, 36)
		badge.color = Color(t["primary"])
		var badge_lbl := _make_label("%s - %s" % [str(t["animal"]).to_upper(), str(t["country"]).to_upper()], 20, GameData.COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		badge_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.add_child(badge_lbl)
		vb.add_child(badge)

		vb.add_child(_make_label("SPD %d | STR %d | AGI %d" % [t["speed"], t["strength"], t["agility"]], 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		vb.add_child(_make_label("Ability: " + str(t["ability_name"]), 16, GameData.COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER))

		var desc := _make_label(str(t["ability_desc"]), 14, Color("#BFD7EA"), HORIZONTAL_ALIGNMENT_CENTER)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(250, 44)
		vb.add_child(desc)

		var pick_btn := _make_button("SELECTED" if is_sel else "SELECT TEAM", Vector2(240, 44), is_sel)
		var tid: int = int(t["id"])
		pick_btn.pressed.connect(func():
			GameData.selected_team_id = tid
			GameData.save_data()
			show_screen("TEAMS")
		)
		vb.add_child(pick_btn)
		grid.add_child(card)

func _build_customize_screen() -> void:
	_add_top_bar("PLAYER #12 CUSTOMIZE & STATS")
	_add_bottom_tabs("Balls" if current_custom_tab == "Balls" else "Players")

	var right_panel := PanelContainer.new()
	right_panel.position = Vector2(490, 90)
	right_panel.size = Vector2(760, 540)
	right_panel.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_NAVY, GameData.COLOR_GOLD, 3, 16))
	screen_root.add_child(right_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 12)
	right_panel.add_child(rv)

	var stats := GameData.get_effective_stats(GameData.selected_team_id)
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 24)
	stats_grid.add_theme_constant_override("v_separation", 8)
	rv.add_child(stats_grid)

	for st_key in ["speed", "strength", "agility", "stamina"]:
		var sb_row := HBoxContainer.new()
		sb_row.custom_minimum_size = Vector2(340, 30)
		var st_lbl := _make_label(st_key.to_upper() + ": " + str(stats[st_key]), 17, GameData.COLOR_GOLD)
		st_lbl.custom_minimum_size = Vector2(145, 28)
		sb_row.add_child(st_lbl)

		var pbar := ProgressBar.new()
		pbar.min_value = 0
		pbar.max_value = 100
		pbar.value = float(stats[st_key])
		pbar.custom_minimum_size = Vector2(185, 24)
		pbar.add_theme_stylebox_override("background", _make_style(Color("#071121"), Color("#2B4C7E"), 1, 8))
		pbar.add_theme_stylebox_override("fill", _make_style(GameData.COLOR_GOLD, GameData.COLOR_GOLD, 0, 8))
		sb_row.add_child(pbar)
		stats_grid.add_child(sb_row)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 12)
	rv.add_child(tab_row)
	for cat in ["Skins", "Helmets", "Balls", "Emotes"]:
		var cat_name: String = cat
		var cbtn := _make_button(cat_name.to_upper(), Vector2(170, 44), current_custom_tab == cat_name)
		cbtn.pressed.connect(func():
			current_custom_tab = cat_name
			show_screen("CUSTOMIZE")
		)
		tab_row.add_child(cbtn)

	var items_grid := GridContainer.new()
	items_grid.columns = 2
	items_grid.add_theme_constant_override("h_separation", 16)
	items_grid.add_theme_constant_override("v_separation", 14)
	rv.add_child(items_grid)

	var items: Array = GameData.CUSTOM_ITEMS.get(current_custom_tab, [])
	for item in items:
		var equipped := GameData.is_item_equipped(item["id"])
		var owned := GameData.is_item_owned(item["id"])
		var icard := PanelContainer.new()
		icard.custom_minimum_size = Vector2(355, 145)
		icard.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_CARD, GameData.COLOR_GOLD if equipped else Color("#2B4C7E"), 4 if equipped else 2, 14))

		var iv := VBoxContainer.new()
		icard.add_child(iv)
		iv.add_child(_make_label(str(item["name"]), 20, GameData.COLOR_GOLD if equipped else Color.WHITE))
		iv.add_child(_make_label("+%d %s" % [item["bonus_val"], str(item["bonus_stat"]).to_upper()], 16, GameData.COLOR_GREEN))

		var btn_txt := "EQUIPPED" if equipped else ("EQUIP" if owned else ("BUY (%d COINS)" % item["price"]))
		var act_btn := _make_button(btn_txt, Vector2(310, 44), equipped)
		var item_ref: Dictionary = item
		act_btn.pressed.connect(func():
			if not GameData.buy_or_equip_item(current_custom_tab, item_ref):
				_show_popup("Not enough coins! Play matches or claim daily challenges.")
			show_screen("CUSTOMIZE")
		)
		iv.add_child(act_btn)
		items_grid.add_child(icard)

func _build_stadiums_screen() -> void:
	_add_top_bar("SELECT STADIUM ARENA")
	_add_bottom_tabs("Stadiums")

	var st := GameData.get_selected_stadium()
	var card := PanelContainer.new()
	card.position = Vector2(280, 145)
	card.size = Vector2(720, 440)
	card.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_NAVY, GameData.COLOR_GOLD, 4, 20))
	screen_root.add_child(card)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	card.add_child(vb)

	vb.add_child(_make_label("STADIUM %d OF 4" % [GameData.selected_stadium_id + 1], 20, Color("#BFD7EA"), HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(_make_label(str(st["name"]).to_upper(), 40, GameData.COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(540, 56)
	swatch.color = Color(st["turf_a"])
	var sw_lbl := _make_label(str(st["effect_title"]), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	sw_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	swatch.add_child(sw_lbl)
	vb.add_child(swatch)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 28)
	vb.add_child(nav)

	var prev_btn := _make_button("PREV ARENA", Vector2(190, 56))
	prev_btn.pressed.connect(func():
		GameData.selected_stadium_id = (GameData.selected_stadium_id + 3) % 4
		GameData.save_data()
		show_screen("STADIUMS")
	)
	nav.add_child(prev_btn)

	var play_here := _make_button("PLAY HERE NOW", Vector2(230, 56), true)
	play_here.pressed.connect(func(): _launch_match(false))
	nav.add_child(play_here)

	var next_btn := _make_button("NEXT ARENA", Vector2(190, 56))
	next_btn.pressed.connect(func():
		GameData.selected_stadium_id = (GameData.selected_stadium_id + 1) % 4
		GameData.save_data()
		show_screen("STADIUMS")
	)
	nav.add_child(next_btn)

func _build_tournament_screen() -> void:
	_add_top_bar("8-TEAM WORLD TOURNAMENT & TROPHIES (WON: %d)" % GameData.trophies_won)
	_add_bottom_tabs("Trophies")

	var main_hb := HBoxContainer.new()
	main_hb.position = Vector2(36, 94)
	main_hb.size = Vector2(1208, 535)
	main_hb.add_theme_constant_override("separation", 20)
	screen_root.add_child(main_hb)

	var b_panel := PanelContainer.new()
	b_panel.custom_minimum_size = Vector2(680, 530)
	b_panel.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_NAVY, GameData.COLOR_GOLD, 3, 16))
	main_hb.add_child(b_panel)

	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 12)
	b_panel.add_child(bv)

	var r_names := ["QUARTERFINALS (8 TEAMS)", "SEMIFINALS (4 TEAMS)", "CHAMPIONSHIP FINAL"]
	bv.add_child(_make_label("CURRENT STAGE: " + r_names[clampi(GameData.tournament_round, 0, 2)], 24, GameData.COLOR_GOLD))

	var active_list: Array = GameData.tournament_bracket[clampi(GameData.tournament_round, 0, 2)]
	var i := 0
	while i < active_list.size():
		var t1: Dictionary = GameData.TEAMS[int(active_list[i])]
		var t2: Dictionary = GameData.TEAMS[int(active_list[i + 1])]
		var m_lbl := _make_label("Match %d:  %s (%s)   VS   %s (%s)" % [(i / 2) + 1, t1["name"], t1["code"], t2["name"], t2["code"]], 20, Color.WHITE)
		bv.add_child(m_lbl)
		i += 2

	var play_t_btn := _make_button("PLAY TOURNAMENT MATCH", Vector2(380, 58), true)
	play_t_btn.pressed.connect(func(): _launch_match(true))
	bv.add_child(play_t_btn)

	var c_panel := PanelContainer.new()
	c_panel.custom_minimum_size = Vector2(500, 530)
	c_panel.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_NAVY, GameData.COLOR_GOLD, 3, 16))
	main_hb.add_child(c_panel)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	c_panel.add_child(cv)
	cv.add_child(_make_label("DAILY CHALLENGES", 24, GameData.COLOR_GOLD))

	for ch in GameData.daily_challenges:
		var ch_box := PanelContainer.new()
		ch_box.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_CARD, Color("#2B4C7E"), 2, 12))
		var ch_v := VBoxContainer.new()
		ch_box.add_child(ch_v)
		ch_v.add_child(_make_label("%s (%d / %d)" % [ch["title"], ch["progress"], ch["goal"]], 18, Color.WHITE))
		var done: bool = int(ch["progress"]) >= int(ch["goal"])
		var claimed: bool = bool(ch["claimed"])
		var claim_btn := _make_button("CLAIMED" if claimed else ("CLAIM +%d COINS" % ch["reward"] if done else "IN PROGRESS"), Vector2(240, 40), done and not claimed)
		var ch_ref: Dictionary = ch
		claim_btn.pressed.connect(func():
			if int(ch_ref["progress"]) >= int(ch_ref["goal"]) and not bool(ch_ref["claimed"]):
				ch_ref["claimed"] = true
				GameData.coins += int(ch_ref["reward"])
				GameData.save_data()
				show_screen("TOURNAMENT")
		)
		ch_v.add_child(claim_btn)
		cv.add_child(ch_box)

func _build_settings_screen() -> void:
	_add_top_bar("GAME SETTINGS")

	var panel := PanelContainer.new()
	panel.position = Vector2(310, 120)
	panel.size = Vector2(660, 480)
	panel.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_NAVY, GameData.COLOR_GOLD, 3, 18))
	screen_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	panel.add_child(vb)

	var diff_names := ["EASY", "NORMAL", "HARD"]
	var d_idx: int = int(GameData.settings.get("difficulty", 1))
	var diff_btn := _make_button("AI DIFFICULTY: " + diff_names[d_idx], Vector2(580, 56), true)
	diff_btn.pressed.connect(func():
		GameData.settings["difficulty"] = (d_idx + 1) % 3
		GameData.save_data()
		show_screen("SETTINGS")
	)
	vb.add_child(diff_btn)

	var arc: bool = bool(GameData.settings.get("arcade_mode", true))
	var arc_btn := _make_button("ARCADE MODE (NO PENALTIES): " + ("ON" if arc else "OFF"), Vector2(580, 56))
	arc_btn.pressed.connect(func():
		GameData.settings["arcade_mode"] = not arc
		GameData.save_data()
		show_screen("SETTINGS")
	)
	vb.add_child(arc_btn)

	var bcam: bool = bool(GameData.settings.get("broadcast_cam", false))
	var cam_btn := _make_button("CAMERA VIEW: " + ("BROADCAST SIDE" if bcam else "BEHIND PLAYER #12"), Vector2(580, 56))
	cam_btn.pressed.connect(func():
		GameData.settings["broadcast_cam"] = not bcam
		GameData.save_data()
		show_screen("SETTINGS")
	)
	vb.add_child(cam_btn)

	var qm: int = int(GameData.settings.get("quarter_minutes", 2))
	var q_btn := _make_button("QUARTER LENGTH: %d MINUTES" % qm, Vector2(580, 56))
	q_btn.pressed.connect(func():
		GameData.settings["quarter_minutes"] = 3 if qm == 2 else 2
		GameData.save_data()
		show_screen("SETTINGS")
	)
	vb.add_child(q_btn)

func _launch_match(is_tourn: bool) -> void:
	current_screen = "MATCH"
	_clear_screen()
	bg_3d_root.visible = false
	if bg_camera:
		bg_camera.current = false

	var opp_id: int = GameData.get_next_tournament_opponent() if is_tourn else ((GameData.selected_team_id + randi_range(1, 7)) % 8)
	match_engine = MatchEngine.new()
	add_child(match_engine)
	match_engine.match_HUD_updated.connect(_on_hud_updated)
	match_engine.play_selection_requested.connect(_on_play_select_requested)
	match_engine.banner_triggered.connect(_on_banner_triggered)
	match_engine.match_finished.connect(_on_match_finished)

	_build_match_hud()
	match_engine.setup_match(GameData.selected_team_id, opp_id, GameData.selected_stadium_id, is_tourn)

func _build_match_hud() -> void:
	var top_sb := PanelContainer.new()
	top_sb.position = Vector2(210, 10)
	top_sb.size = Vector2(860, 62)
	top_sb.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_NAVY, GameData.COLOR_GOLD, 3, 14))
	screen_root.add_child(top_sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	top_sb.add_child(hb)

	hud_score_lbl = _make_label("USA 0 - 0 ESP", 25, GameData.COLOR_GOLD)
	hb.add_child(hud_score_lbl)

	hud_clock_lbl = _make_label("Q1  2:00", 22, Color.WHITE)
	hb.add_child(hud_clock_lbl)

	hud_down_lbl = _make_label("1st & 10", 22, GameData.COLOR_GREEN)
	hb.add_child(hud_down_lbl)

	hud_stamina_bar = ProgressBar.new()
	hud_stamina_bar.custom_minimum_size = Vector2(150, 24)
	hud_stamina_bar.value = 100
	hud_stamina_bar.add_theme_stylebox_override("background", _make_style(Color("#06101E"), Color.WHITE, 1, 8))
	hud_stamina_bar.add_theme_stylebox_override("fill", _make_style(GameData.COLOR_GREEN, GameData.COLOR_GREEN, 0, 8))
	hb.add_child(hud_stamina_bar)

	var quit_btn := _make_button("EXIT", Vector2(90, 42))
	quit_btn.pressed.connect(func(): show_screen("MAIN_MENU"))
	hb.add_child(quit_btn)

	hud_banner_lbl = _make_label("", 44, GameData.COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	hud_banner_lbl.position = Vector2(240, 105)
	hud_banner_lbl.size = Vector2(800, 70)
	screen_root.add_child(hud_banner_lbl)

	joy_pad_control = Control.new()
	joy_pad_control.position = Vector2(60, 450)
	joy_pad_control.size = Vector2(180, 180)
	screen_root.add_child(joy_pad_control)

	var outer_ring := Panel.new()
	outer_ring.size = Vector2(180, 180)
	outer_ring.add_theme_stylebox_override("panel", _make_style(Color(0.04, 0.1, 0.2, 0.65), GameData.COLOR_GOLD, 3, 90))
	joy_pad_control.add_child(outer_ring)

	joy_knob_rect = Panel.new()
	joy_knob_rect.size = Vector2(74, 74)
	joy_knob_rect.position = Vector2(53, 53)
	joy_knob_rect.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_GOLD, Color.WHITE, 2, 37))
	joy_pad_control.add_child(joy_knob_rect)

	var btn_sprint := _make_button("SPRINT", Vector2(155, 72), true)
	btn_sprint.position = Vector2(1085, 595)
	btn_sprint.button_down.connect(func(): if match_engine: match_engine.sprint_held = true)
	btn_sprint.button_up.connect(func(): if match_engine: match_engine.sprint_held = false)
	screen_root.add_child(btn_sprint)

	hud_pass_btn = _make_button("PASS", Vector2(155, 72))
	hud_pass_btn.position = Vector2(915, 595)
	hud_pass_btn.pressed.connect(func(): if match_engine: match_engine.trigger_pass_or_switch())
	screen_root.add_child(hud_pass_btn)

	hud_tackle_btn = _make_button("TACKLE / DIVE", Vector2(155, 72), false, Color("#C82333"))
	hud_tackle_btn.position = Vector2(915, 508)
	hud_tackle_btn.pressed.connect(func(): if match_engine: match_engine.trigger_tackle_or_dive())
	screen_root.add_child(hud_tackle_btn)

	hud_ability_btn = _make_button("ABILITY", Vector2(155, 72), false, Color("#6A1B9A"))
	hud_ability_btn.position = Vector2(1085, 508)
	hud_ability_btn.pressed.connect(func(): if match_engine: match_engine.trigger_animal_ability())
	screen_root.add_child(hud_ability_btn)

	play_call_panel = PanelContainer.new()
	play_call_panel.position = Vector2(180, 175)
	play_call_panel.size = Vector2(920, 340)
	play_call_panel.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_NAVY, GameData.COLOR_GOLD, 4, 18))
	screen_root.add_child(play_call_panel)

	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 14)
	play_call_panel.add_child(pv)

	pv.add_child(_make_label("CHOOSE YOUR PLAY BEFORE THE SNAP (SWIPE RIGHT SIDE TO JUKE)", 22, GameData.COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	play_cards_box = HBoxContainer.new()
	play_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	play_cards_box.add_theme_constant_override("separation", 16)
	pv.add_child(play_cards_box)

	fourth_down_box = HBoxContainer.new()
	fourth_down_box.alignment = BoxContainer.ALIGNMENT_CENTER
	fourth_down_box.add_theme_constant_override("separation", 16)
	pv.add_child(fourth_down_box)

func _on_hud_updated(st: Dictionary) -> void:
	if hud_score_lbl == null:
		return
	hud_score_lbl.text = "%s %d  -  %d %s" % [st["user_code"], st["user_score"], st["ai_score"], st["ai_code"]]
	hud_clock_lbl.text = "%s  %s" % [st["quarter"], st["clock"]]
	hud_down_lbl.text = str(st["down_text"])
	hud_stamina_bar.value = float(st["stamina"])
	var is_off: bool = bool(st["is_offense"])
	hud_pass_btn.text = "PASS" if is_off else "SWITCH"
	hud_tackle_btn.text = "DIVE / JUKE" if is_off else "TACKLE"
	var cd: float = float(st["ability_cd"])
	hud_ability_btn.text = ("CD %.1fs" % cd) if cd > 0.0 else str(st["ability_name"]).to_upper()

func _on_play_select_requested(is_user_offense: bool, down_num: int, _ytg: int) -> void:
	if play_call_panel == null:
		return
	play_call_panel.visible = true
	for c in play_cards_box.get_children():
		c.queue_free()
	for c in fourth_down_box.get_children():
		c.queue_free()

	var play_list := GameData.OFFENSE_PLAYS if is_user_offense else GameData.DEFENSE_PLAYS
	for p in play_list:
		var pcard := PanelContainer.new()
		pcard.custom_minimum_size = Vector2(270, 175)
		pcard.add_theme_stylebox_override("panel", _make_style(GameData.COLOR_CARD, GameData.COLOR_GOLD, 3, 14))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		pcard.add_child(vb)
		vb.add_child(_make_label(str(p["name"]), 18, GameData.COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var d_lbl := _make_label(str(p["desc"]), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.custom_minimum_size = Vector2(240, 58)
		vb.add_child(d_lbl)
		var sel_btn := _make_button("HIKE PLAY", Vector2(230, 44), true)
		var p_ref: Dictionary = p
		sel_btn.pressed.connect(func():
			play_call_panel.visible = false
			if match_engine:
				match_engine.start_play(p_ref)
		)
		vb.add_child(sel_btn)
		play_cards_box.add_child(pcard)

	var quick_btn := _make_button("QUICK PLAY (AUTO)", Vector2(240, 46), true)
	quick_btn.pressed.connect(func():
		play_call_panel.visible = false
		if match_engine:
			match_engine.start_play(play_list[randi() % play_list.size()])
	)
	fourth_down_box.add_child(quick_btn)

	if is_user_offense and down_num == 4:
		var fg_btn := _make_button("KICK FIELD GOAL (3 PTS)", Vector2(250, 46))
		fg_btn.pressed.connect(func():
			play_call_panel.visible = false
			if match_engine: match_engine.execute_special_fourth_down("field_goal")
		)
		fourth_down_box.add_child(fg_btn)

		var punt_btn := _make_button("PUNT BALL", Vector2(180, 46))
		punt_btn.pressed.connect(func():
			play_call_panel.visible = false
			if match_engine: match_engine.execute_special_fourth_down("punt")
		)
		fourth_down_box.add_child(punt_btn)

func _on_banner_triggered(txt: String, col: Color) -> void:
	if hud_banner_lbl == null:
		return
	hud_banner_lbl.text = txt
	hud_banner_lbl.add_theme_color_override("font_color", col)
	var tw := create_tween()
	hud_banner_lbl.scale = Vector2(1.25, 1.25)
	tw.tween_property(hud_banner_lbl, "scale", Vector2.ONE, 0.25)

func _on_match_finished(user_won: bool, u_score: int, a_score: int, reward: int) -> void:
	var extra := ""
	if match_engine and match_engine.is_tournament:
		extra = "\n" + GameData.advance_tournament(user_won)
	var title := "VICTORY!" if user_won else "FULL TIME"
	_show_popup("%s\nFinal Score: %d - %d\nEarned +%d Coins!%s" % [title, u_score, a_score, reward, extra])
	show_screen("TOURNAMENT" if (match_engine and match_engine.is_tournament) else "MAIN_MENU")

func _input(event: InputEvent) -> void:
	if current_screen != "MATCH" or match_engine == null:
		return

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if st.position.x < 520.0 and st.position.y > 320.0 and joy_touch_idx == -1:
				joy_touch_idx = st.index
				_update_joystick(st.position)
			elif st.position.x >= 520.0 and swipe_touch_idx == -1:
				swipe_touch_idx = st.index
				swipe_start_pos = st.position
		else:
			if st.index == joy_touch_idx:
				joy_touch_idx = -1
				match_engine.joy_vector = Vector2.ZERO
				if joy_knob_rect:
					joy_knob_rect.position = Vector2(53, 53)
			elif st.index == swipe_touch_idx:
				if st.position.distance_to(swipe_start_pos) > 55.0:
					match_engine.trigger_juke()
				swipe_touch_idx = -1

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == joy_touch_idx:
			_update_joystick(sd.position)

func _update_joystick(touch_pos: Vector2) -> void:
	var center := Vector2(150, 540)
	var delta_v := touch_pos - center
	var max_r := 68.0
	if delta_v.length() > max_r:
		delta_v = delta_v.normalized() * max_r
	if joy_knob_rect:
		joy_knob_rect.position = Vector2(53, 53) + delta_v
	if match_engine:
		match_engine.joy_vector = delta_v / max_r
