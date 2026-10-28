extends SceneTree

## Suíte Automatizada de Validação do Sistema Anatômico de Impacto (Projeto Sakas)
## Valida rigorosamente os 16 cenários anatômicos de combate conforme Seção 9 de GAME_RULES.md.

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const BasicEnemyScene: PackedScene = preload("res://scenes/actors/enemies/basic_enemy.tscn")
const BossAlessandroScene: PackedScene = preload("res://scenes/actors/enemies/boss_alessandro.tscn")
const AttackDataClass = preload("res://scripts/combat/attack_data.gd")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const ImpactZonesClass = preload("res://scripts/combat/impact_zones.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	print("\n==================================================")
	print("INICIANDO SUITE DE TESTES: SISTEMA ANATÔMICO DE IMPACTO")
	print("==================================================")
	call_deferred("_run_suite")


func assert_test(cond: bool, msg: String) -> void:
	total_tests += 1
	if cond:
		passed_tests += 1
		print("  [OK] %s" % msg)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % msg)


func _run_suite() -> void:
	# -------------------------------------------------------------
	# 11. Validação de Integridade do Jogador de Magic
	# -------------------------------------------------------------
	print("\n--- 11. Validando Preservação Absoluta do Jogador de Magic ---")
	var magic_enemy := BasicEnemyScene.instantiate() as EnemyAI
	root.add_child(magic_enemy)
	magic_enemy.global_position = Vector2(500, 300)

	var m_sprite: AnimatedSprite2D = magic_enemy.get_node_or_null("Visual/AnimatedSprite2D")
	assert_test(m_sprite != null, "AnimatedSprite2D presente no Jogador de Magic")
	assert_test(is_equal_approx(m_sprite.scale.x, 0.42) and is_equal_approx(m_sprite.scale.y, 0.42), "Escala do sprite estritamente preservada em 0.42 (sem normalização 220x300)")
	assert_test(is_equal_approx(m_sprite.position.y, -96.0), "Posição vertical do sprite preservada em Y = -96.0")

	var m_iz = magic_enemy.get_node_or_null("ImpactZones")
	assert_test(m_iz != null, "Nó ImpactZones presente no Jogador de Magic")
	assert_test(m_iz.profile == ImpactZonesClass.TargetProfile.JOGADOR_DE_MAGIC, "Perfil detectado/configurado como JOGADOR_DE_MAGIC")
	assert_test(m_iz.head_top_y == -170.0 and m_iz.head_bottom_y == -125.0, "Faixa da cabeça calibrada para Magic: [-170, -125]")
	assert_test(m_iz.upper_torso_top_y == -125.0 and m_iz.upper_torso_bottom_y == -85.0, "Faixa do tórax superior calibrada para Magic: [-125, -85]")
	assert_test(m_iz.lower_torso_top_y == -85.0 and m_iz.lower_torso_bottom_y == -45.0, "Faixa do tronco inferior calibrada para Magic: [-85, -45]")
	assert_test(m_iz.legs_top_y == -45.0 and m_iz.legs_bottom_y == 0.0, "Faixa das pernas calibrada para Magic: [-45, 0]")

	# -------------------------------------------------------------
	# 1. Jab atingindo a cabeça
	# -------------------------------------------------------------
	print("\n--- 1. Jab Atingindo a Cabeça ---")
	var jab_hitbox_pos := magic_enemy.global_position + Vector2(-40.0, -145.0) # Alinhado à cabeça
	var jab_res: Dictionary = m_iz.resolve_impact(jab_hitbox_pos, Vector2(60.0, 50.0), ["head", "upper_torso"], 1.0, "punch")
	assert_test(jab_res.region == "head", "Jab direcionado à cabeça identifica região 'head'")
	assert_test(jab_res.position.y <= magic_enemy.global_position.y - 125.0, "Coordenada Y do impacto está no nível da cabeça (Y <= -125)")

	# -------------------------------------------------------------
	# 2. Jab atingindo o tórax (sem ser forçado para a cabeça)
	# -------------------------------------------------------------
	print("\n--- 2. Jab Atingindo o Tórax ---")
	var chest_hitbox_pos := magic_enemy.global_position + Vector2(-40.0, -100.0) # Alinhado ao tórax
	var chest_res: Dictionary = m_iz.resolve_impact(chest_hitbox_pos, Vector2(60.0, 40.0), ["head", "upper_torso"], 1.0, "punch")
	assert_test(chest_res.region == "upper_torso", "Jab direcionado ao tórax identifica região 'upper_torso' sem ser forçado para cabeça")
	assert_test(chest_res.position.y > magic_enemy.global_position.y - 125.0 and chest_res.position.y <= magic_enemy.global_position.y - 85.0, "Coordenada Y do impacto está no nível do tórax superior [-125, -85]")

	# -------------------------------------------------------------
	# 3. Cross atingindo a cabeça ou tórax superior
	# -------------------------------------------------------------
	print("\n--- 3. Cross Atingindo Região Confirmada ---")
	var cross_res: Dictionary = m_iz.resolve_impact(magic_enemy.global_position + Vector2(-40.0, -110.0), Vector2(70.0, 50.0), ["upper_torso", "head"], 1.0, "punch")
	assert_test(cross_res.region == "upper_torso", "Cross identifica 'upper_torso' com contato no peito")
	var cross_high: Dictionary = m_iz.resolve_impact(magic_enemy.global_position + Vector2(-40.0, -150.0), Vector2(70.0, 40.0), ["upper_torso", "head"], 1.0, "punch")
	assert_test(cross_high.region == "head", "Cross alto identifica 'head' conforme geometria real")

	# -------------------------------------------------------------
	# 4. Kick atingindo a cintura / tronco inferior
	# -------------------------------------------------------------
	print("\n--- 4. Kick Atingindo Cintura / Tronco Inferior ---")
	var kick_hitbox_pos := magic_enemy.global_position + Vector2(-40.0, -68.0) # Alinhado à cintura
	var kick_res: Dictionary = m_iz.resolve_impact(kick_hitbox_pos, Vector2(70.0, 45.0), ["lower_torso"], 1.0, "kick")
	assert_test(kick_res.region == "lower_torso", "Kick identifica região 'lower_torso'")
	assert_test(absf(kick_res.position.y - (magic_enemy.global_position.y - 68.0)) < 15.0, "Efeito do kick NÃO aparece no meio do tórax (-85/-100), mas sim na cintura")

	# Golpe baixo nas pernas
	var leg_hitbox_pos := magic_enemy.global_position + Vector2(-40.0, -20.0)
	var leg_res: Dictionary = m_iz.resolve_impact(leg_hitbox_pos, Vector2(70.0, 30.0), [], 1.0, "kick")
	assert_test(leg_res.region == "legs", "Golpe rasteiro/baixo identifica região 'legs'")

	# -------------------------------------------------------------
	# 5. Finisher conserva feedback de golpe pesado e posição anatômica
	# -------------------------------------------------------------
	print("\n--- 5. Finisher com Feedback Pesado ---")
	var fin_res: Dictionary = m_iz.resolve_impact(magic_enemy.global_position + Vector2(-40.0, -120.0), Vector2(80.0, 60.0), ["upper_torso", "head"], 1.0, "finisher")
	assert_test(fin_res.region in ["upper_torso", "head"], "Finisher conecta em região superior (upper_torso/head)")

	# -------------------------------------------------------------
	# 6. Ataque Especial de Área
	# -------------------------------------------------------------
	print("\n--- 6. Ataque Especial e Resolução Anatômica ---")
	var spec_res: Dictionary = ImpactZonesClass.resolve_impact_on_target(magic_enemy, magic_enemy.global_position + Vector2(0, -110), Vector2(100, 100), ["upper_torso", "head"], 1.0, "special")
	assert_test(spec_res.region in ["upper_torso", "head"], "Especial resolve região anatômica no alvo")
	assert_test(spec_res.position.y < magic_enemy.global_position.y - 80.0, "Especial posiciona faísca azul na região anatômica do alvo")

	# -------------------------------------------------------------
	# 7. Whiff / Golpe que Erra
	# -------------------------------------------------------------
	print("\n--- 7. Isolamento de Whiff ---")
	var player := PlayerScene.instantiate() as PlayerController
	root.add_child(player)
	player.global_position = Vector2(100, 300)

	var initial_sparks: int = 0
	for child in player.get_children():
		if "AnimatedHitSpark" in child.name or "ImpactSpark" in child.name:
			initial_sparks += 1

	# Executa soco no ar longe de qualquer inimigo
	var whiff_hit := player.melee_attack.execute_attack(1.0)
	assert_test(whiff_hit, "Ataque no ar disparado")
	var sparks_after_whiff: int = 0
	for child in player.get_children():
		if "AnimatedHitSpark" in child.name or "ImpactSpark" in child.name:
			sparks_after_whiff += 1
	assert_test(sparks_after_whiff == initial_sparks, "Golpe sem alvo NÃO instancia faíscas nem partículas (Whiff isolado)")

	# -------------------------------------------------------------
	# 8. Ataque que intersecta mais de uma região: aplica dano uma única vez
	# -------------------------------------------------------------
	print("\n--- 8. Dano Único sob Múltiplas Regiões ---")
	var target_test_enemy := BasicEnemyScene.instantiate() as EnemyAI
	root.add_child(target_test_enemy)
	target_test_enemy.global_position = Vector2(150, 300) # À frente do player

	var initial_health: float = target_test_enemy.health_component.current_health

	# Cancela ataque anterior e configura ataque abrangente cobrindo múltiplas zonas
	player.melee_attack.cancel_attack()
	player.melee_attack.damage = 25.0
	player.melee_attack.horizontal_range = 90.0
	player.melee_attack.active_duration = 0.15
	player.melee_attack.startup_duration = 0.0
	var hp_before: float = target_test_enemy.health_component.current_health
	var hit_ok: bool = player.melee_attack.execute_attack(1.0)
	assert_test(hit_ok, "Execução do golpe bem-sucedida")

	# Verificação via delta de vida (autoridade canônica) em vez de lambda closure
	var hp_delta: float = hp_before - target_test_enemy.health_component.current_health
	assert_test(is_equal_approx(hp_delta, 25.0), "Ataque que cruza múltiplas regiões anatômicas aplica dano exatamente 1 vez (25hp)")
	assert_test(target_test_enemy.health_component.current_health == initial_health - 25.0, "Vida reduzida apenas pelo valor de um único golpe")

	# -------------------------------------------------------------
	# 9. Inimigo em Movimento
	# -------------------------------------------------------------
	print("\n--- 9. Inimigo em Movimento ---")
	target_test_enemy.global_position = Vector2(800, 450)
	var target_iz = target_test_enemy.get_node_or_null("ImpactZones")
	var move_res: Dictionary = target_iz.resolve_impact(target_test_enemy.global_position + Vector2(-30, -110), Vector2(60, 50), ["upper_torso"], 1.0)
	assert_test(is_equal_approx(move_res.position.x, 800.0 - 16.0), "Impacto acompanha coordenada X móvel do inimigo")
	assert_test(move_res.position.y > 450.0 - 130.0 and move_res.position.y < 450.0 - 80.0, "Impacto acompanha coordenada Y móvel do inimigo")

	# -------------------------------------------------------------
	# 10. Inimigo sofrendo Knockback / Hitstun / Queda
	# -------------------------------------------------------------
	print("\n--- 10. Inimigo em Knockback e Queda ---")
	target_test_enemy.velocity = Vector2(150, 0)
	target_test_enemy.current_state = EnemyAI.State.FALL
	var fall_res: Dictionary = ImpactZonesClass.resolve_impact_on_target(target_test_enemy, target_test_enemy.global_position + Vector2(-20, -100))
	assert_test(fall_res.position != Vector2.ZERO, "Resolução funcional durante estado de queda sem travar ou reusar offset obsoleto")

	# -------------------------------------------------------------
	# 12. Outro Inimigo: Padrão 220x300 e Chefe Alessandro
	# -------------------------------------------------------------
	print("\n--- 12. Chefe Alessandro e Escala Oficial ---")
	var boss := BossAlessandroScene.instantiate() as BossAlessandro
	root.add_child(boss)
	boss.global_position = Vector2(1000, 300)

	var b_iz = boss.get_node_or_null("ImpactZones")
	assert_test(b_iz != null, "ImpactZones presente no Chefe Alessandro")
	assert_test(b_iz.head_top_y == -195.0, "Cabeça do Chefe Alessandro calibrada em -195px")
	assert_test(b_iz.horizontal_contact_inset == 22.0, "Inset de contato do Chefe calibrado em 22px")

	var boss_head_res: Dictionary = b_iz.resolve_impact(boss.global_position + Vector2(-50, -170), Vector2(70, 50), ["head"])
	assert_test(boss_head_res.region == "head", "Impacto alto no Chefe identifica 'head' corretamente")

	# -------------------------------------------------------------
	# 13. Mais de um inimigo próximo: impacto associado ao alvo correto
	# -------------------------------------------------------------
	print("\n--- 13. Isolamento entre Inimigos Próximos ---")
	var enemy_a := BasicEnemyScene.instantiate() as EnemyAI
	var enemy_b := BasicEnemyScene.instantiate() as EnemyAI
	root.add_child(enemy_a)
	root.add_child(enemy_b)
	enemy_a.global_position = Vector2(300, 200)
	enemy_b.global_position = Vector2(300, 260)

	var res_a: Dictionary = ImpactZonesClass.resolve_impact_on_target(enemy_a, enemy_a.global_position + Vector2(-30, -110))
	var res_b: Dictionary = ImpactZonesClass.resolve_impact_on_target(enemy_b, enemy_b.global_position + Vector2(-30, -110))
	assert_test(res_a.position.y != res_b.position.y, "Coordenadas de impacto calculadas independentemente para alvos distintos")
	assert_test(abs(res_a.position.y - (200.0 - 110.0)) <= 15.0, "Inimigo A recebe impacto em sua própria coordenada Y")
	assert_test(abs(res_b.position.y - (260.0 - 110.0)) <= 15.0, "Inimigo B recebe impacto em sua própria coordenada Y")

	# -------------------------------------------------------------
	# 14. Ausência de ImpactZones: Fallback gracioso
	# -------------------------------------------------------------
	print("\n--- 14. Fallback Gracioso sem ImpactZones ---")
	var generic_target := Node2D.new()
	root.add_child(generic_target)
	generic_target.global_position = Vector2(400, 300)
	var fallback_res := ImpactZonesClass.resolve_impact_on_target(generic_target, generic_target.global_position + Vector2(-20, -100))
	assert_test(fallback_res.has("region") and fallback_res.has("position"), "Fallback retorna dicionário válido com region e position")
	assert_test(fallback_res.position.y == 300.0 - 85.0, "Fallback utiliza cálculo seguro padrão sem crash")

	# -------------------------------------------------------------
	# 15. Combo Completo preserva sequência, hitstop e knockdown
	# -------------------------------------------------------------
	print("\n--- 15. Preservação do Combo Completo (4 Golpes) ---")
	assert_test(player._combo_attacks.size() == 4, "Combo do jogador possui exatamente 4 ataques")
	var c1 = player._combo_attacks[0]
	var c2 = player._combo_attacks[1]
	var c3 = player._combo_attacks[2]
	var c4 = player._combo_attacks[3]
	# Comparação via string evita mismatch Array[String] vs Array genérico
	assert_test(str(c1.preferred_regions) == str(["head", "upper_torso"]), "Jab configurado para head/upper_torso")
	assert_test(str(c2.preferred_regions) == str(["upper_torso", "head"]), "Cross configurado para upper_torso/head")
	assert_test(str(c3.preferred_regions) == str(["lower_torso"]), "Kick configurado para lower_torso")
	assert_test(str(c4.preferred_regions) == str(["upper_torso", "head"]) and c4.can_knockdown, "Finisher configurado para upper_torso/head com knockdown ativo")

	# -------------------------------------------------------------
	# 16. Combate com Guarda: Mitigação e Faísca de Bloqueio
	# -------------------------------------------------------------
	print("\n--- 16. Combate com Guarda ---")
	player.global_position = Vector2(200, 300)
	player._is_guarding = true
	var hp_before_guard: float = player.health_component.current_health
	var guard_dmg := DamageInfoClass.new(20.0, target_test_enemy, target_test_enemy.global_position, Vector2.LEFT, "melee", 40.0, 0.2)
	var guard_applied := player.take_damage(guard_dmg)
	assert_test(guard_applied, "Dano na guarda processado com sucesso")
	assert_test(player.health_component.current_health == hp_before_guard - (20.0 * 0.30), "Dano na guarda reduzido em 70% (20 * 0.30 = 6.0)")
	assert_test(player.combat_state != PlayerController.CombatState.HURT and player.combat_state != PlayerController.CombatState.FALL, "Jogador em guarda NÃO entra em HURT nem FALL")

	# Limpeza dos nós de teste
	magic_enemy.queue_free()
	player.queue_free()
	target_test_enemy.queue_free()
	boss.queue_free()
	enemy_a.queue_free()
	enemy_b.queue_free()
	generic_target.queue_free()

	print("\n==================================================")
	print("RESULTADO FINAL: %d PASSARAM (Falhas: %d)" % [passed_tests, failed_tests])
	print("==================================================")

	quit(failed_tests)
