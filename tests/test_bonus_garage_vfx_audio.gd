extends SceneTree

const OrangeCarScene: PackedScene = preload("res://scenes/props/bonus_car_orange.tscn")
const BlueCarScene: PackedScene = preload("res://scenes/props/bonus_car_blue.tscn")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const ImpactZonesClass = preload("res://scripts/combat/impact_zones.gd")

var passed_count: int = 0
var failed_count: int = 0


func _init() -> void:
	print("\n==================================================")
	print("INICIANDO SUITE DE TESTES: IMPACTOS, ÁUDIO E FUMAÇA")
	print("==================================================")

	test_impact_positioning()
	test_audio_and_particles_components()
	test_destruction_sequence_and_smoke()
	test_wreck_inertness_and_independence()

	print("\n==================================================")
	print("RESULTADO FINAL: %d PASSARAM (Falhas: %d)" % [passed_count, failed_count])
	print("==================================================")

	if failed_count > 0:
		quit(1)
	else:
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("  [OK] %s" % message)
	else:
		failed_count += 1
		printerr("  [FAIL] %s" % message)


func test_impact_positioning() -> void:
	print("\n--- 1. Testando Mapeamento Anatômico e Posição do Impacto ---")
	var orange_car: DestructibleProp = OrangeCarScene.instantiate() as DestructibleProp
	var blue_car: DestructibleProp = BlueCarScene.instantiate() as DestructibleProp

	root.add_child(orange_car)
	root.add_child(blue_car)
	orange_car.global_position = Vector2(500, 650)
	blue_car.global_position = Vector2(1150, 670)

	# A. Carro Laranja: Soco na Frente
	# Atacante vem da direita, facing = -1
	var front_hitbox := Vector2(740, 570)
	var orange_front_pos: Vector2 = orange_car.get_impact_point(front_hitbox, -1.0)
	_assert(orange_front_pos.x >= 650.0 and orange_front_pos.x <= 760.0,
		"Carro Laranja: Impacto frontal mapeado na região da frente (X=%.1f)" % orange_front_pos.x)
	_assert(orange_front_pos.y >= 490.0 and orange_front_pos.y <= 650.0,
		"Carro Laranja: Impacto frontal dentro da altura útil da carroceria (Y=%.1f)" % orange_front_pos.y)

	# B. Carro Laranja: Soco na Traseira
	# Atacante vem da esquerda, facing = +1
	var rear_hitbox := Vector2(260, 570)
	var orange_rear_pos: Vector2 = orange_car.get_impact_point(rear_hitbox, 1.0)
	_assert(orange_rear_pos.x >= 240.0 and orange_rear_pos.x <= 340.0,
		"Carro Laranja: Impacto traseiro mapeado na região da traseira (X=%.1f)" % orange_rear_pos.x)

	# C. Carro Laranja: Golpe na Lateral/Portas (Centro X, abaixo em Y)
	var flank_hitbox := Vector2(500, 680)
	var orange_flank_pos: Vector2 = orange_car.get_impact_point(flank_hitbox, 1.0)
	_assert(absf(orange_flank_pos.x - 500.0) < 50.0,
		"Carro Laranja: Impacto lateral preserva alinhamento horizontal (X=%.1f)" % orange_flank_pos.x)
	_assert(orange_flank_pos.y >= 560.0 and orange_flank_pos.y <= 650.0,
		"Carro Laranja: Impacto lateral na altura da porta/saia (Y=%.1f)" % orange_flank_pos.y)

	# D. Carro Azul: Soco na Frente
	var blue_front_hitbox := Vector2(1400, 590)
	var blue_front_pos: Vector2 = blue_car.get_impact_point(blue_front_hitbox, -1.0)
	_assert(blue_front_pos.x >= 1310.0 and blue_front_pos.x <= 1420.0,
		"Carro Azul: Impacto frontal mapeado na região da frente (X=%.1f)" % blue_front_pos.x)

	# E. Carro Azul: Soco na Traseira
	var blue_rear_hitbox := Vector2(900, 590)
	var blue_rear_pos: Vector2 = blue_car.get_impact_point(blue_rear_hitbox, 1.0)
	_assert(blue_rear_pos.x >= 880.0 and blue_rear_pos.x <= 980.0,
		"Carro Azul: Impacto traseiro mapeado na região da traseira (X=%.1f)" % blue_rear_pos.x)

	# F. Resolução via ImpactZonesClass universal
	var res: Dictionary = ImpactZonesClass.resolve_impact_on_target(orange_car, front_hitbox, Vector2(60, 60), [], -1.0, "punch")
	_assert(res.has("position") and absf(res["position"].x - orange_front_pos.x) < 5.0,
		"ImpactZonesClass resolve impacto através de get_impact_point no prop")

	orange_car.queue_free()
	blue_car.queue_free()


func test_audio_and_particles_components() -> void:
	print("\n--- 2. Testando Componentes de Áudio e Partículas ---")
	var car: DestructibleProp = OrangeCarScene.instantiate() as DestructibleProp
	root.add_child(car)

	var effects: Node2D = car.get_node_or_null("Effects") as Node2D
	_assert(effects != null, "Nó Effects presente na hierarquia do veículo")

	var impact_particles: CPUParticles2D = effects.get_node_or_null("ImpactParticles") as CPUParticles2D
	_assert(impact_particles != null, "ImpactParticles (CPUParticles2D) presente em Effects")

	var break_particles: CPUParticles2D = effects.get_node_or_null("BreakParticles") as CPUParticles2D
	_assert(break_particles != null, "BreakParticles (CPUParticles2D) presente em Effects")

	var smoke_particles: CPUParticles2D = effects.get_node_or_null("SmokeParticles") as CPUParticles2D
	_assert(smoke_particles != null, "SmokeParticles (CPUParticles2D) presente em Effects")
	_assert(smoke_particles.texture != null, "SmokeParticles utiliza textura procedural GradientTexture2D")
	_assert(smoke_particles.gravity.y < 0.0, "SmokeParticles configurada com subida gradual (gravity.y = %.1f < 0)" % smoke_particles.gravity.y)
	_assert(smoke_particles.emitting == false, "SmokeParticles inicia inativa durante gameplay normal")

	var impact_sound: AudioStreamPlayer2D = effects.get_node_or_null("ImpactSound") as AudioStreamPlayer2D
	_assert(impact_sound != null, "AudioStreamPlayer2D ImpactSound configurado em Effects")
	_assert(impact_sound.bus == &"Master" or impact_sound.bus == &"SFX", "ImpactSound roteado para barramento de áudio válido")

	var break_sound: AudioStreamPlayer2D = effects.get_node_or_null("BreakSound") as AudioStreamPlayer2D
	_assert(break_sound != null, "AudioStreamPlayer2D BreakSound configurado em Effects")

	# Testando aplicação de dano e movimentação das partículas de impacto
	var hit_pos := car.global_position + Vector2(180, -80)
	var dmg := DamageInfoClass.new(50.0, null, hit_pos, Vector2.LEFT, "melee", 0.0, 0.0, true, false, 0.05, "punch", "body", hit_pos)
	var accepted: bool = car.take_damage(dmg)
	_assert(accepted, "Golpe aceito e dano computado com sucesso")
	_assert(impact_particles.emitting == true, "ImpactParticles disparado no momento do golpe")
	_assert(impact_particles.position.distance_to(effects.to_local(hit_pos)) < 15.0,
		"ImpactParticles posicionado exatamente na região atingida (dist=%.2f)" % impact_particles.position.distance_to(effects.to_local(hit_pos)))

	car.queue_free()


func test_destruction_sequence_and_smoke() -> void:
	print("\n--- 3. Testando Sequência de Destruição e Fumaça ---")
	var car: DestructibleProp = OrangeCarScene.instantiate() as DestructibleProp
	root.add_child(car)

	var effects: Node2D = car.get_node_or_null("Effects") as Node2D
	var smoke: CPUParticles2D = effects.get_node_or_null("SmokeParticles") as CPUParticles2D
	var sprite: Sprite2D = car.get_node_or_null("Visual/Sprite2D") as Sprite2D

	var initial_texture = sprite.texture
	var destroyed_box: Array[bool] = [false]
	car.prop_destroyed.connect(func(): destroyed_box[0] = true)

	# Causa dano letal total
	var lethal_dmg := DamageInfoClass.new(car.max_health + 100.0, null, car.global_position, Vector2.RIGHT)
	car.take_damage(lethal_dmg)

	_assert(car.is_prop_destroyed(), "Veículo entra em estado DESTROYED")
	_assert(car.current_health == 0.0, "Vida do veículo chega exatamente a 0")
	_assert(destroyed_box[0], "Sinal prop_destroyed emitido com sucesso")
	_assert(smoke.emitting == true, "Fumaça procedural (SmokeParticles) iniciada na destruição")
	_assert(sprite.texture != initial_texture, "Sprite atualizado para estágio final de carcaça destruída")
	_assert(car.get_parent() != null, "Carcaça permanece visível no cenário (não é removida)")

	var col_shape: CollisionShape2D = car.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_assert(col_shape.disabled == true, "Colisão física desativada para liberar passagem de pedestres")

	car.queue_free()


func test_wreck_inertness_and_independence() -> void:
	print("\n--- 4. Testando Inércia da Carcaça e Independência dos Dois Carros ---")
	var car1: DestructibleProp = OrangeCarScene.instantiate() as DestructibleProp
	var car2: DestructibleProp = BlueCarScene.instantiate() as DestructibleProp

	root.add_child(car1)
	root.add_child(car2)

	# Destrói carro 1
	car1.destroy_prop()
	_assert(car1.is_prop_destroyed(), "Carro 1 destruído")

	# Tentativa de golpear a carcaça destruída
	var extra_hit := DamageInfoClass.new(50.0, null, car1.global_position, Vector2.RIGHT)
	var rejected: bool = not car1.take_damage(extra_hit)
	_assert(rejected, "Carcaça destruída recusa novos golpes e não reprocessa dano")

	# Carro 2 deve continuar 100% ativo e funcional
	_assert(car2.is_active(), "Carro 2 permanece 100% ativo e íntegro")
	var hit_car2 := DamageInfoClass.new(50.0, null, car2.global_position, Vector2.RIGHT)
	var car2_accepted: bool = car2.take_damage(hit_car2)
	_assert(car2_accepted, "Carro 2 recebe dano normalmente")
	_assert(car2.current_health == car2.max_health - 50.0, "Vida do Carro 2 reduzida corretamente (%.1f)" % car2.current_health)

	car1.queue_free()
	car2.queue_free()

