extends Node2D
# Snake indie - v2: iconos propios, la comida cambia SOLO al comer, velocidad ajustable

const CELL := 32
const GRID_W := 25
const GRID_H := 18

const BODY_COLOR := Color("478cbf")
const BG_COLOR := Color("1e1e2e")
const FOOD_COLOR := Color("f9e2af")

# Sombra que se dibuja detras de los sprites para que resalten
const SHADOW_COLOR := Color(0, 0, 0, 0.35)
const SHADOW_OFFSET := Vector2(2, 3)

# Respaldo: si no has puesto imagenes todavia, se dibujan estos simbolos como texto
const TEXT_SYMBOLS := ["{", "}", "[", "]", "(", ")", "/", "\\", ";", "<", ">", "=", "!", "&", "|", "#"]

# ---- Arrastra las imagenes de tu equipo aqui desde el Inspector (nodo Main) ----
@export var head_texture: Texture2D
@export var body_texture: Texture2D
@export var food_textures: Array[Texture2D] = []

# Fondos por nivel: casilla 0 = nivel 1, casilla 1 = nivel 2, etc.
@export var level_backgrounds: Array[Texture2D] = []

# Que tanto se oscurece el fondo (0 = nada, 0.8 = muy oscuro) para que los iconos se vean mejor
@export_range(0.0, 0.8, 0.05) var background_dim := 0.25

# ---- Velocidad: segundos por paso (mas alto = mas lento) ----
@export var start_step_time := 0.30
@export var min_step_time := 0.12
@export var speed_up_per_food := 0.005

var fallback_head: Texture2D = preload("res://icon.svg")

var snake: Array[Vector2i] = []
var dir := Vector2i.RIGHT
var next_dir := Vector2i.RIGHT
var food_pos := Vector2i.ZERO
var food_index := -1
var score := 0
var level := 0   # 0 = nivel 1
var game_over := false

var move_timer: Timer


func _ready() -> void:
	randomize()
	# Para que el pixel art se vea nitido y no borroso
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	move_timer = Timer.new()
	move_timer.timeout.connect(_step)
	add_child(move_timer)

	_reset()


func _reset() -> void:
	snake = [Vector2i(5, 9), Vector2i(4, 9), Vector2i(3, 9)]
	dir = Vector2i.RIGHT
	next_dir = Vector2i.RIGHT
	score = 0
	game_over = false
	food_index = -1
	move_timer.wait_time = start_step_time
	move_timer.start()
	_spawn_food()
	queue_redraw()


func _food_variants() -> int:
	return food_textures.size() if food_textures.size() > 0 else TEXT_SYMBOLS.size()


func _spawn_food() -> void:
	# Posicion nueva
	while true:
		food_pos = Vector2i(randi() % GRID_W, randi() % GRID_H)
		if not snake.has(food_pos):
			break
	# Simbolo nuevo (distinto al anterior). Solo cambia aqui, o sea, al comer.
	var total := _food_variants()
	var nuevo := randi() % total
	while total > 1 and nuevo == food_index:
		nuevo = randi() % total
	food_index = nuevo


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				_set_dir(Vector2i.UP)
			KEY_DOWN, KEY_S:
				_set_dir(Vector2i.DOWN)
			KEY_LEFT, KEY_A:
				_set_dir(Vector2i.LEFT)
			KEY_RIGHT, KEY_D:
				_set_dir(Vector2i.RIGHT)
			KEY_ENTER, KEY_SPACE:
				if game_over:
					_reset()


func _set_dir(d: Vector2i) -> void:
	if d != -dir:
		next_dir = d


func _step() -> void:
	if game_over:
		return

	dir = next_dir
	var new_head := snake[0] + dir

	if new_head.x < 0 or new_head.x >= GRID_W or new_head.y < 0 or new_head.y >= GRID_H or snake.has(new_head):
		game_over = true
		move_timer.stop()
		queue_redraw()
		return

	snake.push_front(new_head)

	if new_head == food_pos:
		score += 1
		move_timer.wait_time = max(min_step_time, move_timer.wait_time - speed_up_per_food)
		_spawn_food()
	else:
		snake.pop_back()

	queue_redraw()


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))


func _draw_with_shadow(tex: Texture2D, rect: Rect2) -> void:
	# Primero la sombra (la misma imagen pintada de negro y desplazada), luego la imagen
	draw_texture_rect(tex, Rect2(rect.position + SHADOW_OFFSET, rect.size), false, SHADOW_COLOR)
	draw_texture_rect(tex, rect, false)


func _draw_text_outlined(font: Font, pos: Vector2, text: String, align: HorizontalAlignment, width: float, size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, align, width, size, 5, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, align, width, size, color)


func _draw_background() -> void:
	var area := Vector2(GRID_W * CELL, GRID_H * CELL)

	if level < level_backgrounds.size() and level_backgrounds[level] != null:
		var tex := level_backgrounds[level]
		var tex_size := tex.get_size()
		# Escala la imagen para cubrir toda el area SIN deformarla (recorta lo que sobra)
		var s := maxf(area.x / tex_size.x, area.y / tex_size.y)
		var src_size := area / s
		var src_pos := (tex_size - src_size) / 2.0
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, area), Rect2(src_pos, src_size))
		# Capa oscura encima del fondo para bajar el contraste
		if background_dim > 0.0:
			draw_rect(Rect2(Vector2.ZERO, area), Color(0, 0, 0, background_dim))
	else:
		# Si no hay imagen para este nivel, color liso
		draw_rect(Rect2(Vector2.ZERO, area), BG_COLOR)


func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Fondo
	_draw_background()

	# Comida
	var food_rect := _cell_rect(food_pos)
	# Circulo oscuro detras para que el simbolo resalte sobre cualquier fondo
	draw_circle(food_rect.get_center(), CELL * 0.55, Color(0, 0, 0, 0.4))
	if food_textures.size() > 0:
		var tex := food_textures[food_index]
		if tex:
			_draw_with_shadow(tex, food_rect)
	else:
		_draw_text_outlined(font, Vector2(food_pos.x * CELL, food_pos.y * CELL + CELL * 0.8),
			TEXT_SYMBOLS[food_index], HORIZONTAL_ALIGNMENT_CENTER, CELL, 30, FOOD_COLOR)

	# Cuerpo
	for i in range(1, snake.size()):
		var r := _cell_rect(snake[i])
		if body_texture:
			_draw_with_shadow(body_texture, r)
		else:
			draw_rect(Rect2(r.position + SHADOW_OFFSET, r.size).grow(-3), SHADOW_COLOR)
			draw_rect(r.grow(-3), BODY_COLOR)

	# Cabeza
	var head_tex: Texture2D = head_texture if head_texture else fallback_head
	_draw_with_shadow(head_tex, _cell_rect(snake[0]))

	# Puntaje
	_draw_text_outlined(font, Vector2(8, 22), "Puntos: %d" % score,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

	# Game over
	if game_over:
		_draw_text_outlined(font, Vector2(0, GRID_H * CELL / 2.0), "GAME OVER - Enter para reiniciar",
			HORIZONTAL_ALIGNMENT_CENTER, GRID_W * CELL, 22, Color("f38ba8"))
