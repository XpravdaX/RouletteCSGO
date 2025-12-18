extends Control

@export var rarities: Array[String] = ["Обычный", "Яркий", "Легендарный"]
@export var rarity_colors: Array[Color] = [
	Color("#8E8E8E"),
	Color("#4CAF50"),
	Color("#FFD700")
]
@export var rarity_probabilities: Array[float] = [70, 25, 5]

@export var item_names: Array[String] = []
@export var textures: Array[Texture2D] = []
@export var texture_rarities: Array[int] = []
@export var spin_duration: float = 10.0
@export var spin_slowdown_time: float = 5.0
@export var item_width: int = 145

@export var scroll_container: ScrollContainer
@export var item_container: BoxContainer
@export var contro: Control
@export var panelWin: Panel
@export var textureWin: TextureRect
@export var rarityLabel: Label
@export var rarityPanel: Panel
@export var timer: Timer

@export var case_manager: NodePath
var case_manager_node: Node

var spinning = false
var spin_speed = 0.0
var target_item_index = 0
var current_scroll = 0
var items_pool = []
var visible_items = []
var won_item_texture: Texture2D
var won_item_rarity: int = 0

const VISIBLE_ITEMS_COUNT = 10

func _ready():
	case_manager_node = get_node(case_manager) if case_manager else get_node("/root/CaseManager")
	
	assert(textures.size() == texture_rarities.size(), "Количество текстур и редкостей должно совпадать")
	assert(abs(rarity_probabilities.reduce(func(a, b): return a + b) - 100.0) < 0.01, "Сумма вероятностей должна быть 100%")
	
	scroll_container.get_h_scroll_bar().scale.x = 0
	scroll_container.get_v_scroll_bar().scale.x = 0
	scroll_container.get_h_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_container.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	initialize_items_pool()
	for i in range(VISIBLE_ITEMS_COUNT):
		add_item_to_end()
	
	panelWin.visible = false

func initialize_items_pool():
	for i in textures.size():
		var texture_rect = TextureRect.new()
		texture_rect.texture = textures[i]
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.custom_minimum_size = Vector2(item_width, 200)
		
		var rarity_idx = texture_rarities[i] if i < texture_rarities.size() else 0
		rarity_idx = clampi(rarity_idx, 0, rarity_colors.size() - 1)
		
		var panel = Panel.new()
		panel.size = Vector2(item_width, 15)
		panel.position = Vector2(0, 185)
		panel.self_modulate = rarity_colors[rarity_idx]
		
		var style = StyleBoxFlat.new()
		style.bg_color = rarity_colors[rarity_idx]
		style.bg_color.a = 0.8
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		panel.add_theme_stylebox_override("panel", style)
		
		texture_rect.add_child(panel)
		
		items_pool.append({
			"texture_rect": texture_rect,
			"rarity": rarity_idx
		})

func add_item_to_end():
	if items_pool.is_empty():
		return
	
	var random_index = get_random_item_index()
	var item_data = items_pool[random_index]
	var item = item_data["texture_rect"].duplicate()
	
	item_container.add_child(item)
	visible_items.append({
		"node": item,
		"rarity": item_data["rarity"]
	})

func get_random_item_index() -> int:
	var rand = randf_range(0.0, 100.0)
	var cumulative = 0.0
	for i in rarity_probabilities.size():
		cumulative += rarity_probabilities[i]
		if rand <= cumulative:
			var available_textures = []
			for j in textures.size():
				if texture_rarities[j] == i:
					available_textures.append(j)
			
			if available_textures.size() > 0:
				return available_textures[randi() % available_textures.size()]
	
	return 0

func remove_item_from_start():
	if not visible_items.is_empty():
		visible_items.pop_front()["node"].queue_free()

func _on_open_case_pressed():
	# Проверяем, можно ли открыть кейс
	if case_manager_node and case_manager_node.can_open_case():
		case_manager_node.open_case(self)
		contro.visible = true
		if not spinning:
			start_spin()
	else:
		print("Другой кейс уже открыт")

func start_spin():
	spinning = true
	spin_speed = 2000.0
	target_item_index = get_random_item_index()
	
	var target_pos = target_item_index * item_width + item_width * textures.size() * 5
	current_scroll = target_pos
	
	panelWin.visible = false
	
	timer.start(spin_duration)

func _process(delta):
	if spinning:
		var slowdown = 1.0
		if timer.time_left < spin_slowdown_time:
			slowdown = timer.time_left / spin_slowdown_time
		
		scroll_container.scroll_horizontal += spin_speed * delta * slowdown
		
		if not visible_items.is_empty() and scroll_container.scroll_horizontal > visible_items[0]["node"].position.x + item_width:
			remove_item_from_start()
			add_item_to_end()
			for item in visible_items:
				item["node"].position.x -= item_width
			scroll_container.scroll_horizontal -= item_width
			current_scroll -= item_width

func _on_timer_timeout():
	spinning = false
	var center_pos = scroll_container.scroll_horizontal + scroll_container.size.x / 2
	var closest_item = null
	var min_distance = INF
	
	for item in visible_items:
		var item_pos = item["node"].position.x + item_width / 2
		var distance = abs(item_pos - center_pos)
		if distance < min_distance:
			min_distance = distance
			closest_item = item
	
	if closest_item:
		won_item_texture = closest_item["node"].texture
		won_item_rarity = closest_item["rarity"]
		print("Вы выиграли: ", won_item_texture.resource_path, " (", rarities[won_item_rarity], ")")
		
		show_win_panel()

func show_win_panel():
	textureWin.texture = won_item_texture
	textureWin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	textureWin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var correct_index = textures.find(won_item_texture)
	if correct_index == -1:
		correct_index = 0
	
	var item_name = item_names[correct_index] if correct_index < item_names.size() else "Неизвестная наклейка"
	
	rarityLabel.text = "%s (%s)" % [item_name, rarities[won_item_rarity]]
	rarityPanel.self_modulate = rarity_colors[won_item_rarity]
	
	panelWin.visible = true

func _on_button_prinat_pressed():
	contro.visible = false
	var tween = create_tween()
	tween.tween_property(panelWin, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): 
		panelWin.visible = false
		panelWin.modulate.a = 1.0
		
		for item in visible_items:
			item["node"].queue_free()
		visible_items.clear()
		
		initialize_items_pool()
		for i in range(VISIBLE_ITEMS_COUNT):
			add_item_to_end()
			
		scroll_container.scroll_horizontal = 0
		current_scroll = 0
		
		if case_manager_node:
			case_manager_node.close_case()
	)
