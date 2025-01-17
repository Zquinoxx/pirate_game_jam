extends Node2D

@onready var level_nodes = get_children()
@onready var grid_width = Globals.map_grid_width
@onready var grid_height = Globals.map_grid_height
@onready var current_level_number = 4
@onready var max_number_of_levels = Globals.rng.randi_range(1, 2) + 5 + current_level_number * 2.6
@onready var min_number_of_levels = max_number_of_levels - 2
@onready var levels_added = 0
@onready var level_cells = []
@onready var level_queue = []
@onready var num_level_nodes = 0
@onready var wall_level_nodes = []
@onready var level_container_node: Node2D

@onready var level_lookup_map = []

func _ready():
	initialize_level_nodes()
	cache_wall_level_nodes()
	create_level_container()
	while levels_added < min_number_of_levels:
		initialize_level_cells()
		initialize_level_lookup_map()
		place_starting_level_into_queue(35)
		loop_over_level_queue()
		if levels_added < min_number_of_levels:
			reset_level_container()
	create_level_floors()
	create_level_walls()
	
func initialize_level_cells():
	level_cells = []
	level_cells.resize(grid_width * grid_height)
	level_cells.fill(false)
	levels_added = 0
	
func initialize_level_lookup_map():
	level_lookup_map = []
	level_lookup_map.resize(grid_width * grid_height)
	level_lookup_map.fill(null)
	
func cache_wall_level_nodes():
	for node in level_nodes:
		if node.name.contains("Wall"):
			wall_level_nodes.append(node)
			# deterministic order is
			# ew, sw, ns, es, nw, ne
			# nsw, new, nes, esw
			
func cell_index_is_out_of_bounds(index: int) -> bool:
	if index < 0: return true
	if index >= (grid_width * grid_height) - 1 : return true
	return false
	
func create_level_container():
	level_container_node = Node2D.new()
	add_child(level_container_node)
	
func reset_level_container():
	level_container_node.queue_free()
	create_level_container()
	
func create_level_floors():
	var count = 0
	for level in level_cells:
		if level:
			if count != 35: #for now don't do start level
				var level_coords = get_level_coords_from_cell(count)
				create_level_at_location("Level_1", level_coords.x, level_coords.y, count)
		count += 1	

func create_level_walls():
	var count = 0
	for level in level_cells:
		if level:				
			var wall_level_suffix = ""
			#north neighbor
			if cell_index_is_out_of_bounds(count - 10) || !level_cells[count - 10]:
				wall_level_suffix = wall_level_suffix + "n"	
			#east neighbor
			if cell_index_is_out_of_bounds(count + 1) || !level_cells[count + 1]:
				wall_level_suffix = wall_level_suffix + "e"
			#south neighbor
			if cell_index_is_out_of_bounds(count + 10) || !level_cells[count + 10]:
				wall_level_suffix = wall_level_suffix + "s"
			#west neighbor
			if cell_index_is_out_of_bounds(count - 1) || !level_cells[count - 1]:
				wall_level_suffix = wall_level_suffix + "w"
				
			var level_coords = get_level_coords_from_cell(count)
			create_level_at_location("Walls_" + wall_level_suffix, level_coords.x, level_coords.y, count)
		count += 1
	
func increase_level_number():
	current_level_number += 1
	max_number_of_levels = Globals.rng.randi_range(1, 2) + 5 + current_level_number * 2.6
	
func initialize_level_nodes():
	num_level_nodes = level_nodes.size()
	for level in level_nodes:
		level.visible = false
	#always initialize level zero
	level_nodes[0].visible = true
	
func place_starting_level_into_queue(cell: int):
	level_cells[cell] = true
	level_lookup_map[cell] = level_nodes[0]
	print("level_nodes[0]: ", level_nodes[0])
	Utils.add_to_queue(level_queue, cell)
	var level_coords = get_level_coords_from_cell(35)
	level_nodes[0].position = Vector2(level_coords.x * Globals.VIEWPORT_WIDTH, level_coords.y * Globals.VIEWPORT_HEIGHT)
	
func loop_over_level_queue():
	while !level_queue.is_empty():
		var level = level_queue[0]
	#for level in level_queue:
		if neighbor_is_good(level + 10, levels_added): levels_added += 1 #north
		if neighbor_is_good(level + 1, levels_added): levels_added += 1 #east
		if neighbor_is_good(level - 10, levels_added): levels_added += 1 #south
		if neighbor_is_good(level - 1, levels_added): levels_added += 1 #west
		Utils.finish_queue_front(level_queue)
		
func cell_index_ends_with_zero(index: int) -> bool:
	if index == 0 || str(index).length() == 2 && str(index)[1] == "0":
		return true
	return false
			
func neighbor_is_good(neighbor: int, levels_added: int) -> bool:
	# if neighbor is out of bounds of map
	if cell_index_is_out_of_bounds(neighbor): return false
	# if neighbor is on the far left size of the map (prevent wrapping)
	if cell_index_ends_with_zero(neighbor): return false
	# if we already have enough rooms
	if levels_added >= floor(max_number_of_levels): return false
	# if neighbor is already occupied
	if level_cells[neighbor] != false: return false
	# if neighbor has more than one filled neighbor
	var number_of_filled_neighbors = 0
	if neighbor + 10 < grid_width * grid_height && level_cells[neighbor + 10] != false: 
			number_of_filled_neighbors += 1
	if neighbor + 1 < grid_width * grid_height && level_cells[neighbor + 1] != false:
			number_of_filled_neighbors += 1
	if neighbor - 10 >= 0 && level_cells[neighbor - 10] != false: 
		number_of_filled_neighbors += 1
	if neighbor - 1 >= 0 && level_cells[neighbor - 1] != false:
		number_of_filled_neighbors += 1
	if number_of_filled_neighbors > 1: return false
	# random 50% chance
	if Globals.rng.randi_range(1, 2) == 1: 
		return false
	level_cells[neighbor] = true
	Utils.add_to_queue(level_queue, neighbor)
	return true
	
func create_level_at_location(level_name: String, x: int, y: int, cell: int):
	var new_level
	var count = 0
	for level in level_nodes:
		if level.name == level_name:
			new_level = level_nodes[count].duplicate()
		count += 1
	if new_level:
		new_level.position = Vector2(x * Globals.VIEWPORT_WIDTH, y * Globals.VIEWPORT_HEIGHT)
		new_level.visible = true
		add_child(new_level)
		if !level_name.contains("Walls_"):
			level_lookup_map[cell] = new_level
	else:
		print(level_name)

func get_level_coords_from_cell(cell: int) -> Vector2:
	if str(cell).length() == 2:
		return Vector2(int(str(cell)[1]), int(str(cell)[0]))
	return Vector2(int(str(cell)[0]), 0)

