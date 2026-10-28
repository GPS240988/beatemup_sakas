class_name ImpactZones
extends Node2D

## Sistema Anatômico de Impacto 2.5D (Projeto Sakas)
## Mapeia e calibra as regiões anatômicas do corpo (head, upper_torso, lower_torso, legs)
## para determinar com precisão a região e coordenada espacial do impacto visual de combate,
## mantendo autoridade única e centralizada para aplicação de dano (Hurtbox / HealthComponent).

enum TargetProfile {
	AUTO,
	JOGADOR_DE_MAGIC,
	STANDARD_220_300,
	BOSS_ALESSANDRO,
	CUSTOM
}

const REGION_HEAD: String = "head"
const REGION_UPPER_TORSO: String = "upper_torso"
const REGION_LOWER_TORSO: String = "lower_torso"
const REGION_LEGS: String = "legs"

@export var profile: TargetProfile = TargetProfile.AUTO

## Faixas verticais relativas à origem do ator no chão (Y=0, valores negativos sobem em direção à cabeça)
@export var head_top_y: float = -170.0
@export var head_bottom_y: float = -125.0

@export var upper_torso_top_y: float = -125.0
@export var upper_torso_bottom_y: float = -85.0

@export var lower_torso_top_y: float = -85.0
@export var lower_torso_bottom_y: float = -45.0

@export var legs_top_y: float = -45.0
@export var legs_bottom_y: float = 0.0

@export var horizontal_contact_inset: float = 16.0

## Referências aos marcadores de nó filho (opcionais, sobrescrevem centros geométricos)
@onready var marker_head: Node2D = get_node_or_null("Head") as Node2D
@onready var marker_upper_torso: Node2D = get_node_or_null("UpperTorso") as Node2D
@onready var marker_lower_torso: Node2D = get_node_or_null("LowerTorso") as Node2D
@onready var marker_legs: Node2D = get_node_or_null("Legs") as Node2D


func _ready() -> void:
	if profile == TargetProfile.AUTO:
		_auto_detect_profile()
	elif profile != TargetProfile.CUSTOM:
		apply_profile_calibration(profile)


func _auto_detect_profile() -> void:
	var p: Node = get_parent()
	if p == null:
		apply_profile_calibration(TargetProfile.STANDARD_220_300)
		return

	var p_name: String = p.name.to_lower()
	var disp_name: String = str(p.get("display_name")).to_lower() if p.get("display_name") != null else ""

	if "magic" in disp_name or "magic" in p_name or "basicenemy" in p_name:
		apply_profile_calibration(TargetProfile.JOGADOR_DE_MAGIC)
	elif "alessandro" in p_name or "boss" in p_name:
		apply_profile_calibration(TargetProfile.BOSS_ALESSANDRO)
	else:
		apply_profile_calibration(TargetProfile.STANDARD_220_300)


## Calibra as faixas anatômicas conforme as dimensões reais de cada personagem
func apply_profile_calibration(p: TargetProfile) -> void:
	profile = p
	match p:
		TargetProfile.JOGADOR_DE_MAGIC:
			# Jogador de Magic: sprite nativo com escala 0.42 e altura útil útil de ~165px
			head_top_y = -170.0
			head_bottom_y = -125.0
			upper_torso_top_y = -125.0
			upper_torso_bottom_y = -85.0
			lower_torso_top_y = -85.0
			lower_torso_bottom_y = -45.0
			legs_top_y = -45.0
			legs_bottom_y = 0.0
			horizontal_contact_inset = 16.0
		TargetProfile.BOSS_ALESSANDRO:
			# Chefe Alessandro: canvas 250x330 em escala 0.80, altura ~195px
			head_top_y = -195.0
			head_bottom_y = -145.0
			upper_torso_top_y = -145.0
			upper_torso_bottom_y = -95.0
			lower_torso_top_y = -95.0
			lower_torso_bottom_y = -45.0
			legs_top_y = -45.0
			legs_bottom_y = 0.0
			horizontal_contact_inset = 22.0
		TargetProfile.STANDARD_220_300, _:
			# Heróis e Capangas padrão 220x300 em escala 0.80, altura ~200-210px
			head_top_y = -210.0
			head_bottom_y = -155.0
			upper_torso_top_y = -155.0
			upper_torso_bottom_y = -105.0
			lower_torso_top_y = -105.0
			lower_torso_bottom_y = -55.0
			legs_top_y = -55.0
			legs_bottom_y = 0.0
			horizontal_contact_inset = 18.0


## Retorna os limites verticais locais de uma região anatômica
func get_zone_local_bounds(region_name: String) -> Vector2:
	match region_name.to_lower():
		REGION_HEAD:
			return Vector2(head_top_y, head_bottom_y)
		REGION_UPPER_TORSO:
			return Vector2(upper_torso_top_y, upper_torso_bottom_y)
		REGION_LOWER_TORSO:
			return Vector2(lower_torso_top_y, lower_torso_bottom_y)
		REGION_LEGS:
			return Vector2(legs_top_y, legs_bottom_y)
		_:
			return Vector2(upper_torso_top_y, upper_torso_bottom_y)


## Determina a região atingida e calcula a posição espacial do feedback de impacto
func resolve_impact(
	attack_hitbox_global_pos: Vector2,
	hitbox_size: Vector2 = Vector2(80.0, 60.0),
	preferred_regions: Array = [],
	attacker_facing: float = 1.0,
	_impact_profile: String = "punch"
) -> Dictionary:
	var half_h: float = absf(hitbox_size.y) * 0.5
	var atk_top: float = attack_hitbox_global_pos.y - half_h
	var atk_bot: float = attack_hitbox_global_pos.y + half_h

	var base_y: float = global_position.y
	var base_x: float = global_position.x

	# 1. Mapeamento das 4 zonas anatômicas em coordenadas globais
	var zones: Dictionary = {
		REGION_HEAD: {
			"top": base_y + head_top_y,
			"bottom": base_y + head_bottom_y,
			"center": base_y + (head_top_y + head_bottom_y) * 0.5,
			"marker": marker_head if marker_head != null else get_node_or_null("Head")
		},
		REGION_UPPER_TORSO: {
			"top": base_y + upper_torso_top_y,
			"bottom": base_y + upper_torso_bottom_y,
			"center": base_y + (upper_torso_top_y + upper_torso_bottom_y) * 0.5,
			"marker": marker_upper_torso if marker_upper_torso != null else get_node_or_null("UpperTorso")
		},
		REGION_LOWER_TORSO: {
			"top": base_y + lower_torso_top_y,
			"bottom": base_y + lower_torso_bottom_y,
			"center": base_y + (lower_torso_top_y + lower_torso_bottom_y) * 0.5,
			"marker": marker_lower_torso if marker_lower_torso != null else get_node_or_null("LowerTorso")
		},
		REGION_LEGS: {
			"top": base_y + legs_top_y,
			"bottom": base_y + legs_bottom_y,
			"center": base_y + (legs_top_y + legs_bottom_y) * 0.5,
			"marker": marker_legs if marker_legs != null else get_node_or_null("Legs")
		}
	}

	# 2. Cálculo da sobreposição geométrica efetiva com cada região
	var overlaps: Dictionary = {}
	for reg: String in zones.keys():
		var z: Dictionary = zones[reg]
		var ov: float = maxf(0.0, minf(atk_bot, z["bottom"]) - maxf(atk_top, z["top"]))
		overlaps[reg] = ov

	# 3. Determinação da região atingida
	var chosen_region: String = ""
	var best_overlap: float = 0.0

	# Candidatas prioritárias são avaliadas primeiramente se houver contato real
	if not preferred_regions.is_empty():
		for pref in preferred_regions:
			var pref_str := str(pref).to_lower()
			if overlaps.has(pref_str) and overlaps[pref_str] > 0.0:
				if chosen_region.is_empty() or overlaps[pref_str] > best_overlap:
					chosen_region = pref_str
					best_overlap = overlaps[pref_str]

	# Se nenhuma região preferida foi fisicamente alcançada, escolhe a região com maior contato real
	if chosen_region.is_empty() or best_overlap <= 0.0:
		for reg in [REGION_UPPER_TORSO, REGION_HEAD, REGION_LOWER_TORSO, REGION_LEGS]:
			if overlaps[reg] > best_overlap:
				best_overlap = overlaps[reg]
				chosen_region = reg

	# Se a hitbox não sobrepôs nenhuma zona (ex: checagem de distância ampla sem colisão direta)
	if chosen_region.is_empty() or best_overlap <= 0.0:
		if not preferred_regions.is_empty():
			chosen_region = str(preferred_regions[0]).to_lower()
		else:
			chosen_region = REGION_UPPER_TORSO

	# 4. Cálculo da coordenada espacial de impacto obedecendo à hierarquia de prioridade
	var z_data: Dictionary = zones[chosen_region]
	var pos_y: float = z_data["center"]
	var marker: Node2D = z_data.get("marker")

	if overlaps.get(chosen_region, 0.0) > 0.0:
		# Prioridade 1: Ponto de contato real (centro da interseção física)
		var c_top: float = maxf(atk_top, z_data["top"])
		var c_bot: float = minf(atk_bot, z_data["bottom"])
		pos_y = (c_top + c_bot) * 0.5
	elif marker != null and is_instance_valid(marker):
		# Prioridade 2: Marcador espacial dedicado da região
		pos_y = marker.global_position.y
	else:
		# Prioridade 3: Centro espacial calibrado da região anatômica
		pos_y = z_data["center"]

	# Coordenada horizontal: face de contato voltada para o atacante
	var pos_x: float = base_x - (attacker_facing * horizontal_contact_inset)
	if marker != null and is_instance_valid(marker) and marker.position.x != 0.0:
		pos_x = marker.global_position.x

	return {
		"region": chosen_region,
		"position": Vector2(pos_x, pos_y),
		"zone_node": marker
	}


## Helper estático universal para resolver impacto anatômico em qualquer alvo
static func resolve_impact_on_target(
	target: Node,
	attack_hitbox_global_pos: Vector2,
	hitbox_size: Vector2 = Vector2(80.0, 60.0),
	preferred_regions: Array = [],
	attacker_facing: float = 1.0,
	impact_profile: String = "punch"
) -> Dictionary:
	if target == null:
		return { "region": REGION_UPPER_TORSO, "position": attack_hitbox_global_pos }

	var iz := get_impact_zones(target)
	if iz != null and is_instance_valid(iz):
		return iz.resolve_impact(attack_hitbox_global_pos, hitbox_size, preferred_regions, attacker_facing, impact_profile)

	# Fallback universal para entidades sem ImpactZones (ex: Props destrutíveis ou testes dinâmicos)
	var target_node2d := target as Node2D
	var base_pos: Vector2 = target_node2d.global_position if target_node2d != null else attack_hitbox_global_pos
	var hurtbox: Area2D = target.get_node_or_null("Hurtbox") as Area2D

	var fallback_y: float = base_pos.y - 85.0
	var fallback_x: float = base_pos.x - (attacker_facing * 16.0)

	if hurtbox != null and is_instance_valid(hurtbox):
		fallback_y = hurtbox.global_position.y
		fallback_x = hurtbox.global_position.x - (attacker_facing * 10.0)

	return {
		"region": REGION_UPPER_TORSO,
		"position": Vector2(fallback_x, fallback_y),
		"zone_node": hurtbox
	}


## Localiza o nó ImpactZones em um ator
static func get_impact_zones(actor: Node) -> ImpactZones:
	if actor == null:
		return null
	var iz: ImpactZones = actor.get_node_or_null("ImpactZones") as ImpactZones
	if iz != null:
		return iz
	for child in actor.get_children():
		if child is ImpactZones:
			return child as ImpactZones
	return null
