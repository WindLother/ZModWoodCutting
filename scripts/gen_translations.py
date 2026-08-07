# -*- coding: utf-8 -*-
"""Generate the Build 42 JSON translation tree for WoodcuttingSkill_B42.

Build 42.20.2's Translator reads exactly one path:
    <modVersionDir-or-commonDir>/media/lua/shared/Translate/<LANG>/<Type>.json
Legacy <Type>_<LANG>.txt tables are ignored entirely.

Literal '%' must be written '%%' in every file the game parses as text (42.20.1/42.20.2).
"""
import json, os, io

ROOT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Contents", "mods", "WoodcuttingSkill - Build 42",
    "common", "media", "lua", "shared", "Translate",
)

# Perk display name per language -> also used to build the vanilla-quirk description key
# (ISSkillProgressBar builds "IGUI_perks_"..perk:getName().."_Description", and perk:getName()
#  is the *translated* name, not the perk id).
PERK_NAME = {
    "EN":   "Woodcutting",
    "PT":   "Corte de Madeira",
    "PTBR": "Corte de Madeira",
    "ES":   "Tala de árboles",
    "FR":   "Abattage du bois",
}

PERK_DESC = {
    "EN": "Cut trees and remove bushes more efficiently: -7%% endurance per level, "
          "+2 tree damage per level (axes), +10%% bush removal speed per level, and a chance for "
          "extra loot on medium and large trees. At level 8, chopping no longer escalates to "
          "Excessive Exertion.",
    "PT": "Corte árvores e remova arbustos com mais eficiência: -7%% de vigor por nível, "
          "+2 de dano a árvores por nível (machados), +10%% de velocidade a remover arbustos por "
          "nível, e hipótese de saque extra em árvores médias e grandes. No nível 8, cortar deixa "
          "de escalar para Exaustão Excessiva.",
    "PTBR": "Corte árvores e remova arbustos com mais eficiência: -7%% de vigor por nível, "
            "+2 de dano a árvores por nível (machados), +10%% de velocidade ao remover arbustos "
            "por nível, e chance de loot extra em árvores médias e grandes. No nível 8, cortar "
            "não escala mais para Exaustão Excessiva.",
    "ES": "Tala árboles y elimina arbustos con mayor eficiencia: -7%% de resistencia por nivel, "
          "+2 de daño a árboles por nivel (hachas), +10%% de velocidad al eliminar arbustos por "
          "nivel, y posibilidad de botín extra en árboles medianos y grandes. En el nivel 8, "
          "talar ya no escala a Agotamiento Excesivo.",
    "FR": "Abattez les arbres et retirez les buissons plus efficacement : -7%% d'endurance par "
          "niveau, +2 dégâts aux arbres par niveau (haches), +10%% de vitesse de débroussaillage "
          "par niveau, et une chance de butin supplémentaire sur les arbres moyens et grands. "
          "Au niveau 8, l'abattage n'escalade plus vers l'Épuisement Excessif.",
}

TREES = {"EN": "Trees", "PT": "Árvores", "PTBR": "Árvores", "ES": "Árboles", "FR": "Arbres"}
BUSHES = {"EN": "Bushes", "PT": "Arbustos", "PTBR": "Arbustos", "ES": "Arbustos", "FR": "Buissons"}

TRAIT = {
    "EN":   ("Woodcutter", "Starts with +1 Woodcutting and is better at finding firewood."),
    "PT":   ("Lenhador", "Começa com +1 de Corte de Madeira e é melhor a encontrar lenha."),
    "PTBR": ("Lenhador", "Começa com +1 de Corte de Madeira e é melhor em encontrar lenha."),
    "ES":   ("Leñador", "Empieza con +1 de Tala de árboles y encuentra leña con más facilidad."),
    "FR":   ("Bûcheron", "Commence avec +1 en Abattage du bois et trouve plus facilement du bois de chauffage."),
}

PAGE = {
    "EN": "Woodcutting", "PT": "Corte de Madeira", "PTBR": "Corte de Madeira",
    "ES": "Tala de árboles", "FR": "Abattage du bois",
}

# option -> {lang: (label, tooltip)}
SANDBOX = {
    "damageBaseMultiplier": {
        "EN": ("Base Damage Multiplier", "Multiplies tree damage at level 0, before per-level scaling."),
        "PT": ("Multiplicador de Dano Base", "Multiplica o dano a árvores no nível 0, antes do bónus por nível."),
        "PTBR": ("Multiplicador de Dano Base", "Multiplica o dano em árvores no nível 0, antes do bônus por nível."),
        "ES": ("Multiplicador de daño base", "Multiplica el daño a árboles en el nivel 0, antes del escalado por nivel."),
        "FR": ("Multiplicateur de dégâts de base", "Multiplie les dégâts aux arbres au niveau 0, avant le bonus par niveau."),
    },
    "damagePerLevel": {
        "EN": ("Damage per Level (+%%)", "Additional damage per Woodcutting level. 0.15 = +15%% per level."),
        "PT": ("Dano por Nível (+%%)", "Dano adicional por nível de Corte de Madeira. 0,15 = +15%% por nível."),
        "PTBR": ("Dano por Nível (+%%)", "Dano adicional por nível de Corte de Madeira. 0,15 = +15%% por nível."),
        "ES": ("Daño por nivel (+%%)", "Daño adicional por nivel de Tala de árboles. 0,15 = +15%% por nivel."),
        "FR": ("Dégâts par niveau (+%%)", "Dégâts supplémentaires par niveau d'Abattage du bois. 0,15 = +15%% par niveau."),
    },
    "damageMaxMultiplier": {
        "EN": ("Max Damage Multiplier (cap)", "Upper cap for the total tree-damage multiplier."),
        "PT": ("Teto do Multiplicador de Dano", "Limite máximo do multiplicador total de dano a árvores."),
        "PTBR": ("Teto do Multiplicador de Dano", "Limite máximo do multiplicador total de dano em árvores."),
        "ES": ("Multiplicador de daño máximo", "Límite superior del multiplicador total de daño a árboles."),
        "FR": ("Multiplicateur de dégâts maximum", "Plafond du multiplicateur total de dégâts aux arbres."),
    },
    # Max levels are 10, so any threshold of 11+ can never be reached and disables the feature.
    # 0 is not "off" - it means every tree falls in one swing from level 0. Say so explicitly:
    # a player looking for a disable switch will otherwise reach for 0 first.
    "oneHitLevelThreshold": {
        "EN": ("One-Hit Level Threshold", "At or above this Woodcutting level, trees fall in one swing. Set to 11 or higher to disable this entirely. 0 means every tree falls in one swing from the start."),
        "PT": ("Nível para Derrubar num Golpe", "A partir deste nível de Corte de Madeira, as árvores caem num golpe. Use 11 ou mais para desativar por completo. 0 faz todas as árvores caírem num golpe desde o início."),
        "PTBR": ("Nível para Derrubar em 1 Golpe", "A partir deste nível de Corte de Madeira, as árvores caem em um golpe. Use 11 ou mais para desativar por completo. 0 faz todas as árvores caírem em um golpe desde o início."),
        "ES": ("Nivel para talar de un golpe", "A partir de este nivel de Tala de árboles, los árboles caen de un golpe. Usa 11 o más para desactivarlo por completo. 0 hace que todos los árboles caigan de un golpe desde el principio."),
        "FR": ("Niveau pour abattre en un coup", "À partir de ce niveau d'Abattage du bois, les arbres tombent en un coup. Mettez 11 ou plus pour désactiver complètement. 0 fait tomber tous les arbres en un coup dès le départ."),
    },
    "oneHitTreeDamage": {
        "EN": ("One-Hit TreeDamage value", "TreeDamage used once the one-hit threshold is reached."),
        "PT": ("Valor de TreeDamage num Golpe", "Valor de TreeDamage usado quando o limiar de um golpe é atingido."),
        "PTBR": ("Valor de TreeDamage em 1 Golpe", "Valor de TreeDamage usado quando o limiar de 1 golpe é atingido."),
        "ES": ("Valor de TreeDamage de un golpe", "TreeDamage usado al alcanzar el umbral de un golpe."),
        "FR": ("Valeur de TreeDamage en un coup", "TreeDamage utilisé une fois le seuil d'un coup atteint."),
    },
    "onlyForAxes": {
        "EN": ("Affect only Axes", "If enabled, damage scaling applies to axes only."),
        "PT": ("Apenas para Machados", "Se ativo, o escalonamento de dano aplica-se apenas a machados."),
        "PTBR": ("Apenas para Machados", "Se ativo, o escalonamento de dano se aplica apenas a machados."),
        "ES": ("Solo para hachas", "Si se activa, el escalado de daño se aplica solo a hachas."),
        "FR": ("Haches uniquement", "Si activé, le bonus de dégâts ne s'applique qu'aux haches."),
    },
    "xpMultiplier": {
        "EN": ("XP Multiplier", "Global Woodcutting XP multiplier."),
        "PT": ("Multiplicador de XP", "Multiplicador global de XP de Corte de Madeira."),
        "PTBR": ("Multiplicador de XP", "Multiplicador global de XP de Corte de Madeira."),
        "ES": ("Multiplicador de XP", "Multiplicador global de XP de Tala de árboles."),
        "FR": ("Multiplicateur d'XP", "Multiplicateur global d'XP d'Abattage du bois."),
    },
    "axeXpPerHit": {
        "EN": ("Axe XP per Tree Hit", "Axe XP awarded for each tree hit made with an axe. Set to 0 to disable."),
        "PT": ("XP de Machado por Golpe", "XP de Machado por cada golpe numa árvore com um machado. Use 0 para desativar."),
        "PTBR": ("XP de Machado por Golpe", "XP de Machado por cada golpe em árvore com um machado. Use 0 para desativar."),
        "ES": ("XP de Hacha por golpe", "XP de Hacha por cada golpe a un árbol con un hacha. Usa 0 para desactivar."),
        "FR": ("XP de Hache par coup", "XP de Hache accordée à chaque coup porté à un arbre avec une hache. 0 pour désactiver."),
    },
    "treeFelledXp": {
        "EN": ("Woodcutting XP per Tree Felled", "Bonus Woodcutting XP when a tree is fully cut down. Set to 0 to disable."),
        "PT": ("XP por Árvore Derrubada", "XP de Corte de Madeira ao derrubar uma árvore por completo. Use 0 para desativar."),
        "PTBR": ("XP por Árvore Derrubada", "XP de Corte de Madeira ao derrubar uma árvore por completo. Use 0 para desativar."),
        "ES": ("XP por árbol talado", "XP de Tala de árboles al derribar un árbol por completo. Usa 0 para desactivar."),
        "FR": ("XP par arbre abattu", "XP d'Abattage du bois lorsqu'un arbre est entièrement abattu. 0 pour désactiver."),
    },
    "axeXpOnTreeFelled": {
        "EN": ("Axe XP per Tree Felled", "Bonus Axe XP when a tree is fully cut down with an axe. Set to 0 to disable."),
        "PT": ("XP de Machado por Árvore Derrubada", "XP de Machado ao derrubar uma árvore por completo com um machado. Use 0 para desativar."),
        "PTBR": ("XP de Machado por Árvore Derrubada", "XP de Machado ao derrubar uma árvore por completo com um machado. Use 0 para desativar."),
        "ES": ("XP de Hacha por árbol talado", "XP de Hacha al derribar un árbol por completo con un hacha. Usa 0 para desactivar."),
        "FR": ("XP de Hache par arbre abattu", "XP de Hache lorsqu'un arbre est entièrement abattu à la hache. 0 pour désactiver."),
    },
    "bushRemovedXp": {
        "EN": ("Woodcutting XP per Bush Removed", "Woodcutting XP awarded for clearing a bush. Set to 0 to disable."),
        "PT": ("XP por Arbusto Removido", "XP de Corte de Madeira ao limpar um arbusto. Use 0 para desativar."),
        "PTBR": ("XP por Arbusto Removido", "XP de Corte de Madeira ao limpar um arbusto. Use 0 para desativar."),
        "ES": ("XP por arbusto eliminado", "XP de Tala de árboles al despejar un arbusto. Usa 0 para desactivar."),
        "FR": ("XP par buisson retiré", "XP d'Abattage du bois pour avoir dégagé un buisson. 0 pour désactiver."),
    },
    "cumulatedForagingAndWoodcuttingSkillLevelForFruit": {
        "EN": ("Min (Foraging + Woodcutting) for Fruit", "Minimum combined levels required for fruit extras."),
        "PT": ("Mín. (Recolha + Corte) para Fruta", "Soma mínima de níveis exigida para extras de fruta."),
        "PTBR": ("Mín. (Coleta + Corte) para Frutas", "Soma mínima de níveis exigida para extras de frutas."),
        "ES": ("Mín. (Recolección + Tala) para fruta", "Suma mínima de niveles requerida para los extras de fruta."),
        "FR": ("Min. (Cueillette + Abattage) pour fruits", "Somme minimale de niveaux requise pour les fruits supplémentaires."),
    },
    "FruitTreeExtra": {
        "EN": ("Fruit Tree Extra (1 in N)", "Lower is more likely. Adjusted by abundance and skills."),
        "PT": ("Extra de Fruta (1 em N)", "Quanto menor, maior a hipótese. Ajustado pela abundância e perícias."),
        "PTBR": ("Extra de Frutas (1 em N)", "Quanto menor, maior a chance. Ajustado pela abundância e habilidades."),
        "ES": ("Extra de fruta (1 de cada N)", "Cuanto menor, más probable. Se ajusta por abundancia y habilidades."),
        "FR": ("Fruit supplémentaire (1 sur N)", "Plus la valeur est basse, plus c'est probable. Ajusté par l'abondance et les compétences."),
    },
    "Winter": {
        "EN": ("Winter Extra (1 in N)", "Extras chance during winter. Lower is more likely."),
        "PT": ("Extra de Inverno (1 em N)", "Hipótese de extras durante o inverno. Quanto menor, maior a hipótese."),
        "PTBR": ("Extra de Inverno (1 em N)", "Chance de extras durante o inverno. Quanto menor, maior a chance."),
        "ES": ("Extra de invierno (1 de cada N)", "Probabilidad de extras en invierno. Cuanto menor, más probable."),
        "FR": ("Extra d'hiver (1 sur N)", "Chance de butin en hiver. Plus la valeur est basse, plus c'est probable."),
    },
    "Pinecone": {
        "EN": ("Pinecone (1 in N)", "Chance to get a pinecone. Lower is more likely."),
        "PT": ("Pinha (1 em N)", "Hipótese de obter uma pinha. Quanto menor, maior a hipótese."),
        "PTBR": ("Pinha (1 em N)", "Chance de obter uma pinha. Quanto menor, maior a chance."),
        "ES": ("Piña (1 de cada N)", "Probabilidad de obtener una piña. Cuanto menor, más probable."),
        "FR": ("Pomme de pin (1 sur N)", "Chance d'obtenir une pomme de pin. Plus la valeur est basse, plus c'est probable."),
    },
    "PineTreeExtra": {
        "EN": ("Pine Extra (1 in N)", "Extra loot on pine-like trees. Lower is more likely."),
        "PT": ("Extra de Pinheiro (1 em N)", "Saque extra em árvores tipo pinheiro. Quanto menor, maior a hipótese."),
        "PTBR": ("Extra de Pinheiro (1 em N)", "Loot extra em árvores tipo pinheiro. Quanto menor, maior a chance."),
        "ES": ("Extra de pino (1 de cada N)", "Botín extra en árboles tipo pino. Cuanto menor, más probable."),
        "FR": ("Extra de conifère (1 sur N)", "Butin supplémentaire sur les conifères. Plus la valeur est basse, plus c'est probable."),
    },
    "Log": {
        "EN": ("Extra Log (1 in N)", "Chance to get an extra log."),
        "PT": ("Tronco Extra (1 em N)", "Hipótese de obter um tronco extra."),
        "PTBR": ("Tora Extra (1 em N)", "Chance de obter uma tora extra."),
        "ES": ("Tronco extra (1 de cada N)", "Probabilidad de obtener un tronco extra."),
        "FR": ("Bûche supplémentaire (1 sur N)", "Chance d'obtenir une bûche supplémentaire."),
    },
    "TreeBranch": {
        "EN": ("Extra Tree Branch (1 in N)", "Chance to get an extra tree branch."),
        "PT": ("Ramo Extra (1 em N)", "Hipótese de obter um ramo extra."),
        "PTBR": ("Galho Extra (1 em N)", "Chance de obter um galho extra."),
        "ES": ("Rama extra (1 de cada N)", "Probabilidad de obtener una rama extra."),
        "FR": ("Branche supplémentaire (1 sur N)", "Chance d'obtenir une branche supplémentaire."),
    },
    "Twigs": {
        "EN": ("Extra Twigs (1 in N)", "Chance to get extra twigs."),
        "PT": ("Gravetos Extra (1 em N)", "Hipótese de obter gravetos extra."),
        "PTBR": ("Gravetos Extras (1 em N)", "Chance de obter gravetos extras."),
        "ES": ("Ramitas extra (1 de cada N)", "Probabilidad de obtener ramitas extra."),
        "FR": ("Brindilles supplémentaires (1 sur N)", "Chance d'obtenir des brindilles supplémentaires."),
    },
}

ORDER = list(SANDBOX.keys())


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = json.dumps(data, ensure_ascii=False, indent=4) + "\n"
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    # Nothing the game parses as text may contain a lone '%'.
    stripped = text.replace("%%", "")
    assert "%" not in stripped, "lone %% in " + path
    print("wrote", os.path.relpath(path, ROOT))


for lang in ("EN", "PT", "PTBR", "ES", "FR"):
    igui = {
        "IGUI_perks_Woodcutting": PERK_NAME[lang],
        "IGUI_perks_Woodcutting_Description": PERK_DESC[lang],
        "IGUI_trees": TREES[lang],
        "IGUI_bushes": BUSHES[lang],
    }
    # Vanilla quirk: ISSkillProgressBar looks the description up by the *translated* perk name,
    # so non-English languages need the key duplicated under that name. Do not remove.
    if PERK_NAME[lang] != "Woodcutting":
        igui["IGUI_perks_%s_Description" % PERK_NAME[lang]] = PERK_DESC[lang]
    write(os.path.join(ROOT, lang, "IG_UI.json"), igui)

    sandbox = {"Sandbox_Woodcutting": PAGE[lang]}
    for opt in ORDER:
        label, tooltip = SANDBOX[opt][lang]
        sandbox["Sandbox_Woodcutting_%s" % opt] = label
        sandbox["Sandbox_Woodcutting_%s_tooltip" % opt] = tooltip
    write(os.path.join(ROOT, lang, "Sandbox.json"), sandbox)

    name, desc = TRAIT[lang]
    write(os.path.join(ROOT, lang, "UI.json"), {
        "UI_trait_woodcutter": name,
        "UI_trait_woodcutterdesc": desc,
    })
