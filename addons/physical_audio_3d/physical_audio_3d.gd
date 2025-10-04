extends AudioStreamPlayer3D
class_name PhysicalAudio3D


const MAX_WALLS: int = 5


## The node that the audio will path toward.
@export var audio_target: PhysicsBody3D
## The home position of the audio. This is where the audio should be when nothing
## is between it and the listener. If the source of the audio is moving, this value must be
## set each frame.
@export var home_position := Vector3.ZERO
## Select this to disable audio navigation. This node will act as a regular
## AudioStreamPlayer3D.
@export var disabled := false
## The physics layer that the audio will use to find the listener.
@export_flags_3d_physics var target_collision_layer: int = 1
@export_category("Navigation")
## The radius of the audio navigation agent. Audio will not travel through openings
## smaller than this value.
@export_range(0.05, 100.0) var nav_agent_radius: float = 0.25
## The radius of the audio navigation agent. Audio will not travel through openings
## smaller than this value.
@export_range(0.05, 100.0) var nav_agent_height: float = 0.25
## The navigation layer that the audio paths on.
@export_flags_3d_navigation var audio_navigation_layer: int = 1
@export_category("Audio")
## The frequency attentuation value for when there is nothing between the audio
## and the listener.
@export_range(2000.0, 10000.0) var max_attenuation_cutoff_hz: float = 5000.0
## The minimum frequency attenuation value as the path between the audio and the
## player becomes more complex.
@export_range(300.0, 10000.0) var min_attenuation_cutoff_hz: float = 1000.0
@export_category("Debugging")
## Select this to show the path that the audio takes to the listener.
@export var show_navigation_path := false
## Select this to show the position of the audio in the game space.
@export var show_audio_position := false


var ray_cast_floor: RayCast3D
var ray_cast_origin: RayCast3D
var ray_cast_nav: RayCast3D
var nav_base: Node3D
var nav_agent: NavigationAgent3D
var height_off_floor: float


func _ready() -> void:
	if home_position != global_position:
		home_position = global_position
	
	if show_audio_position:
		var new_meshinstance := MeshInstance3D.new()
		var new_mesh := QuadMesh.new()
		new_meshinstance.mesh = new_mesh
		add_child(new_meshinstance)
		
		var new_material := StandardMaterial3D.new()
		new_material.no_depth_test = true
		new_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		new_material.albedo_texture = preload("res://addons/physical_audio_3d/audio_texture.png")
		new_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		new_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		new_meshinstance.material_override = new_material

	var new_rcf := RayCast3D.new()
	add_child(new_rcf)
	ray_cast_floor = new_rcf
	var new_rco := RayCast3D.new()
	add_child(new_rco)
	ray_cast_origin = new_rco
	var new_rcn := RayCast3D.new()
	add_child(new_rcn)
	ray_cast_nav = new_rcn

	var new_base := Node3D.new()
	add_child(new_base)
	nav_base = new_base
	var new_nav := NavigationAgent3D.new()
	nav_base.add_child(new_nav)
	nav_agent = new_nav
	nav_agent.debug_enabled = show_navigation_path
	
	nav_agent.radius = nav_agent_radius
	nav_agent.height = nav_agent_height
	
	ray_cast_floor.top_level = true
	ray_cast_origin.top_level = true
	ray_cast_nav.top_level = true
	nav_base.top_level = true

	ray_cast_origin.set_collision_mask_value(target_collision_layer, true)
	ray_cast_nav.set_collision_mask_value(target_collision_layer, true)
	ray_cast_origin.hit_from_inside = true
	ray_cast_nav.hit_from_inside = true

	ray_cast_floor.target_position.y = -10.0


func _physics_process(_delta: float) -> void:
	nav_base.global_position = home_position
	ray_cast_floor.global_position = home_position
	ray_cast_origin.global_position = home_position

	if not disabled:
		if not height_off_floor:
			if ray_cast_floor.is_colliding():
				height_off_floor = global_position.y - ray_cast_floor.get_collision_point().y
			else:
				height_off_floor = global_position.y
			nav_agent.path_height_offset = -height_off_floor

		var audio_target_obstructed := false
		if audio_target:
			ray_cast_origin.target_position = ray_cast_origin.to_local(audio_target.global_position + Vector3.UP)
			if ray_cast_origin.is_colliding():
				if ray_cast_origin.get_collider() != audio_target:
					audio_target_obstructed = true

		if audio_target_obstructed:
			var audio_pos: Vector3
			var travel_dist: float = 0.0
			var travel_angle_sum: float = 0.0
			nav_agent.target_position = audio_target.global_position
			nav_agent.get_next_path_position()
			var can_reach_target := nav_agent.is_target_reachable()
			var nav_path := nav_agent.get_current_navigation_path()
			var path_size: int = nav_path.size()
			var idx: int = 0
			for point: Vector3 in nav_path:
				if not audio_pos:
					ray_cast_nav.global_position = point + Vector3.UP
					var target_local := ray_cast_nav.to_local(audio_target.global_position + Vector3.UP)
					ray_cast_nav.target_position = target_local
					ray_cast_nav.force_update_transform()
					ray_cast_nav.force_raycast_update()
					if ray_cast_nav.is_colliding():
						if ray_cast_nav.get_collider() == audio_target:
							audio_pos = point
				if idx:
					travel_dist += point.distance_to(nav_path[idx - 1])
					var dir_1: Vector3 = nav_path[idx - 1].direction_to(point)
					var dir_2: Vector3
					if idx < nav_path.size() - 1:
						dir_2 = point.direction_to(nav_path[idx + 1])
					else:
						dir_2 = point.direction_to(audio_target.global_position)
					travel_angle_sum += dir_1.angle_to(dir_2)
				idx += 1
			var far_distance := audio_target.global_position.direction_to(audio_pos) * travel_dist
			var audio_target_pos: Vector3 = audio_pos + far_distance + Vector3(0.0,
																	height_off_floor,
																	0.0)
			var angle_sum_clamped: float = clampf(travel_angle_sum, PI/2.0, 3.0 * PI)
			var max_atten_sub: float = max_attenuation_cutoff_hz - min_attenuation_cutoff_hz
			var target_cutoff: float = max_attenuation_cutoff_hz - remap(travel_angle_sum,
																		PI/2.0,
																		3.0 * PI,
																		0.0,
																		max_atten_sub)
			
			if not can_reach_target:
				var wall_count: int = 0
				for i in MAX_WALLS:
					pass
					# pass
			
			global_position = slerp_around(global_position,
										audio_target_pos,
										audio_target.global_position,
										0.1)
			attenuation_filter_cutoff_hz = lerpf(attenuation_filter_cutoff_hz,
											target_cutoff,
											0.05)
		else:
			var goto: Vector3
			if home_position:
				goto = home_position
			else:
				goto = get_parent().global_position
			global_position = global_position.lerp(goto, 0.2)
			attenuation_filter_cutoff_hz = lerpf(attenuation_filter_cutoff_hz,
											max_attenuation_cutoff_hz,
											0.05)


func slerp_around(from: Vector3, to: Vector3, around: Vector3, weight: float) -> Vector3:
	var from_vec: Vector3 = from - around
	var to_vec: Vector3 = to - around
	return from_vec.slerp(to_vec, weight) + around
