class_name MatchEngine
extends Node3D

signal match_HUD_updated(state: Dictionary)
signal play_selection_requested(is_user_offense: bool, down: int, yards_to_go: int)
signal banner_triggered(text: String, color: Color)
signal match_finished(user_won: bool, user_score: int, ai_score: int, coins_earned: int)

enum Phase { PLAY_SELECT, LIVE_PLAY, CELEBRATION, TACKLE_CAM, GAME_OVER }

var phase: Phase = Phase.PLAY_SELECT
var is_tournament: bool = false
var user_team: Dictionary
var ai_team: Dictionary
var stadium_data: Dictionary
var user_stats: Dictionary
var ai_stats: Dictionary

var user_score: int = 0
var ai_score: int = 0
var quarter: int = 1
var clock_sec: float = 120.0
var is_user_offense: bool = true
var down: int = 1
var line_of_scrimmage: float = 20.0 # Z from +50 (user own goal) toward -50 (AI goal)
var first_down_z: float = 10.0

var current_play: Dictionary = {}
var stadium_node: Node3D
var scrimmage_marker: MeshInstance3D
var first_down_marker: MeshInstance3D
var ball_node: Node3D
var receiver_ring: MeshInstance3D

var user_players: Array[Node3D] = []
var ai_players: Array[Node3D] = []
var controlled_player: Node3D
var ball_carrier: Node3D

var ball_in_air: bool = false
var ball_start_pos: Vector3
var ball_target_pos: Vector3
var ball_flight_t: float = 0.0
var ball_flight_duration: float = 0.85
var intended_receiver: Node3D = null
var pass_thrown_this_down: bool = false

var joy_vector: Vector2 = Vector2.ZERO
var sprint_held: bool = false
var stamina: float = 100.0
var ability_cooldown: float = 0.0
var ability_active_timer: float = 0.0
var stun_timer_ai: float = 0.0
var juke_cooldown: float = 0.0

var camera: Camera3D
var cam_shake: float = 0.0
var phase_timer: float = 0.0
var anim_time: float = 0.0
var fireworks_root: Node3D

func setup_match(p_user_team_id: int, p_ai_team_id: int, p_stadium_id: int, p_tournament: bool) -> void:
	is_tournament = p_tournament
	user_team = GameData.TEAMS[p_user_team_id]
	ai_team = GameData.TEAMS[p_ai_team_id]
	stadium_data = GameData.STADIUMS[p_stadium_id]
	user_stats = GameData.get_effective_stats(p_user_team_id)
	ai_stats = GameData.get_effective_stats(p_ai_team_id)

	clock_sec = float(int(GameData.settings.get("quarter_minutes", 2)) * 60)
	_build_environment()
	_spawn_teams_and_ball()
	_reset_drive(true, 25.0)

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(stadium_data["sky"])
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = float(stadium_data["ambient_energy"])
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 60.0
	add_child(camera)

	stadium_node = MeshFactory.build_stadium(stadium_data, user_team, ai_team)
	add_child(stadium_node)

	# Blue Line of Scrimmage & Gold First-Down Line
	scrimmage_marker = MeshFactory.add_box(
		self, Vector3(44.0, 0.15, 0.35), Vector3(0, 0.02, 20.0),
		MeshFactory.make_mat(Color("#1664E8"), 0.3, 0.1, true)
	)
	first_down_marker = MeshFactory.add_box(
		self, Vector3(44.0, 0.16, 0.40), Vector3(0, 0.03, 10.0),
		MeshFactory.make_mat(Color("#FFB400"), 0.3, 0.1, true)
	)

	fireworks_root = Node3D.new()
	add_child(fireworks_root)

func _spawn_teams_and_ball() -> void:
	var custom_skin := GameData.get_equipped_color("Skins", Color(user_team["primary"]))
	var custom_helm := GameData.get_equipped_color("Helmets", Color(user_team["secondary"]))
	var custom_ball := GameData.get_equipped_color("Balls", Color("#A84A18"))

	var user_numbers := ["12", "88", "24", "72", "55"]
	for i in range(5):
		var p := MeshFactory.build_animal_player(user_team, user_numbers[i], custom_skin, custom_helm)
		add_child(p)
		user_players.append(p)

	var ai_numbers := ["10", "81", "33", "77", "99"]
	for i in range(5):
		var p := MeshFactory.build_animal_player(ai_team, ai_numbers[i])
		add_child(p)
		ai_players.append(p)

	ball_node = MeshFactory.build_football(custom_ball)
	add_child(ball_node)

	# Target ring under open receiver
	receiver_ring = MeshFactory.add_ConeRing(self) if has_method("add_ConeRing") else MeshFactory.add_cone(
		self, 1.1, 0.9, 0.08, Vector3(0, 0.08, 0),
		MeshFactory.make_mat(Color("#FFB400"), 0.2, 0.2, true)
	)

func _reset_drive(user_off: bool, start_z: float) -> void:
	is_user_offense = user_off
	down = 1
	line_of_scrimmage = clampf(start_z, -42.0, 42.0)
	first_down_z = line_of_scrimmage - 10.0 if is_user_offense else line_of_scrimmage + 10.0
	_setup_formation_for_down()

func _setup_formation_for_down() -> void:
	Engine.time_scale = 1.0
	phase = Phase.PLAY_SELECT
	ball_in_air = false
	pass_thrown_this_down = false
	stamina = 100.0
	ability_active_timer = 0.0
	stun_timer_ai = 0.0

	scrimmage_marker.position.z = line_of_scrimmage
	first_down_marker.position.z = clampf(first_down_z, -50.0, 50.0)

	var dir: float = -1.0 if is_user_offense else 1.0
	var off_team := user_players if is_user_offense else ai_players
	var def_team := ai_players if is_user_offense else user_players

	# Offense positions: [0]=QB/Carrier #12, [1]=WR Left, [2]=WR Right, [3]=OL Left, [4]=OL Right
	var off_offsets := [
		Vector3(0.0, 0.0, -4.2 * dir),
		Vector3(-11.5, 0.0, -1.2 * dir),
		Vector3(11.5, 0.0, -1.2 * dir),
		Vector3(-2.5, 0.0, -1.0 * dir),
		Vector3(2.5, 0.0, -1.0 * dir)
	]
	for i in range(5):
		off_team[i].position = Vector3(off_offsets[i].x, 0.0, line_of_scrimmage + off_offsets[i].z)
		off_team[i].rotation.y = PI if is_user_offense else 0.0

	# Defense positions: [0]=MLB Captain, [1]=CB Left, [2]=CB Right, [3]=DL Left, [4]=DL Right
	var def_offsets := [
		Vector3(0.0, 0.0, 5.5 * dir),
		Vector3(-11.0, 0.0, 4.5 * dir),
		Vector3(11.0, 0.0, 4.5 * dir),
		Vector3(-2.6, 0.0, 1.8 * dir),
		Vector3(2.6, 0.0, 1.8 * dir)
	]
	for i in range(5):
		def_team[i].position = Vector3(def_offsets[i].x, 0.0, line_of_scrimmage + def_offsets[i].z)
		def_team[i].rotation.y = 0.0 if is_user_offense else PI

	controlled_player = user_players[0]
	ball_carrier = off_team[0]
	intended_receiver = off_team[1]
	_attach_ball_to_carrier()
	_update_camera(0.0, true)
	_emit_hud()
	emit_signal("play_selection_requested", is_user_offense, down, int( roundf(absf(first_down_z - line_of_scrimmage)) ))

func start_play(play_data: Dictionary) -> void:
	if phase != Phase.PLAY_SELECT:
		return
	current_play = play_data
	phase = Phase.LIVE_PLAY
	emit_signal("banner_triggered", str(play_data["name"]), GameData.COLOR_GOLD)

func execute_special_fourth_down(action_type: String) -> void:
	if phase != Phase.PLAY_SELECT:
		return
	if action_type == "field_goal":
		var dist_to_post: float = absf(-60.0 - line_of_scrimmage)
		var success_prob: float = clampf(1.15 - (dist_to_post / 62.0), 0.25, 0.95)
		if randf() <= success_prob:
			user_score += 3
			emit_signal("banner_triggered", "FIELD GOAL GOOD! +3 PTS", GameData.COLOR_GOLD)
			_trigger_celebration(false)
		else:
			emit_signal("banner_triggered", "FIELD GOAL WIDE! TURNOVER", GameData.COLOR_RED)
			_reset_drive(false, line_of_scrimmage)
	elif action_type == "punt":
		var punt_z := clampf(line_of_scrimmage - 34.0, -45.0, 40.0)
		emit_signal("banner_triggered", "BOOM PUNT! 34 YARDS", GameData.COLOR_WHITE)
		_reset_drive(false, punt_z)

func trigger_juke() -> void:
	if phase != Phase.LIVE_PLAY or juke_cooldown > 0.0 or controlled_player == null:
		return
	juke_cooldown = 1.1
	var juke_dir := 1.0 if randf() > 0.5 else -1.0
	if absf(joy_vector.x) > 0.15:
		juke_dir = signf(joy_vector.x)
	var agility_factor: float = float(user_stats["agility"]) / 80.0
	controlled_player.position.x = clampf(controlled_player.position.x + juke_dir * 3.4 * agility_factor, -20.5, 20.5)
	emit_signal("banner_triggered", "JUKE MOVE!", GameData.COLOR_GOLD)

func trigger_pass_or_switch() -> void:
	if phase != Phase.LIVE_PLAY:
		return
	if is_user_offense:
		if ball_carrier == controlled_player and not ball_in_air and not pass_thrown_this_down:
			# Pick best open WR (user_players[1] or user_players[2])
			var wr1 := user_players[1]
			var wr2 := user_players[2]
			intended_receiver = wr1 if wr1.position.z < wr2.position.z else wr2
			ball_in_air = true
			pass_thrown_this_down = true
			ball_carrier = null
			ball_start_pos = controlled_player.position + Vector3(0, 1.8, 0)
			ball_target_pos = intended_receiver.position + Vector3(0, 1.4, -5.5)
			ball_target_pos.x = clampf(ball_target_pos.x, -20.0, 20.0)
			ball_target_pos.z = clampf(ball_target_pos.z, -58.0, 50.0)
			ball_flight_t = 0.0
			var dist := ball_start_pos.distance_to(ball_target_pos)
			ball_flight_duration = clampf(dist / 26.0, 0.35, 1.1)
			emit_signal("banner_triggered", "SPIRAL PASS!", GameData.COLOR_WHITE)
	else:
		# Switch controlled defender to closest to ball
		var target_pos := ball_node.position if ball_in_air else (ball_carrier.position if ball_carrier else Vector3.ZERO)
		var best_p := controlled_player
		var best_d := 999.0
		for p in user_players:
			if p == controlled_player:
				continue
			var d := p.position.distance_to(target_pos)
			if d < best_d:
				best_d = d
				best_p = p
		controlled_player = best_p
		emit_signal("banner_triggered", "SWITCHED DEFENDER!", GameData.COLOR_GOLD)

func trigger_tackle_or_dive() -> void:
	if phase != Phase.LIVE_PLAY or controlled_player == null:
		return
	if not is_user_offense:
		var fwd := -controlled_player.transform.basis.z.normalized()
		if joy_vector.length() > 0.15:
			fwd = Vector3(joy_vector.x, 0, joy_vector.y).normalized()
		controlled_player.position += fwd * 2.8
		if ball_carrier != null and controlled_player.position.distance_to(ball_carrier.position) < 3.1:
			_resolve_tackle(controlled_player, ball_carrier, true)
	else:
		# Dive forward for extra yards
		controlled_player.position.z -= 2.4

func trigger_animal_ability() -> void:
	if phase != Phase.LIVE_PLAY or ability_cooldown > 0.0 or controlled_player == null:
		return
	ability_cooldown = float(user_team["cooldown"])
	ability_active_timer = 3.0
	var animal: String = str(user_team["animal"])
	emit_signal("banner_triggered", str(user_team["ability_name"]).to_upper() + "!", GameData.COLOR_GOLD)

	match animal:
		"Lion":
			stun_timer_ai = 2.4
		"Bull":
			for ai_p in ai_players:
				if ai_p.position.distance_to(controlled_player.position) < 6.5:
					var push := (ai_p.position - controlled_player.position).normalized() * 5.5
					ai_p.position += Vector3(push.x, 0, push.z)
		"Eagle", "Kangaroo":
			controlled_player.position.y = 3.2
			var leap_z := -6.5 if is_user_offense else 5.0
			controlled_player.position.z = clampf(controlled_player.position.z + leap_z, -58.0, 58.0)
		"Jaguar":
			var dash_z := -8.0 if is_user_offense else 6.5
			controlled_player.position.z = clampf(controlled_player.position.z + dash_z, -58.0, 58.0)
		"Bear":
			for ai_p in ai_players:
				if ai_p.position.distance_to(controlled_player.position) < 6.0:
					if not is_user_offense and ai_p == ball_carrier:
						_resolve_tackle(controlled_player, ball_carrier, true)
						return
					ai_p.position += (ai_p.position - controlled_player.position).normalized() * 4.8

func _process(delta: float) -> void:
	var raw_dt: float = delta / maxf(Engine.time_scale, 0.05)
	anim_time += raw_dt

	if ability_cooldown > 0.0:
		ability_cooldown = maxf(0.0, ability_cooldown - raw_dt)
	if ability_active_timer > 0.0:
		ability_active_timer = maxf(0.0, ability_active_timer - raw_dt)
	if stun_timer_ai > 0.0:
		stun_timer_ai = maxf(0.0, stun_timer_ai - raw_dt)
	if juke_cooldown > 0.0:
		juke_cooldown = maxf(0.0, juke_cooldown - raw_dt)

	match phase:
		Phase.PLAY_SELECT:
			_animate_all_models(0.0, false)
			_update_camera(raw_dt, false)
		Phase.LIVE_PLAY:
			_update_live_play(delta)
			_update_camera(raw_dt, false)
		Phase.TACKLE_CAM:
			phase_timer -= raw_dt
			_update_camera(raw_dt, false)
			if phase_timer <= 0.0:
				Engine.time_scale = 1.0
				_advance_down_after_tackle()
		Phase.CELEBRATION:
			phase_timer -= raw_dt
			_animate_all_models(2.0, true)
			_update_fireworks(raw_dt)
			_update_camera(raw_dt, false)
			if phase_timer <= 0.0:
				Engine.time_scale = 1.0
				_clear_fireworks()
				_reset_drive(not is_user_offense, 20.0 if not is_user_offense else -20.0)

func _update_live_play(delta: float) -> void:
	# Quarter Clock
	clock_sec -= delta
	if clock_sec <= 0.0:
		if quarter < 4:
			quarter += 1
			clock_sec = float(int(GameData.settings.get("quarter_minutes", 2)) * 60)
			emit_signal("banner_triggered", "START OF QUARTER " + str(quarter), GameData.COLOR_GOLD)
		else:
			_end_game()
			return

	# Gravity return from Eagle/Kangaroo jump
	if controlled_player and controlled_player.position.y > 0.0:
		controlled_player.position.y = maxf(0.0, controlled_player.position.y - delta * 6.5)

	# User Movement
	var base_spd: float = (6.8 + (float(user_stats["speed"]) - 75.0) * 0.09) * float(stadium_data["speed_mult"])
	if ability_active_timer > 0.0 and str(user_team["animal"]) in ["Wolf", "Bull", "Jaguar"]:
		base_spd *= 1.48

	if sprint_held and stamina > 2.0 and joy_vector.length() > 0.1:
		base_spd *= 1.34
		var drain: float = 24.0 * float(stadium_data["stamina_drain_mult"]) * (100.0 / maxf(float(user_stats["stamina"]), 50.0))
		stamina = maxf(0.0, stamina - drain * delta)
	else:
		stamina = minf(100.0, stamina + 12.0 * delta)

	if controlled_player and joy_vector.length() > 0.1:
		var move_v := Vector3(joy_vector.x, 0.0, joy_vector.y).normalized() * base_spd * delta
		controlled_player.position += move_v
		controlled_player.position.x = clampf(controlled_player.position.x, -21.5, 21.5)
		controlled_player.position.z = clampf(controlled_player.position.z, -58.0, 58.0)
		controlled_player.rotation.y = atan2(-move_v.x, -move_v.z)

	# Update AI Teammates & Opponents
	_update_ai_units(delta)

	# Update Airborne Pass or Attached Ball
	if ball_in_air:
		ball_flight_t += delta / ball_flight_duration
		var pos := ball_start_pos.lerp(ball_target_pos, clampf(ball_flight_t, 0.0, 1.0))
		pos.y += sin(clampf(ball_flight_t, 0.0, 1.0) * PI) * 5.2
		ball_node.position = pos
		ball_node.rotation_degrees.x += 540.0 * delta
		receiver_ring.visible = true
		receiver_ring.position = Vector3(ball_target_pos.x, 0.08, ball_target_pos.z)
		if ball_flight_t >= 1.0:
			_resolve_pass_landing()
	else:
		receiver_ring.visible = is_user_offense and (not pass_thrown_this_down)
		if receiver_ring.visible and user_players.size() > 1:
			var open_wr := user_players[1] if user_players[1].position.z < user_players[2].position.z else user_players[2]
			receiver_ring.position = Vector3(open_wr.position.x, 0.08, open_wr.position.z)
		_attach_ball_to_carrier()

	# Check Touchdowns & Tackles
	if ball_carrier != null:
		if is_user_offense and ball_carrier.position.z <= -50.0:
			_score_touchdown(true)
			return
		elif (not is_user_offense) and ball_carrier.position.z >= 50.0:
			_score_touchdown(false)
			return

		var defenders := ai_players if is_user_offense else user_players
		for def_p in defenders:
			if ball_carrier.position.y > 1.3:
				continue # Jumping over tackler!
			if def_p.position.distance_to(ball_carrier.position) < 1.45:
				# Check Panda Heavy Block or Bull Charge tackle break
				if ball_carrier == controlled_player and ability_active_timer > 0.0 and str(user_team["animal"]) in ["Panda", "Bull", "Bear"]:
					def_p.position += (def_p.position - ball_carrier.position).normalized() * 4.2
					emit_signal("banner_triggered", "BROKEN TACKLE!", GameData.COLOR_GOLD)
					continue
				_resolve_tackle(def_p, ball_carrier, def_p == controlled_player)
				return

	_animate_all_models(base_spd if joy_vector.length() > 0.1 else 0.5, false)
	_emit_hud()

func _update_ai_units(delta: float) -> void:
	var diff: int = int(GameData.settings.get("difficulty", 1))
	var ai_spd_mult: float = (0.84 if diff == 0 else (1.0 if diff == 1 else 1.15)) * float(stadium_data["speed_mult"])
	var ai_spd: float = (6.3 + (float(ai_stats["speed"]) - 75.0) * 0.08) * ai_spd_mult

	# User AI Teammates
	for i in range(user_players.size()):
		var p := user_players[i]
		if p == controlled_player:
			continue
		if is_user_offense:
			if i == 1 or i == 2: # Wide Receivers run routes downfield
				var target_z := maxf(-54.0, line_of_scrimmage - 28.0)
				var step := Vector3(0, 0, -1.0) * 7.2 * delta
				if p.position.z > target_z:
					p.position += step
			else: # Linemen block nearest AI defender
				var nearest := _find_nearest(p.position, ai_players)
				if nearest:
					var dir := (nearest.position - p.position).normalized()
					p.position += Vector3(dir.x, 0, dir.z) * 5.0 * delta
		else:
			var target := ball_target_pos if ball_in_air else (ball_carrier.position if ball_carrier else Vector3.ZERO)
			var dir := (target - p.position).normalized()
			p.position += Vector3(dir.x, 0, dir.z) * 6.2 * delta

	# AI Opponents (frozen if stunned by Lion Roar)
	if stun_timer_ai > 0.0:
		return

	for i in range(ai_players.size()):
		var ai_p := ai_players[i]
		if is_user_offense:
			var target := ball_target_pos if ball_in_air else (ball_carrier.position if ball_carrier else controlled_player.position)
			if (i == 1 or i == 2) and not pass_thrown_this_down and current_play.get("type", "run") == "pass":
				# Cover user receivers
				target = user_players[i].position + Vector3(0, 0, -1.5)
			var dir := (target - ai_p.position).normalized()
			ai_p.position += Vector3(dir.x, 0, dir.z) * ai_spd * delta
			ai_p.rotation.y = atan2(-dir.x, -dir.z)
		else:
			if ai_p == ball_carrier:
				# AI Carrier runs toward +50 endzone while dodging controlled defender
				var avoid := Vector3.ZERO
				if controlled_player and ai_p.position.distance_to(controlled_player.position) < 6.0:
					avoid.x = signf(ai_p.position.x - controlled_player.position.x) * 0.65
				var run_dir := Vector3(avoid.x, 0, 1.0).normalized()
				ai_p.position += run_dir * ai_spd * delta
				ai_p.position.x = clampf(ai_p.position.x, -20.0, 20.0)
				ai_p.rotation.y = atan2(-run_dir.x, -run_dir.z)
			else:
				var nearest_u := _find_nearest(ai_p.position, user_players)
				if nearest_u:
					var bdir := (nearest_u.position - ai_p.position).normalized()
					ai_p.position += Vector3(bdir.x, 0, bdir.z) * (ai_spd * 0.9) * delta

func _resolve_pass_landing() -> void:
	ball_in_air = false
	receiver_ring.visible = false
	# Check Interception by closest defender
	var defenders := ai_players if is_user_offense else user_players
	var closest_def := _find_nearest(ball_target_pos, defenders)
	if closest_def and closest_def.position.distance_to(ball_target_pos) < 2.2 and randf() < 0.35:
		emit_signal("banner_triggered", "INTERCEPTED! TURNOVER!", GameData.COLOR_RED)
		_reset_drive(not is_user_offense, ball_target_pos.z)
		return

	if intended_receiver and intended_receiver.position.distance_to(ball_target_pos) < 5.5:
		intended_receiver.position = Vector3(ball_target_pos.x, 0.0, ball_target_pos.z)
		ball_carrier = intended_receiver
		if is_user_offense:
			controlled_player = intended_receiver
		emit_signal("banner_triggered", "CATCH COMPLETE!", GameData.COLOR_GREEN)
	else:
		emit_signal("banner_triggered", "INCOMPLETE PASS!", GameData.COLOR_WHITE)
		down += 1
		if down > 4:
			emit_signal("banner_triggered", "TURNOVER ON DOWNS!", GameData.COLOR_RED)
			_reset_drive(not is_user_offense, line_of_scrimmage)
		else:
			_setup_formation_for_down()

func _resolve_tackle(tackler: Node3D, carrier: Node3D, is_user_tackler: bool) -> void:
	phase = Phase.TACKLE_CAM
	phase_timer = 1.15
	Engine.time_scale = 0.28 # Hit-stop & slow-motion tackle close-up!
	cam_shake = 0.55

	if is_user_tackler:
		GameData.add_challenge_progress("tackle_5", 1)

	# Check fumble chance (affected by stadium mud + strength stats)
	var base_fumble: float = 0.05 + float(stadium_data["fumble_add"])
	if not bool(GameData.settings.get("arcade_mode", true)):
		base_fumble += 0.04
	if randf() < base_fumble:
		emit_signal("banner_triggered", "BIG HIT FUMBLE! TURNOVER!", GameData.COLOR_RED)
		line_of_scrimmage = clampf(carrier.position.z, -44.0, 44.0)
		is_user_offense = not is_user_offense
		down = 1
		first_down_z = line_of_scrimmage - 10.0 if is_user_offense else line_of_scrimmage + 10.0
		return

	emit_signal("banner_triggered", "CRUSHING TACKLE!", GameData.COLOR_GOLD)

func _advance_down_after_tackle() -> void:
	if ball_carrier == null:
		_setup_formation_for_down()
		return
	var new_z: float = clampf(ball_carrier.position.z, -48.0, 48.0)
	var got_first: bool = (new_z <= first_down_z) if is_user_offense else (new_z >= first_down_z)
	line_of_scrimmage = new_z
	if got_first:
		down = 1
		first_down_z = line_of_scrimmage - 10.0 if is_user_offense else line_of_scrimmage + 10.0
		emit_signal("banner_triggered", "FIRST DOWN!", GameData.COLOR_GOLD)
		_setup_formation_for_down()
	else:
		down += 1
		if down > 4:
			emit_signal("banner_triggered", "TURNOVER ON DOWNS!", GameData.COLOR_RED)
			_reset_drive(not is_user_offense, line_of_scrimmage)
		else:
			_setup_formation_for_down()

func _score_touchdown(for_user: bool) -> void:
	if for_user:
		user_score += 7
		GameData.add_challenge_progress("td_3", 1)
		emit_signal("banner_triggered", "TOUCHDOWN! +7 PTS", GameData.COLOR_GOLD)
	else:
		ai_score += 7
		emit_signal("banner_triggered", str(ai_team["code"]) + " TOUCHDOWN!", GameData.COLOR_RED)
	_trigger_celebration(true)

func _trigger_celebration(spawn_fw: bool) -> void:
	phase = Phase.CELEBRATION
	phase_timer = 2.8
	Engine.time_scale = 0.65
	if spawn_fw:
		_spawn_fireworks()
	_emit_hud()

func _spawn_fireworks() -> void:
	_clear_fireworks()
	var z_pos := -54.0 if is_user_offense else 54.0
	var colors := [Color("#FFB400"), Color("#FF2A85"), Color("#00E5FF"), Color("#2ECC71"), Color.WHITE]
	for b in range(36):
		var c: Color = colors[b % colors.size()]
		var orb := MeshFactory.add_sphere(
			fireworks_root, 0.38,
			Vector3(randf_range(-16.0, 16.0), randf_range(3.5, 13.0), z_pos + randf_range(-5.0, 5.0)),
			MeshFactory.make_mat(c, 0.1, 0.1, true)
		)
		orb.set_meta("vel", Vector3(randf_range(-6.0, 6.0), randf_range(2.0, 8.0), randf_range(-6.0, 6.0)))

func _update_fireworks(dt: float) -> void:
	for child in fireworks_root.get_children():
		if child is Node3D and child.has_meta("vel"):
			var v: Vector3 = child.get_meta("vel")
			child.position += v * dt
			child.scale = Vector3.ONE * (0.7 + 0.5 * absf(sin(anim_time * 12.0)))

func _clear_fireworks() -> void:
	for child in fireworks_root.get_children():
		child.queue_free()

func _attach_ball_to_carrier() -> void:
	if ball_carrier != null and is_instance_valid(ball_carrier):
		ball_node.position = ball_carrier.position + Vector3(0.35, 1.25, 0.25)
		ball_node.rotation_degrees = Vector3(0, ball_carrier.rotation_degrees.y, 25)

func _update_camera(dt: float, instant: bool) -> void:
	if camera == null:
		return
	var focus := controlled_player.position if controlled_player else Vector3.ZERO
	if ball_in_air:
		focus = ball_node.position
	elif phase == Phase.TACKLE_CAM and ball_carrier:
		focus = ball_carrier.position

	var desired_pos: Vector3
	var look_target: Vector3 = focus + Vector3(0, 1.4, 0)

	if phase == Phase.TACKLE_CAM:
		desired_pos = focus + Vector3(3.2, 2.6, 4.2)
	elif phase == Phase.CELEBRATION:
		var orbit_x := sin(anim_time * 1.8) * 7.5
		var orbit_z := cos(anim_time * 1.8) * 7.5
		desired_pos = focus + Vector3(orbit_x, 3.8, orbit_z)
	elif bool(GameData.settings.get("broadcast_cam", false)):
		desired_pos = focus + Vector3(18.5, 13.5, 4.0)
	else:
		var z_offset := 11.5 if is_user_offense else -11.5
		desired_pos = focus + Vector3(0.0, 7.2, z_offset)
		look_target = focus + Vector3(0.0, 1.2, -5.0 if is_user_offense else 5.0)

	if cam_shake > 0.0:
		cam_shake = maxf(0.0, cam_shake - dt * 1.6)
		desired_pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * cam_shake

	if instant:
		camera.position = desired_pos
	else:
		camera.position = camera.position.lerp(desired_pos, clampf(dt * 7.5, 0.05, 1.0))
	camera.look_at(look_target, Vector3.UP)

func _animate_all_models(spd: float, celeb: bool) -> void:
	for p in user_players:
		MeshFactory.animate_character(p, anim_time, spd, celeb and is_user_offense)
	for p in ai_players:
		MeshFactory.animate_character(p, anim_time, spd, celeb and (not is_user_offense))

func _find_nearest(from_pos: Vector3, list: Array[Node3D]) -> Node3D:
	var best: Node3D = null
	var best_d := 9999.0
	for item in list:
		var d := from_pos.distance_to(item.position)
		if d < best_d:
			best_d = d
			best = item
	return best

func _emit_hud() -> void:
	var mins := int(clock_sec) / 60
	var secs := int(clock_sec) % 60
	var down_names := ["1st", "2nd", "3rd", "4th"]
	var d_str: String = down_names[clampi(down - 1, 0, 3)]
	var ytg: int = maxi(1, int(roundf(absf(first_down_z - line_of_scrimmage))))
	emit_signal("match_HUD_updated", {
		"user_code": user_team["code"],
		"ai_code": ai_team["code"],
		"user_score": user_score,
		"ai_score": ai_score,
		"quarter": "Q" + str(quarter),
		"clock": "%d:%02d" % [mins, secs],
		"down_text": "%s & %d" % [d_str, ytg],
		"stamina": stamina,
		"ability_cd": ability_cooldown,
		"ability_name": user_team["ability_name"],
		"is_offense": is_user_offense
	})

func _end_game() -> void:
	Engine.time_scale = 1.0
	phase = Phase.GAME_OVER
	var user_won := user_score >= ai_score
	var reward := 450 if user_won else 150
	GameData.coins += reward
	if user_won:
		GameData.add_challenge_progress("win_match", 1)
	GameData.save_data()
	emit_signal("match_finished", user_won, user_score, ai_score, reward)
