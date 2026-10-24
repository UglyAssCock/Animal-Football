extends Node

const SAVE_PATH := "user://animal_football_save.cfg"

const COLOR_NAVY := Color("#0B1A33")
const COLOR_NAVY_LIGHT := Color("#152C52")
const COLOR_CARD := Color("#112545")
const COLOR_GOLD := Color("#FFB400")
const COLOR_JERSEY_BLUE := Color("#1664E8")
const COLOR_WHITE := Color("#FFFFFF")
const COLOR_GREEN := Color("#2ECC71")
const COLOR_RED := Color("#E74C3C")

var coins: int = 2500
var selected_team_id: int = 0
var selected_stadium_id: int = 0
var equipped_skin: String = "classic_blue"
var equipped_helmet: String = "pro_gold"
var equipped_ball: String = "pro_leather"
var equipped_emote: String = "backflip"

var owned_items: Array[String] = [
	"classic_blue", "pro_gold", "pro_leather", "backflip"
]

var settings: Dictionary = {
	"difficulty": 1, # 0 Easy, 1 Normal, 2 Hard
	"arcade_mode": true,
	"broadcast_cam": false,
	"quarter_minutes": 2
}

var trophies_won: int = 0
var tournament_round: int = 0 # 0 QF, 1 SF, 2 Final
var tournament_bracket: Array = []

var daily_challenges: Array = [
	{"id": "td_3", "title": "Score 3 Touchdowns", "progress": 0, "goal": 3, "reward": 350, "claimed": false},
	{"id": "tackle_5", "title": "Land 5 Big Tackles", "progress": 0, "goal": 5, "reward": 250, "claimed": false},
	{"id": "win_match", "title": "Win 1 Match in Any Mode", "progress": 0, "goal": 1, "reward": 400, "claimed": false}
]

const TEAMS: Array = [
	{
		"id": 0,
		"name": "USA Lions",
		"country": "USA",
		"animal": "Lion",
		"code": "USA",
		"primary": Color("#1664E8"),
		"secondary": Color("#FFB400"),
		"fur": Color("#E09132"),
		"speed": 84,
		"strength": 86,
		"agility": 82,
		"stamina": 85,
		"ability_name": "Lion Roar",
		"ability_desc": "Sonic roar stuns nearby defenders for 2.2s",
		"cooldown": 9.0
	},
	{
		"id": 1,
		"name": "Spain Bulls",
		"country": "Spain",
		"animal": "Bull",
		"code": "ESP",
		"primary": Color("#C82333"),
		"secondary": Color("#FFB400"),
		"fur": Color("#5C3A21"),
		"speed": 80,
		"strength": 95,
		"agility": 74,
		"stamina": 88,
		"ability_name": "Bull Charge",
		"ability_desc": "Unstoppable horned charge knocks tacklers flying",
		"cooldown": 10.0
	},
	{
		"id": 2,
		"name": "Germany Eagles",
		"country": "Germany",
		"animal": "Eagle",
		"code": "GER",
		"primary": Color("#222831"),
		"secondary": Color("#F0A500"),
		"fur": Color("#4A3525"),
		"speed": 91,
		"strength": 75,
		"agility": 92,
		"stamina": 84,
		"ability_name": "Eagle Glide Leap",
		"ability_desc": "Soars high through the air over the defensive line",
		"cooldown": 8.5
	},
	{
		"id": 3,
		"name": "France Wolves",
		"country": "France",
		"animal": "Wolf",
		"code": "FRA",
		"primary": Color("#1C3FAA"),
		"secondary": Color("#E63946"),
		"fur": Color("#7F8C8D"),
		"speed": 93,
		"strength": 78,
		"agility": 90,
		"stamina": 89,
		"ability_name": "Wolf Speed Burst",
		"ability_desc": "Pack sprint boosts top speed by 65% for 3s",
		"cooldown": 8.0
	},
	{
		"id": 4,
		"name": "Russia Bears",
		"country": "Russia",
		"animal": "Bear",
		"code": "RUS",
		"primary": Color("#9B1B30"),
		"secondary": Color("#D4AF37"),
		"fur": Color("#6E472B"),
		"speed": 76,
		"strength": 98,
		"agility": 72,
		"stamina": 92,
		"ability_name": "Bear Power Tackle",
		"ability_desc": "Shockwave slam crushes blockers or tacklers",
		"cooldown": 9.5
	},
	{
		"id": 5,
		"name": "Australia Roos",
		"country": "Australia",
		"animal": "Kangaroo",
		"code": "AUS",
		"primary": Color("#1E824C"),
		"secondary": Color("#FFB400"),
		"fur": Color("#C67D3B"),
		"speed": 89,
		"strength": 80,
		"agility": 95,
		"stamina": 87,
		"ability_name": "Kangaroo Jump",
		"ability_desc": "Mega spring vault leaps clean over tacklers",
		"cooldown": 7.5
	},
	{
		"id": 6,
		"name": "China Pandas",
		"country": "China",
		"animal": "Panda",
		"code": "CHN",
		"primary": Color("#D62828"),
		"secondary": Color("#FCBF49"),
		"fur": Color("#F5F5F5"),
		"speed": 78,
		"strength": 94,
		"agility": 79,
		"stamina": 93,
		"ability_name": "Panda Heavy Block",
		"ability_desc": "Iron belly shield repels all defenders for 3s",
		"cooldown": 10.0
	},
	{
		"id": 7,
		"name": "Brazil Jaguars",
		"country": "Brazil",
		"animal": "Jaguar",
		"code": "BRA",
		"primary": Color("#2A9D8F"),
		"secondary": Color("#FFB400"),
		"fur": Color("#E9A825"),
		"speed": 96,
		"strength": 77,
		"agility": 96,
		"stamina": 83,
		"ability_name": "Jaguar Quick Dash",
		"ability_desc": "Razor-fast burst dashes 8 yards instantly",
		"cooldown": 7.0
	}
]

const STADIUMS: Array = [
	{
		"id": 0,
		"name": "Desert Arena",
		"effect_title": "Scorching Sun: +35% Sprint Stamina Drain",
		"speed_mult": 1.02,
		"stamina_drain_mult": 1.35,
		"fumble_add": 0.0,
		"agility_mult": 1.0,
		"turf_a": Color("#38983E"),
		"turf_b": Color("#43AD49"),
		"surround": Color("#D9A05B"),
		"sky": Color("#F4A261"),
		"ambient_energy": 1.15
	},
	{
		"id": 1,
		"name": "Snow Field",
		"effect_title": "Frozen Turf: -18% Speed & Slippery Cuts",
		"speed_mult": 0.82,
		"stamina_drain_mult": 0.9,
		"fumble_add": 0.04,
		"agility_mult": 0.85,
		"turf_a": Color("#4C9A6A"),
		"turf_b": Color("#63B082"),
		"surround": Color("#E8F1F5"),
		"sky": Color("#A8DADC"),
		"ambient_energy": 1.1
	},
	{
		"id": 2,
		"name": "Jungle Stadium",
		"effect_title": "Heavy Mud: -15% Speed & +10% Fumble Risk",
		"speed_mult": 0.85,
		"stamina_drain_mult": 1.2,
		"fumble_add": 0.10,
		"agility_mult": 0.9,
		"turf_a": Color("#267332"),
		"turf_b": Color("#2E853B"),
		"surround": Color("#4A3B2C"),
		"sky": Color("#52B788"),
		"ambient_energy": 0.95
	},
	{
		"id": 3,
		"name": "Night Stadium",
		"effect_title": "Prime-Time Lights: +12% Speed & Agility Boost",
		"speed_mult": 1.12,
		"stamina_drain_mult": 0.95,
		"fumble_add": 0.0,
		"agility_mult": 1.15,
		"turf_a": Color("#1E7E34"),
		"turf_b": Color("#25923E"),
		"surround": Color("#162436"),
		"sky": Color("#091326"),
		"ambient_energy": 0.85
	}
]

const CUSTOM_ITEMS: Dictionary = {
	"Skins": [
		{"id": "classic_blue", "name": "Blue #12 Home", "price": 0, "color": Color("#1664E8"), "bonus_stat": "speed", "bonus_val": 2},
		{"id": "royal_gold", "name": "Gold #12 MVP", "price": 600, "color": Color("#E09F1F"), "bonus_stat": "agility", "bonus_val": 5},
		{"id": "crimson_blitz", "name": "Crimson #12 Blitz", "price": 750, "color": Color("#D62828"), "bonus_stat": "strength", "bonus_val": 6},
		{"id": "neon_emerald", "name": "Emerald #12 Turf", "price": 900, "color": Color("#10B981"), "bonus_stat": "stamina", "bonus_val": 7}
	],
	"Helmets": [
		{"id": "pro_gold", "name": "Gold Gridiron", "price": 0, "color": Color("#FFB400"), "bonus_stat": "strength", "bonus_val": 2},
		{"id": "titanium_white", "name": "Titanium White", "price": 500, "color": Color("#F8F9FA"), "bonus_stat": "speed", "bonus_val": 4},
		{"id": "midnight_visor", "name": "Navy Visor Pro", "price": 800, "color": Color("#1D3557"), "bonus_stat": "agility", "bonus_val": 6},
		{"id": "fire_chrome", "name": "Blaze Chrome", "price": 1100, "color": Color("#F77F00"), "bonus_stat": "strength", "bonus_val": 8}
	],
	"Balls": [
		{"id": "pro_leather", "name": "Pro Leather", "price": 0, "color": Color("#A84A18"), "bonus_stat": "agility", "bonus_val": 1},
		{"id": "gold_trophy", "name": "Golden Spiral", "price": 650, "color": Color("#FFB400"), "bonus_stat": "speed", "bonus_val": 4},
		{"id": "neon_cyber", "name": "Electric Cyan", "price": 850, "color": Color("#00B4D8"), "bonus_stat": "stamina", "bonus_val": 5},
		{"id": "lava_core", "name": "Volcano Core", "price": 1000, "color": Color("#E63946"), "bonus_stat": "strength", "bonus_val": 6}
	],
	"Emotes": [
		{"id": "backflip", "name": "Star Spin Jump", "price": 0, "color": Color("#FFB400"), "bonus_stat": "stamina", "bonus_val": 2},
		{"id": "roar_flex", "name": "Champion Flex", "price": 450, "color": Color("#F77F00"), "bonus_stat": "strength", "bonus_val": 4},
		{"id": "lightning_dance", "name": "Endzone Shuffle", "price": 700, "color": Color("#4CC9F0"), "bonus_stat": "agility", "bonus_val": 5},
		{"id": "crown_bow", "name": "Royal Salute", "price": 950, "color": Color("#9D4EDD"), "bonus_stat": "speed", "bonus_val": 6}
	]
}

const OFFENSE_PLAYS: Array = [
	{"id": "inside_run", "name": "INSIDE POWER RUN", "type": "run", "desc": "HB #12 blasts up the middle behind heavy blocks"},
	{"id": "sweep_run", "name": "OUTSIDE TURBO SWEEP", "type": "run", "desc": "Fast sideline sprint with lead blocker"},
	{"id": "long_bomb", "name": "HAIL MARY PASS", "type": "pass", "desc": "Receivers streak deep for a big touchdown throw"}
]

const DEFENSE_PLAYS: Array = [
	{"id": "man_lock", "name": "MAN LOCK COVERAGE", "type": "cover", "desc": "Tight coverage on all receivers"},
	{"id": "all_blitz", "name": "ALL-OUT ANIMAL BLITZ", "type": "blitz", "desc": "Rush the backfield to force a sack or fumble"},
	{"id": "zone_wall", "name": "DEEP ZONE WALL", "type": "zone", "desc": "Prevent deep passes and swarm the ball"}
]

func _ready() -> void:
	load_data()
	if tournament_bracket.is_empty():
		reset_tournament()

func get_selected_team() -> Dictionary:
	return TEAMS[clampi(selected_team_id, 0, TEAMS.size() - 1)]

func get_selected_stadium() -> Dictionary:
	return STADIUMS[clampi(selected_stadium_id, 0, STADIUMS.size() - 1)]

func get_effective_stats(team_id: int) -> Dictionary:
	var t: Dictionary = TEAMS[clampi(team_id, 0, TEAMS.size() - 1)]
	var stats := {
		"speed": int(t["speed"]),
		"strength": int(t["strength"]),
		"agility": int(t["agility"]),
		"stamina": int(t["stamina"])
	}
	if team_id == selected_team_id:
		for category in CUSTOM_ITEMS.keys():
			for item in CUSTOM_ITEMS[category]:
				if is_item_equipped(item["id"]):
					var st: String = item["bonus_stat"]
					stats[st] = mini(99, stats[st] + int(item["bonus_val"]))
	return stats

func get_equipped_color(category: String, fallback: Color) -> Color:
	var eq_id := ""
	match category:
		"Skins": eq_id = equipped_skin
		"Helmets": eq_id = equipped_helmet
		"Balls": eq_id = equipped_ball
		"Emotes": eq_id = equipped_emote
	if CUSTOM_ITEMS.has(category):
		for item in CUSTOM_ITEMS[category]:
			if item["id"] == eq_id:
				return item["color"]
	return fallback

func is_item_owned(item_id: String) -> bool:
	return owned_items.has(item_id)

func is_item_equipped(item_id: String) -> bool:
	return equipped_skin == item_id or equipped_helmet == item_id or equipped_ball == item_id or equipped_emote == item_id

func buy_or_equip_item(category: String, item: Dictionary) -> bool:
	var id: String = item["id"]
	if not is_item_owned(id):
		var price: int = int(item["price"])
		if coins < price:
			return false
		coins -= price
		owned_items.append(id)
	match category:
		"Skins": equipped_skin = id
		"Helmets": equipped_helmet = id
		"Balls": equipped_ball = id
		"Emotes": equipped_emote = id
	save_data()
	return true

func add_challenge_progress(challenge_id: String, amount: int) -> void:
	for ch in daily_challenges:
		if ch["id"] == challenge_id and not ch["claimed"]:
			ch["progress"] = mini(int(ch["goal"]), int(ch["progress"]) + amount)
	save_data()

func reset_tournament() -> void:
	tournament_round = 0
	var ids: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
	ids.erase(selected_team_id)
	ids.shuffle()
	ids.push_front(selected_team_id)
	tournament_bracket = [
		[ids[0], ids[1], ids[2], ids[3], ids[4], ids[5], ids[6], ids[7]], # QF (8 teams)
		[], # SF (4 teams)
		[]  # Final (2 teams)
	]
	save_data()

func get_next_tournament_opponent() -> int:
	if tournament_bracket.is_empty():
		reset_tournament()
	var current_list: Array = tournament_bracket[clampi(tournament_round, 0, 2)]
	if current_list.size() >= 2:
		return int(current_list[1])
	return (selected_team_id + 1) % TEAMS.size()

func advance_tournament(player_won: bool) -> String:
	if not player_won:
		reset_tournament()
		return "ELIMINATED! Bracket Reset."
	var current_list: Array = tournament_bracket[tournament_round]
	if tournament_round < 2:
		var next_list: Array = [selected_team_id]
		var i := 2
		while i < current_list.size():
			var a: int = int(current_list[i])
			var b: int = int(current_list[i + 1])
			next_list.append(a if randf() < 0.5 else b)
			i += 2
		tournament_round += 1
		tournament_bracket[tournament_round] = next_list
		save_data()
		return "ADVANCED TO NEXT ROUND!"
	else:
		trophies_won += 1
		coins += 1000
		reset_tournament()
		save_data()
		return "CHAMPION! +1000 COINS & TROPHY!"

func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "coins", coins)
	cfg.set_value("player", "selected_team_id", selected_team_id)
	cfg.set_value("player", "selected_stadium_id", selected_stadium_id)
	cfg.set_value("player", "equipped_skin", equipped_skin)
	cfg.set_value("player", "equipped_helmet", equipped_helmet)
	cfg.set_value("player", "equipped_ball", equipped_ball)
	cfg.set_value("player", "equipped_emote", equipped_emote)
	cfg.set_value("player", "owned_items", owned_items)
	cfg.set_value("player", "trophies_won", trophies_won)
	cfg.set_value("player", "settings", settings)
	cfg.set_value("player", "daily_challenges", daily_challenges)
	cfg.save(SAVE_PATH)

func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = int(cfg.get_value("player", "coins", 2500))
	selected_team_id = int(cfg.get_value("player", "selected_team_id", 0))
	selected_stadium_id = int(cfg.get_value("player", "selected_stadium_id", 0))
	equipped_skin = str(cfg.get_value("player", "equipped_skin", "classic_blue"))
	equipped_helmet = str(cfg.get_value("player", "equipped_helmet", "pro_gold"))
	equipped_ball = str(cfg.get_value("player", "equipped_ball", "pro_leather"))
	equipped_emote = str(cfg.get_value("player", "equipped_emote", "backflip"))
	trophies_won = int(cfg.get_value("player", "trophies_won", 0))
	var loaded_owned = cfg.get_value("player", "owned_items", owned_items)
	if loaded_owned is Array:
		owned_items.clear()
		for it in loaded_owned:
			owned_items.append(str(it))
	var loaded_settings = cfg.get_value("player", "settings", settings)
	if loaded_settings is Dictionary:
		for k in loaded_settings.keys():
			settings[k] = loaded_settings[k]
	var loaded_ch = cfg.get_value("player", "daily_challenges", daily_challenges)
	if loaded_ch is Array and loaded_ch.size() == 3:
		daily_challenges = loaded_ch
