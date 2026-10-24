extends RefCounted

static func make_mat(color: Color, rough: float = 0.55, metal: float = 0.05, emit: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
	return m

static func add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

static func add_sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 14
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_v
	parent.add_child(mi)
	return mi

static func add_capsule(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

static func add_cone(parent: Node3D, bottom_r: float, top_r: float, height: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = bottom_r
	cyl.top_radius = top_r
	cyl.height = height
	cyl.radial_segments = 12
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

static func build_animal_player(team: Dictionary, jersey_num: String = "12", custom_jersey: Color = Color(0, 0, 0, 0), custom_helmet: Color = Color(0, 0, 0, 0)) -> Node3D:
	var root := Node3D.new()
	root.name = "AnimalModel"

	var jersey_col: Color = custom_jersey if custom_jersey.a > 0.1 else Color(team["primary"])
	var helm_col: Color = custom_helmet if custom_helmet.a > 0.1 else Color(team["secondary"])
	var fur_col: Color = Color(team["fur"])
	var animal: String = str(team["animal"])

	var mat_jersey := make_mat(jersey_col, 0.45)
	var mat_helmet := make_mat(helm_col, 0.3, 0.25)
	var mat_fur := make_mat(fur_col, 0.7)
	var mat_white := make_mat(Color.WHITE, 0.5)
	var mat_dark := make_mat(Color("#1A1A1A"), 0.4)
	var mat_gold := make_mat(Color("#FFB400"), 0.3, 0.3)

	var torso := add_box(root, Vector3(0.95, 1.05, 0.62), Vector3(0, 1.25, 0), mat_jersey)
	torso.name = "Torso"
	add_box(torso, Vector3(1.28, 0.36, 0.72), Vector3(0, 0.36, 0), mat_jersey)
	add_box(torso, Vector3(1.32, 0.12, 0.75), Vector3(0, 0.50, 0), mat_helmet)
	add_box(torso, Vector3(0.82, 0.32, 0.56), Vector3(0, -0.62, 0), mat_white)

	for side in [-1.0, 1.0]:
		var lbl := Label3D.new()
		lbl.text = jersey_num
		lbl.font_size = 72
		lbl.pixel_size = 0.0065
		lbl.modulate = Color.WHITE
		lbl.outline_modulate = Color("#0B1A33")
		lbl.outline_size = 14
		lbl.position = Vector3(0, 0.08, side * 0.33)
		if side < 0.0:
			lbl.rotation_degrees = Vector3(0, 180, 0)
		torso.add_child(lbl)

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 2.18, 0)
	root.add_child(head)

	add_sphere(head, 0.42, Vector3.ZERO, mat_fur)
	add_sphere(head, 0.45, Vector3(0, 0.08, -0.03), mat_helmet, Vector3(1.02, 0.92, 1.04))
	add_box(head, Vector3(0.54, 0.07, 0.25), Vector3(0, -0.05, 0.36), mat_dark)
	add_box(head, Vector3(0.52, 0.06, 0.22), Vector3(0, -0.17, 0.36), mat_dark)
	add_sphere(head, 0.065, Vector3(-0.16, 0.05, 0.37), mat_white)
	add_sphere(head, 0.065, Vector3(0.16, 0.05, 0.37), mat_white)
	add_sphere(head, 0.035, Vector3(-0.16, 0.05, 0.42), mat_dark)
	add_sphere(head, 0.035, Vector3(0.16, 0.05, 0.42), mat_dark)

	match animal:
		"Lion":
			var mat_mane := make_mat(Color("#8B4513"), 0.8)
			add_box(head, Vector3(0.98, 0.88, 0.55), Vector3(0, 0.02, -0.12), mat_mane)
			add_box(head, Vector3(0.36, 0.24, 0.32), Vector3(0, -0.10, 0.42), mat_fur)
			add_sphere(head, 0.08, Vector3(0, -0.04, 0.58), mat_dark)
			add_cone(torso, 0.06, 0.03, 0.75, Vector3(0, -0.45, -0.45), mat_fur, Vector3(45, 0, 0))
		"Bull":
			add_box(head, Vector3(0.44, 0.26, 0.36), Vector3(0, -0.12, 0.44), mat_fur)
			add_cone(head, 0.11, 0.01, 0.52, Vector3(-0.48, 0.28, 0.05), mat_white, Vector3(0, 0, 48))
			add_cone(head, 0.11, 0.01, 0.52, Vector3(0.48, 0.28, 0.05), mat_white, Vector3(0, 0, -48))
			add_sphere(head, 0.07, Vector3(0, -0.18, 0.62), mat_gold)
		"Eagle":
			add_cone(head, 0.16, 0.01, 0.46, Vector3(0, -0.06, 0.56), mat_gold, Vector3(90, 0, 0))
			add_box(head, Vector3(0.20, 0.25, 0.45), Vector3(0, 0.42, -0.05), mat_white)
			add_box(torso, Vector3(0.42, 0.10, 0.38), Vector3(0, -0.5, -0.42), mat_fur, Vector3(-20, 0, 0))
		"Wolf":
			add_cone(head, 0.20, 0.07, 0.42, Vector3(0, -0.09, 0.48), mat_fur, Vector3(90, 0, 0))
			add_cone(head, 0.11, 0.01, 0.34, Vector3(-0.26, 0.44, 0), mat_fur)
			add_cone(head, 0.11, 0.01, 0.34, Vector3(0.26, 0.44, 0), mat_fur)
			add_capsule(torso, 0.11, 0.65, Vector3(0, -0.42, -0.48), mat_fur, Vector3(50, 0, 0))
		"Bear":
			add_sphere(head, 0.22, Vector3(0, -0.10, 0.42), mat_fur)
			add_sphere(head, 0.14, Vector3(-0.34, 0.36, 0), mat_fur)
			add_sphere(head, 0.14, Vector3(0.34, 0.36, 0), mat_fur)
			add_sphere(torso, 0.14, Vector3(0, -0.50, -0.36), mat_fur)
		"Kangaroo":
			add_cone(head, 0.12, 0.03, 0.56, Vector3(-0.22, 0.55, -0.05), mat_fur, Vector3(-12, 0, 10))
			add_cone(head, 0.12, 0.03, 0.56, Vector3(0.22, 0.55, -0.05), mat_fur, Vector3(-12, 0, -10))
			add_box(head, Vector3(0.30, 0.22, 0.40), Vector3(0, -0.10, 0.44), mat_fur)
			add_cone(torso, 0.16, 0.05, 0.95, Vector3(0, -0.45, -0.55), mat_fur, Vector3(55, 0, 0))
		"Panda":
			add_sphere(head, 0.14, Vector3(-0.34, 0.38, 0), mat_dark)
			add_sphere(head, 0.14, Vector3(0.34, 0.38, 0), mat_dark)
			add_sphere(head, 0.11, Vector3(-0.17, 0.05, 0.34), mat_dark)
			add_sphere(head, 0.11, Vector3(0.17, 0.05, 0.34), mat_dark)
			add_box(head, Vector3(0.28, 0.20, 0.30), Vector3(0, -0.10, 0.40), mat_white)
		"Jaguar":
			add_sphere(head, 0.12, Vector3(-0.30, 0.36, 0), mat_fur)
			add_sphere(head, 0.12, Vector3(0.30, 0.36, 0), mat_fur)
			add_box(head, Vector3(0.34, 0.22, 0.32), Vector3(0, -0.10, 0.40), mat_fur)
			add_capsule(torso, 0.07, 0.80, Vector3(0, -0.42, -0.48), mat_fur, Vector3(45, 0, 0))

	var arm_l := add_capsule(root, 0.15, 0.72, Vector3(-0.68, 1.25, 0), mat_fur)
	arm_l.name = "ArmL"
	var arm_r := add_capsule(root, 0.15, 0.72, Vector3(0.68, 1.25, 0), mat_fur)
	arm_r.name = "ArmR"
	var leg_l := add_capsule(root, 0.17, 0.75, Vector3(-0.26, 0.42, 0), mat_white)
	leg_l.name = "LegL"
	var leg_r := add_capsule(root, 0.17, 0.75, Vector3(0.26, 0.42, 0), mat_white)
	leg_r.name = "LegR"

	return root

static func animate_character(model: Node3D, time_sec: float, move_speed: float, celebrating: bool = false) -> void:
	if model == null:
		return
	var arm_l := model.get_node_or_null("ArmL") as Node3D
	var arm_r := model.get_node_or_null("ArmR") as Node3D
	var leg_l := model.get_node_or_null("LegL") as Node3D
	var leg_r := model.get_node_or_null("LegR") as Node3D
	var torso := model.get_node_or_null("Torso") as Node3D

	if celebrating:
		var bounce := absf(sin(time_sec * 10.0)) * 0.45
		model.position.y = bounce
		if arm_l: arm_l.rotation_degrees.x = -150.0 + sin(time_sec * 14.0) * 25.0
		if arm_r: arm_r.rotation_degrees.x = -150.0 - sin(time_sec * 14.0) * 25.0
		if leg_l: leg_l.rotation_degrees.x = sin(time_sec * 12.0) * 30.0
		if leg_r: leg_r.rotation_degrees.x = -sin(time_sec * 12.0) * 30.0
		return

	if move_speed > 0.4:
		var swing := sin(time_sec * 13.0) * 42.0 * clampf(move_speed / 8.0, 0.3, 1.3)
		if arm_l: arm_l.rotation_degrees.x = swing
		if arm_r: arm_r.rotation_degrees.x = -swing
		if leg_l: leg_l.rotation_degrees.x = -swing
		if leg_r: leg_r.rotation_degrees.x = swing
		if torso: torso.position.y = 1.25 + absf(sin(time_sec * 26.0)) * 0.08
	else:
		var idle := sin(time_sec * 3.2) * 5.0
		if arm_l: arm_l.rotation_degrees.x = idle
		if arm_r: arm_r.rotation_degrees.x = -idle
		if leg_l: leg_l.rotation_degrees.x = 0.0
		if leg_r: leg_r.rotation_degrees.x = 0.0
		if torso: torso.position.y = 1.25 + sin(time_sec * 3.2) * 0.03

static func build_football(ball_color: Color = Color("#A84A18")) -> Node3D:
	var root := Node3D.new()
	root.name = "Football"
	var mat_leather := make_mat(ball_color, 0.45, 0.1)
	var mat_white := make_mat(Color.WHITE, 0.3)

	add_sphere(root, 0.26, Vector3.ZERO, mat_leather, Vector3(0.85, 0.85, 1.45))
	add_box(root, Vector3(0.04, 0.04, 0.28), Vector3(0, 0.22, 0), mat_white)
	for i in range(-2, 3):
		add_box(root, Vector3(0.11, 0.03, 0.025), Vector3(0, 0.22, i * 0.055), mat_white)
	return root

static func build_stadium(stadium_data: Dictionary, home_team: Dictionary, away_team: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Stadium"

	var turf_a := make_mat(Color(stadium_data["turf_a"]), 0.85)
	var turf_b := make_mat(Color(stadium_data["turf_b"]), 0.85)
	var mat_surround := make_mat(Color(stadium_data["surround"]), 0.9)
	var mat_line := make_mat(Color.WHITE, 0.5)
	var mat_post := make_mat(Color("#FFB400"), 0.3, 0.3, true)
	var mat_wall := make_mat(Color("#0B1A33"), 0.7)
	var mat_home_ez := make_mat(Color(home_team["primary"]), 0.75)
	var mat_away_ez := make_mat(Color(away_team["primary"]), 0.75)

	add_box(root, Vector3(95.0, 0.2, 165.0), Vector3(0, -0.18, 0), mat_surround)

	for i in range(20):
		var z_center: float = -47.5 + float(i) * 5.0
		var stripe_mat := turf_a if (i % 2 == 0) else turf_b
		add_box(root, Vector3(44.0, 0.12, 5.0), Vector3(0, -0.06, z_center), stripe_mat)
		add_box(root, Vector3(44.0, 0.13, 0.18), Vector3(0, -0.05, z_center - 2.5), mat_line)

	add_box(root, Vector3(44.0, 0.13, 0.22), Vector3(0, -0.05, 50.0), mat_line)
	add_box(root, Vector3(0.4, 0.14, 120.0), Vector3(-22.0, -0.05, 0), mat_line)
	add_box(root, Vector3(0.4, 0.14, 120.0), Vector3(22.0, -0.05, 0), mat_line)

	add_box(root, Vector3(44.0, 0.13, 10.0), Vector3(0, -0.055, 55.0), mat_home_ez)
	add_box(root, Vector3(44.0, 0.13, 10.0), Vector3(0, -0.055, -55.0), mat_away_ez)

	var ez_home_lbl := Label3D.new()
	ez_home_lbl.text = str(home_team["code"]) + " ENDZONE"
	ez_home_lbl.font_size = 96
	ez_home_lbl.pixel_size = 0.025
	ez_home_lbl.rotation_degrees = Vector3(-90, 0, 0)
	ez_home_lbl.position = Vector3(0, 0.06, 55.0)
	root.add_child(ez_home_lbl)

	var ez_away_lbl := Label3D.new()
	ez_away_lbl.text = str(away_team["code"]) + " ENDZONE"
	ez_away_lbl.font_size = 96
	ez_away_lbl.pixel_size = 0.025
	ez_away_lbl.rotation_degrees = Vector3(-90, 180, 0)
	ez_away_lbl.position = Vector3(0, 0.06, -55.0)
	root.add_child(ez_away_lbl)

	var yard_marks: Array[int] = [-40, -30, -20, -10, 0, 10, 20, 30, 40]
	var yard_texts: Array[String] = ["10", "20", "30", "40", "50", "40", "30", "20", "10"]
	for idx in range(yard_marks.size()):
		for side_x in [-16.0, 16.0]:
			var ylbl := Label3D.new()
			ylbl.text = yard_texts[idx]
			ylbl.font_size = 68
			ylbl.pixel_size = 0.022
			ylbl.modulate = Color(1, 1, 1, 0.85)
			ylbl.rotation_degrees = Vector3(-90, 0, 0)
			ylbl.position = Vector3(side_x, 0.05, float(yard_marks[idx]))
			root.add_child(ylbl)

	for side_z in [-60.0, 60.0]:
		add_box(root, Vector3(0.45, 3.6, 0.45), Vector3(0, 1.8, side_z), mat_post)
		add_box(root, Vector3(6.6, 0.38, 0.38), Vector3(0, 3.6, side_z), mat_post)
		add_box(root, Vector3(0.32, 5.5, 0.32), Vector3(-3.15, 6.3, side_z), mat_post)
		add_box(root, Vector3(0.32, 5.5, 0.32), Vector3(3.15, 6.3, side_z), mat_post)

	add_box(root, Vector3(5.0, 4.5, 134.0), Vector3(-28.0, 2.1, 0), mat_wall)
	add_box(root, Vector3(5.0, 4.5, 134.0), Vector3(28.0, 2.1, 0), mat_wall)
	add_box(root, Vector3(60.0, 4.5, 5.0), Vector3(0, 2.1, -66.0), mat_wall)
	add_box(root, Vector3(60.0, 4.5, 5.0), Vector3(0, 2.1, 66.0), mat_wall)

	var light_mat := make_mat(Color("#FFF8D6"), 0.2, 0.1, true)
	for cx in [-30.0, 30.0]:
		for cz in [-66.0, 66.0]:
			add_box(root, Vector3(1.1, 16.0, 1.1), Vector3(cx, 8.0, cz), mat_wall)
			add_box(root, Vector3(3.8, 2.2, 1.2), Vector3(cx, 16.5, cz), light_mat)

	var st_id: int = int(stadium_data["id"])
	if st_id == 2:
		var mat_mud := make_mat(Color("#5C4033"), 0.95)
		add_box(root, Vector3(7.5, 0.14, 5.5), Vector3(-6.0, -0.04, -12.0), mat_mud)
		add_box(root, Vector3(8.0, 0.14, 6.0), Vector3(7.0, -0.04, 15.0), mat_mud)
	elif st_id == 1:
		var mat_snow := make_mat(Color.WHITE, 0.9)
		add_box(root, Vector3(2.8, 0.7, 110.0), Vector3(-24.2, 0.3, 0), mat_snow)
		add_box(root, Vector3(2.8, 0.7, 110.0), Vector3(24.2, 0.3, 0), mat_snow)

	return root
