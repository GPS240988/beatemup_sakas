class_name MapArrowRenderer
extends Node2D

## Renderizador vetorial da seta arcade de navegação no mapa.
## Desenha um triângulo nítido voltado para baixo com preenchimento branco puro
## e borda escura destacada, preservando fidelidade com a arte de Mapa.webp.

@export var arrow_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var border_color: Color = Color(0.10, 0.10, 0.14, 1.0)
@export var arrow_scale: Vector2 = Vector2(1.0, 1.0)

const POLYGON_POINTS: PackedVector2Array = [
	Vector2(-13.0, -12.0),
	Vector2(13.0, -12.0),
	Vector2(0.0, 12.0)
]

const OUTLINE_POINTS: PackedVector2Array = [
	Vector2(-13.0, -12.0),
	Vector2(13.0, -12.0),
	Vector2(0.0, 12.0),
	Vector2(-13.0, -12.0)
]


func _draw() -> void:
	# Sombra suave projetada
	var shadow_poly := PackedVector2Array()
	for pt in POLYGON_POINTS:
		shadow_poly.append(pt + Vector2(0.0, 2.0))
	draw_colored_polygon(shadow_poly, Color(0.0, 0.0, 0.0, 0.35))

	# Preenchimento branco
	draw_colored_polygon(POLYGON_POINTS, arrow_color)

	# Borda escura nítida arcade
	draw_polyline(OUTLINE_POINTS, border_color, 2.0, true)

