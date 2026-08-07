-- WoodcuttingSkillDefinitions.lua (Shared)

Woodcutting = Woodcutting or {}

Woodcutting.testMode = false -- enable this for debug

-- Prints a message to the console/log exactly once per unique key, regardless of testMode.
-- Used to surface silent-failure paths (e.g. perk lookup) so bug reports come with actionable output.
local diagLoggedKeys = {}
function Woodcutting.diag(key, message)
    if diagLoggedKeys[key] then return end
    diagLoggedKeys[key] = true
    print("[Woodcutting][DIAG] " .. message)
end

Woodcutting.Settings = {
    ChanceOfExtrasOneIn = {
        -- chances must all be higher than 17 (max tree size 9 max perk level)
        Log = 40,
        TreeBranch = 35,
        Twigs = 30,

        Pinecone = 20, -- for pine trees only
        PineTreeExtra = 120, -- for pine trees only

        FruitTreeExtra = 80, -- for 'fruit' trees only
        Winter = 130 -- for 'fruit' trees only
    },

    cumulatedForagingAndWoodcuttingSkillLevelForFruit = 8, --Woodcutting + Foraging level required to spawn food
    skillLevelForNoSevereExhaustion = 8, --Woodcutting level required to disable severe exhaustion

    enduranceSavedPerPerkLevel = 0.07, -- 7%
    bonusConditionLowerOneInPerLevel = 1,
    caloriesSavedModifierPerLevel = 0.37,
    bonusAxeTreeDamagePerLevel = 2, -- flat addition, not multiplied

    xpMultiplier = 1,
    axeXpPerHit = 0.05,
    treeFelledXp = 5.0,
    axeXpOnTreeFelled = 1.0,
    bushRemovedXp = 1.0,

    -- ============================
    -- PARÂMETROS DE DANO
    -- ============================
    -- Multiplicador base e por nível (aplica em QUALQUER arma afetada)
    damageBaseMultiplier  = 1.0,   -- 1.0 = padrão no nível 0
    damagePerLevel        = 0.15,  -- +15% por nível (ajuste livre)

    -- Teto de multiplicador (evita absurdos se quiser)
    damageMaxMultiplier   = 8.0,   -- até 8x do dano base

    -- Um-hit a partir deste nível (para atender à meta de 1 golpe no nível 6–7)
    oneHitLevelThreshold  = 6,     -- nível de Woodcutting a partir do qual vira 1-hit
    oneHitTreeDamage      = 2000,  -- valor alto o suficiente para derrubar qualquer árvore em 1 golpe

    -- Restringir só a machados?
    onlyForAxes           = true,  -- true = só machados; false = qualquer HandWeapon
}

-- Un-scaled loot chances. AdjustNatureAbundance() derives Settings.ChanceOfExtrasOneIn from this
-- table, never from itself, so it is idempotent and cannot compound when the event that drives it
-- fires more than once (OnGameStart + OnServerStarted both fire on a listen server).
-- The Sandbox bridge writes here, not into Settings.ChanceOfExtrasOneIn.
Woodcutting.BaseChanceOfExtrasOneIn = {}
for key, value in pairs(Woodcutting.Settings.ChanceOfExtrasOneIn) do
    Woodcutting.BaseChanceOfExtrasOneIn[key] = value
end

function Woodcutting.getPerk()
    if Perks.Woodcutting then
        Woodcutting.diag("getPerk:direct", "getPerk() resolved via Perks.Woodcutting direct field")
        return Perks.Woodcutting
    end
    if Perks.FromString then
        local perk = Perks.FromString("Woodcutting")
        if perk and perk ~= Perks.MAX then
            Woodcutting.diag("getPerk:fromstring", "getPerk() resolved via Perks.FromString('Woodcutting') -> " .. tostring(perk))
            return perk
        end
        Woodcutting.diag("getPerk:fromstring:fail", "Perks.FromString('Woodcutting') returned " .. tostring(perk) .. " (rejected, falling back to PerkFactory)")
    end
    -- Last resort only: PerkFactory indexes PerkByName by the *translated* perk name
    -- (PerkFactory.initTranslations sets perk.name = getText("IGUI_perks_"..translation)), so this
    -- lookup can only ever succeed while the game language is English.
    if PerkFactory.getPerkFromName then
        local perk = PerkFactory.getPerkFromName("Woodcutting")
        if perk then
            Woodcutting.diag("getPerk:factory", "getPerk() resolved via PerkFactory.getPerkFromName('Woodcutting') -> " .. tostring(perk))
            return perk
        end
        Woodcutting.diag("getPerk:factory:fail", "PerkFactory.getPerkFromName('Woodcutting') returned nil")
    end
    Woodcutting.diag("getPerk:totalfail", "Woodcutting.getPerk() FAILED to resolve the Woodcutting perk through any method - all XP/damage/loot features are silently disabled")
    return nil
end

function Woodcutting.isAxe(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return false end
    local scriptItem = weapon:getScriptItem()
    return scriptItem ~= nil and scriptItem:containsWeaponCategory(WeaponCategory.AXE)
end

-- Build 42 gates the Chop Tree action on ItemTag.CHOP_TREE, which is a different set from
-- WeaponCategory.AXE. Used for reporting/diagnostics; balance still keys off isAxe().
function Woodcutting.canChopTree(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return false end
    return weapon:hasTag(ItemTag.CHOP_TREE)
end

local currentTrees = setmetatable({}, { __mode = "k" })
local treeHitCallbacks = {}
local treeFelledCallbacks = {}
local bushRemovedCallbacks = {}

function Woodcutting.setCurrentTree(character, tree)
    if character then currentTrees[character] = tree end
end

function Woodcutting.getCurrentTree(character)
    return character and currentTrees[character] or nil
end

local function dispatch(callbacks, label, ...)
    for _, callback in ipairs(callbacks) do
        local ok, err = pcall(callback, ...)
        if not ok then
            print("[Woodcutting] " .. label .. " callback failed: " .. tostring(err))
        end
    end
end

-- Fired once per axe swing that lands on a tree, from either of the two engine paths that can
-- damage a tree in Build 42: the Chop Tree timed action (B42_TimedActionPacthes.lua) and a plain
-- melee swing (Events.OnWeaponHitTree). `tree` is nil on the melee path - the engine does not
-- tell us which tree was hit there.
function Woodcutting.addOnTreeHit(callback)
    if callback then table.insert(treeHitCallbacks, callback) end
end

function Woodcutting.onTreeHit(character, weapon, tree, treeSize, spriteName)
    Woodcutting.diag("onTreeHit:dispatch", "Woodcutting.onTreeHit() dispatched - " .. #treeHitCallbacks .. " callback(s) registered")
    dispatch(treeHitCallbacks, "OnTreeHit", character, weapon, tree, treeSize, spriteName)
end

function Woodcutting.addOnTreeFelled(callback)
    if callback then table.insert(treeFelledCallbacks, callback) end
end

function Woodcutting.onTreeFelled(character, weapon, tree, treeSize, spriteName)
    Woodcutting.diag("onTreeFelled:dispatch", "Woodcutting.onTreeFelled() dispatched (treeSize=" .. tostring(treeSize) .. ", sprite=" .. tostring(spriteName) .. ") - " .. #treeFelledCallbacks .. " callback(s) registered")
    dispatch(treeFelledCallbacks, "OnTreeFelled", character, weapon, tree, treeSize, spriteName)
end

function Woodcutting.addOnBushRemoved(callback)
    if callback then table.insert(bushRemovedCallbacks, callback) end
end

function Woodcutting.onBushRemoved(character, weapon)
    Woodcutting.diag("onBushRemoved:dispatch", "Woodcutting.onBushRemoved() dispatched - " .. #bushRemovedCallbacks .. " callback(s) registered")
    dispatch(bushRemovedCallbacks, "OnBushRemoved", character, weapon)
end

Woodcutting.TreeFruitExtrasList = { -- except winter
    "Cherry",
    "Lemon",
    "Lime",
    "Grapefruit",
    "Peach",
    "Pear",
    "Apple",
    "Orange",
    "Banana",
    "Acorn",
    "DeadSquirrel",
}

Woodcutting.TreeFruitsWinterList = { -- for winter
    "DeadSquirrel",
}
Woodcutting.PineTreeExtrasList = { -- in all seasons
    "DeadSquirrel",
}
Woodcutting.TreePineSpriteDefinitions = {

    ["e_virginia_pineJUMBO_1_0"] = 1,
    ["e_virginia_pineJUMBO_1_1"] = 1,
    ["e_virginia_pine_1_0"] = 1,
    ["e_virginia_pine_1_1"] = 1,

    ["e_americanhollyJUMBO_1_1"] = 1,
    ["e_americanhollyJUMBO_1_0"] = 1,
    ["e_americanholly_1_1"] = 1,
    ["e_americanholly_1_0"] = 1,

    ["e_canadianhemlockJUMBO_1_0"] = 1,
    ["e_canadianhemlockJUMBO_1_1"] = 1,
    ["e_canadianhemlock_1_0"] = 1,
    ["e_canadianhemlock_1_1"] = 1,

}

function Woodcutting.noise(text)
    if Woodcutting.testMode then
        print(text)
    end
end

-- Recomputes the effective loot chances from BaseChanceOfExtrasOneIn. Pure and idempotent:
-- calling it twice with the same sandbox settings produces the same result.
function Woodcutting.AdjustNatureAbundance()
    local base = Woodcutting.BaseChanceOfExtrasOneIn
    local abundance = SandboxVars and SandboxVars.NatureAbundance or 3
    local factor = 1.0
    if abundance == 1 then     -- very poor
        factor = 1.2
    elseif abundance == 2 then -- poor
        factor = 1.1
    elseif abundance == 4 then -- abundant
        factor = 0.9
    elseif abundance == 5 then -- very abundant
        factor = 0.8
    end

    local effective = {}
    for key, value in pairs(base) do
        effective[key] = math.max(2, math.floor(value * factor))
    end
    Woodcutting.Settings.ChanceOfExtrasOneIn = effective

    Woodcutting.diag("AdjustNatureAbundance:applied",
        "AdjustNatureAbundance() applied factor " .. tostring(factor) .. " (NatureAbundance=" .. tostring(abundance) .. ")")
end

Events.OnGameStart.Add(Woodcutting.AdjustNatureAbundance)
Events.OnServerStarted.Add(Woodcutting.AdjustNatureAbundance)

return Woodcutting
