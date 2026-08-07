-- Server-authoritative tree damage scaling for Build 42.19.

require "WoodcuttingSkillDefinitions"

local function shouldAffect(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return false end
    if weapon:getType() == "BareHands" then return false end
    return not Woodcutting.Settings.onlyForAxes or Woodcutting.isAxe(weapon)
end

local function computeMultiplier(level)
    local settings = Woodcutting.Settings
    local multiplier = (settings.damageBaseMultiplier or 1.0)
        * (1.0 + (settings.damagePerLevel or 0.0) * level)
    local cap = settings.damageMaxMultiplier
    if cap and cap > 0 then multiplier = math.min(multiplier, cap) end
    return multiplier
end

-- weapon:getTreeDamage() reflects whatever we last set on it, so re-deriving "base" from the
-- live value every hit is self-referential: any scaling we apply contaminates the next read.
-- (InventoryItemFactory, which would let us peek at a fresh reference item instead, is not
-- actually exposed to Lua here - confirmed by a "non-table: null" error - so that's not an option.)
-- Instead, snapshot the value exactly once per weapon instance, the first time we ever see it,
-- and freeze it for that item's lifetime. No ratcheting in either direction.
local function getBaseTreeDamage(weapon)
    local modData = weapon:getModData()
    if modData.__WDC_baseTreeDamage then
        return modData.__WDC_baseTreeDamage
    end

    local value = weapon:getTreeDamage()
    modData.__WDC_baseTreeDamage = value
    Woodcutting.diag("getBaseTreeDamage:snapshot:" .. tostring(weapon:getFullType()),
        "Snapshotted base TreeDamage = " .. tostring(value) .. " for " .. tostring(weapon:getFullType())
        .. " (frozen for this item's lifetime, never re-derived from later live readings)")
    return value
end

local function applyTreeDamageMult(player, weapon)
    if not player or not shouldAffect(weapon) then
        Woodcutting.diag("applyTreeDamageMult:notaffected", "applyTreeDamageMult() skipped weapon=" .. tostring(weapon and weapon:getType()) .. " (player nil or shouldAffect()==false)")
        return
    end

    local perk = Woodcutting.getPerk()
    if not perk then
        Woodcutting.diag("applyTreeDamageMult:noperk", "applyTreeDamageMult() bailed: Woodcutting.getPerk() returned nil")
        return
    end

    local level = player:getPerkLevel(perk) or 0
    local settings = Woodcutting.Settings
    local baseDamage = getBaseTreeDamage(weapon)

    -- The threshold is a plain level comparison, so its edges are deliberate and both are
    -- reachable from Sandbox: 0 means every tree falls in one swing from level 0, and anything
    -- above 10 can never be met, which is how the feature is switched off. The Sandbox maximum is
    -- 99 for exactly that reason - do not lower it back to 10 without also giving the option a
    -- separate disable sentinel.
    if settings.oneHitLevelThreshold and level >= settings.oneHitLevelThreshold then
        weapon:setTreeDamage(settings.oneHitTreeDamage or 2000)
        Woodcutting.diag("applyTreeDamageMult:onehit", "One-hit threshold reached (level=" .. tostring(level) .. "), setTreeDamage(" .. tostring(settings.oneHitTreeDamage or 2000) .. ")")
        return
    end

    local flatBonus = Woodcutting.isAxe(weapon)
        and ((settings.bonusAxeTreeDamagePerLevel or 0) * level)
        or 0
    local scaledDamage = math.max(1, math.floor(
        (baseDamage + flatBonus) * computeMultiplier(level) + 0.5
    ))
    weapon:setTreeDamage(scaledDamage)
    Woodcutting.diag("applyTreeDamageMult:applied", "weapon=" .. tostring(weapon:getType()) .. " level=" .. tostring(level)
        .. " baseDamage(cached)=" .. tostring(baseDamage) .. " flatBonus=" .. tostring(flatBonus)
        .. " multiplier=" .. tostring(computeMultiplier(level)) .. " -> setTreeDamage(" .. tostring(scaledDamage) .. ")")
end

function Woodcutting.prepareWeaponForTreeHit(player, weapon)
    applyTreeDamageMult(player, weapon)
end

local function onEquipPrimary(player, item)
    Woodcutting.diag("OnEquipPrimary:fired", "OnEquipPrimary event fired (item=" .. tostring(item and item:getType()) .. ")")
    applyTreeDamageMult(player, item)
end

local function onHitTree(character, weapon)
    Woodcutting.diag("OnWeaponHitTree:damageScaling:fired", "OnWeaponHitTree (damage scaling listener) fired")
    applyTreeDamageMult(character, weapon)
end

local function onLevelPerk(player, perk)
    Woodcutting.diag("LevelPerk:fired", "LevelPerk event fired (perk=" .. tostring(perk) .. ")")
    if perk ~= Woodcutting.getPerk() then return end
    applyTreeDamageMult(player, player and player:getPrimaryHandItem() or nil)
end

Events.OnEquipPrimary.Add(onEquipPrimary)
Events.OnWeaponHitTree.Add(onHitTree)
Events.LevelPerk.Add(onLevelPerk)
