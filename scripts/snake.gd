extends Node2D
# Snake indie - v3: movimiento suave a 60 fps, niveles, TNT, sombras

const CELL := 32
const GRID_W := 25
const GRID_H := 18

const BODY_COLOR := Color("478cbf")
const BG_COLOR := Color("1e1e2e")
const FOOD_COLOR := Color("f9e2af")
const SHADOW_COLOR := Color(0, 0, 0, 0.35)
const SHADOW_OFFSET := Vector2(2, 3)

# Respaldo: si no hay imagenes de simbolos, se dibujan estos como texto
const TEXT_SYMBOLS := ["{", "}", "[", "]", "(", ")", "/", "\\", ";", "<", ">", "=", "!", "&", "|", "#"]

# ---- Imagenes: arrastralas desde el Inspector (nodo Main) ----
@export var head_texture: Texture2D
@export var body_texture: Texture2D
@export var food_textures: Array[Texture2D] = []
@export var tnt_texture: Texture2D

# ---- Cuerpo: que tan junto se ve ----
# body_fill = bolitas extra entre cada pedazo (0 = como antes, 1 = el doble de juntas, 2 = casi una cadena)
@export_range(0, 3) var body_fill := 1
# body_scale = tamano de cada bolita (1.0 = normal, 1.3 = 30% mas grande)
@export_range(1.0, 2.0, 0.05) var body_scale := 1.0

# Fondos por nivel: casilla 0 = nivel 1, casilla 1 = nivel 2, etc.
# Si el juego llega a un nivel sin fondo, se queda con el ultimo que tengas.
@export var level_backgrounds: Array[Texture2D] = []
@export_range(0.0, 0.8, 0.05) var background_dim := 0.25

# ---- Velocidad: segundos por paso (mas alto = mas lento) ----
@export var start_step_time := 0.30
@export var min_step_time := 0.12
@export var speed_up_per_food := 0.005

# ---- Niveles y dificultad ----
@export_range(1, 100) var points_per_level := 10   # puntos para pasar de nivel
@export var tnt_per_level := 4                     # TNT = (nivel - 1) x este numero
@export var max_tnt := 25

var fallback_head: Texture2D = preload("res://icon.svg")

var snake: Array[Vector2i] = []
var prev_snake: Array[Vector2i] = []   # donde estaba cada pedazo antes del ultimo paso
var obstacles: Array[Vector2i] = []    # posiciones de los TNT
var dir := Vector2i.RIGHT
var next_dir := Vector2i.RIGHT

var food_pos := Vector2i.ZERO
var food_index := -1
var ghost_pos := Vector2i.ZERO         # la comida recien comida (se ve hasta que la cabeza llega)
var ghost_index := -1
var ghost_active := false

var score := 0
var level := 0                         # 0 = nivel 1
var game_over := false
var paused := false                    # pausa corta al subir de nivel
var banner_time := 0.0

var step_time := 0.3
var step_clock := 0.0                  # avance dentro del paso actual (para animar suave)


func _ready() -> void:
	randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art nitido
	_reset()


func _reset() -> void:
	snake = [Vector2i(5, 9), Vector2i(4, 9), Vector2i(3, 9)]
	prev_snake.assign(snake)
	obstacles.clear()
	dir = Vector2i.RIGHT
	next_dir = Vector2i.RIGHT
	score = 0
	level = 0
	game_over = false
	paused = false
	ghost_active = false
	banner_time = 0.0
	step_time = start_step_time
	step_clock = 0.0
	food_index = -1
	_spawn_food()


func _food_variants() -> int:
	return food_textures.size() if food_textures.size() > 0 else TEXT_SYMBOLS.size()


func _spawn_food() -> void:
	while true:
		food_pos = Vector2i(randi() % GRID_W, randi() % GRID_H)
		if not snake.has(food_pos) and not obstacles.has(food_pos):
			break
	# Simbolo nuevo (distinto al anterior). Solo cambia al comer.
	var total := _food_variants()
	var nuevo := randi() % total
	while total > 1 and nuevo == food_index:
		nuevo = randi() % total
	food_index = nuevo


func _spawn_obstacles() -> void:
	obstacles.clear()
	var count := mini(level * tnt_per_level, max_tnt)
	var head := snake[0]
	var tries := 0
	while obstacles.size() < count and tries < 500:
		tries += 1
		var c := Vector2i(randi() % GRID_W, randi() % GRID_H)
		# Lejos de la cabeza para que no sea injusto
		if absi(c.x - head.x) + absi(c.y - head.y) < 6:
			continue
		if snake.has(c) or obstacles.has(c):
			continue
		obstacles.append(c)


func _level_up() -> void:
	level += 1
	_spawn_obstacles()
	banner_time = 1.5
	paused = true
	await get_tree().create_timer(1.2).timeout
	paused = false


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


func _process(delta: float) -> void:
	if banner_time > 0.0:
		banner_time -= delta

	if not game_over:
		step_clock += delta
		if step_clock >= step_time:
			if paused:
				step_clock = step_time          # se queda quieta al final del paso
			else:
				step_clock -= step_time
				_step()

	queue_redraw()   # redibuja en cada frame = movimiento fluido


func _step() -> void:
	ghost_active = false
	dir = next_dir
	var new_head := snake[0] + dir

	# Choque con paredes, cuerpo o TNT
	if new_head.x < 0 or new_head.x >= GRID_W or new_head.y < 0 or new_head.y >= GRID_H \
			or snake.has(new_head) or obstacles.has(new_head):
		game_over = true
		step_clock = step_time
		return

	prev_snake.assign(snake)
	snake.push_front(new_head)

	if new_head == food_pos:
		ghost_pos = food_pos
		ghost_index = food_index
		ghost_active = true
		score += 1
		step_time = maxf(min_step_time, step_time - speed_up_per_food)
		if score % points_per_level == 0:
			_level_up()
		_spawn_food()
	else:
		snake.pop_back()


# ------------------------------------------------------------------ dibujo

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))


# Posicion en pantalla del pedazo i, mezclando entre donde estaba y donde esta (t de 0 a 1)
func _seg_pixel(i: int, t: float) -> Vector2:
	var cur := Vector2(snake[i])
	var prev := Vector2(prev_snake[i]) if i < prev_snake.size() else cur
	return prev.lerp(cur, t) * CELL


# Rectangulo de una bolita del cuerpo, agrandada desde su centro segun body_scale
func _body_rect(pos: Vector2) -> Rect2:
	var size := Vector2(CELL, CELL) * body_scale
	return Rect2(pos - (size - Vector2(CELL, CELL)) / 2.0, size)


func _draw_with_shadow(tex: Texture2D, rect: Rect2) -> void:
	draw_texture_rect(tex, Rect2(rect.position + SHADOW_OFFSET, rect.size), false, SHADOW_COLOR)
	draw_texture_rect(tex, rect, false)


func _draw_text_outlined(font: Font, pos: Vector2, text: String, align: HorizontalAlignment, width: float, size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, align, width, size, 5, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, align, width, size, color)


func _draw_background() -> void:
	var area := Vector2(GRID_W * CELL, GRID_H * CELL)
	var idx := mini(level, level_backgrounds.size() - 1)

	if idx >= 0 and level_backgrounds[idx] != null:
		var tex := level_backgrounds[idx]
		var tex_size := tex.get_size()
		# Cubre toda el area SIN deformar la imagen (recorta lo que sobra)
		var s := maxf(area.x / tex_size.x, area.y / tex_size.y)
		var src_size := area / s
		var src_pos := (tex_size - src_size) / 2.0
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, area), Rect2(src_pos, src_size))
		if background_dim > 0.0:
			draw_rect(Rect2(Vector2.ZERO, area), Color(0, 0, 0, background_dim))
	else:
		draw_rect(Rect2(Vector2.ZERO, area), BG_COLOR)


func _draw_food(pos: Vector2i, index: int) -> void:
	var rect := _cell_rect(pos)
	# Circulo oscuro detras para que el simbolo resalte
	draw_circle(rect.get_center(), CELL * 0.55, Color(0, 0, 0, 0.4))
	if food_textures.size() > 0:
		if index >= 0 and index < food_textures.size() and food_textures[index] != null:
			_draw_with_shadow(food_textures[index], rect)
	elif index >= 0 and index < TEXT_SYMBOLS.size():
		_draw_text_outlined(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y + CELL * 0.8),
			TEXT_SYMBOLS[index], HORIZONTAL_ALIGNMENT_CENTER, CELL, 30, FOOD_COLOR)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var t := clampf(step_clock / step_time, 0.0, 1.0)

	_draw_background()

	# TNT
	for o in obstacles:
		var r := _cell_rect(o)
		if tnt_texture:
			_draw_with_shadow(tnt_texture, r)
		else:
			# Respaldo hasta que tengan el sprite del TNT
			draw_rect(Rect2(r.position + SHADOW_OFFSET, r.size).grow(-2), SHADOW_COLOR)
			draw_rect(r.grow(-2), Color("c0392b"))
			_draw_text_outlined(font, Vector2(r.position.x, r.position.y + CELL * 0.68),
				"TNT", HORIZONTAL_ALIGNMENT_CENTER, CELL, 14, Color.WHITE)

	# Comida (y la que acaba de comerse, hasta que la cabeza llegue)
	if ghost_active and t < 0.85:
		_draw_food(ghost_pos, ghost_index)
	_draw_food(food_pos, food_index)

	# Cuerpo (de la cola hacia la cabeza)
	for i in range(snake.size() - 1, 0, -1):
		var pos := _seg_pixel(i, t)
		if body_texture:
			_draw_with_shadow(body_texture, _body_rect(pos))
			# Bolitas extra entre este pedazo y el que tiene delante
			var ahead := _seg_pixel(i - 1, t)
			for j in range(1, body_fill + 1):
				var p := pos.lerp(ahead, float(j) / float(body_fill + 1))
				_draw_with_shadow(body_texture, _body_rect(p))
		else:
			var r := Rect2(pos, Vector2(CELL, CELL))
			draw_rect(Rect2(r.position + SHADOW_OFFSET, r.size).grow(-3), SHADOW_COLOR)
			draw_rect(r.grow(-3), BODY_COLOR)

	# Cabeza
	var head_tex: Texture2D = head_texture if head_texture else fallback_head
	_draw_with_shadow(head_tex, Rect2(_seg_pixel(0, t), Vector2(CELL, CELL)))

	# Puntaje y nivel
	_draw_text_outlined(font, Vector2(8, 22), "Puntos: %d" % score,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	_draw_text_outlined(font, Vector2(0, 22), "Nivel: %d" % (level + 1),
		HORIZONTAL_ALIGNMENT_RIGHT, GRID_W * CELL - 8, 20, Color.WHITE)

	# Cartel de nivel nuevo
	if banner_time > 0.0:
		_draw_text_outlined(font, Vector2(0, GRID_H * CELL / 2.0 - 30), "¡NIVEL %d!" % (level + 1),
			HORIZONTAL_ALIGNMENT_CENTER, GRID_W * CELL, 56, FOOD_COLOR)

	# Game over
	if game_over:
		_draw_text_outlined(font, Vector2(0, GRID_H * CELL / 2.0), "GAME OVER - Enter para reiniciar",
			HORIZONTAL_ALIGNMENT_CENTER, GRID_W * CELL, 28, Color("f38ba8"))
