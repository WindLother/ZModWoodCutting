-- WoocuttingHitTree.lua (Server / XPSystem)
--
-- Registers the XP and condition rewards. The events that drive them are raised by
-- shared/B42_TimedActionPacthes.lua, NOT by Events.OnWeaponHitTree - see the header of that file
-- for why (Build 42 chops trees through a timed action that fires no Lua event).
--
-- This file lives under server/, so it does not load on a multiplayer client. Every dispatch that
-- reaches it has already been gated on `not isClient()`, so all grants here are
-- server-authoritative.

require "WoodcuttingSkillDefinitions"

local function addWoodcuttingXP(character, handWeapon)
    if not character or not handWeapon or handWeapon:getType() == "BareHands" then return end

    local woodcuttingPerk = Woodcutting.getPerk()
    if not woodcuttingPerk then
        Woodcutting.diag("addWoodcuttingXP:noperk", "addWoodcuttingXP() bailed: Woodcutting.getPerk() returned nil")
        return
    end

    local settings = Woodcutting.Settings
    local multiplier = settings.xpMultiplier or 1
    local isAxe = Woodcutting.isAxe(handWeapon)
    local xpAmount = (isAxe and 0.2 or 0.1) * multiplier
    character:getXp():AddXP(woodcuttingPerk, xpAmount)
    Woodcutting.diag("addWoodcuttingXP:granted", "Granted " .. tostring(xpAmount) .. " Woodcutting XP (isAxe=" .. tostring(isAxe) .. ", multiplier=" .. tostring(multiplier) .. ")")

    if isAxe and (settings.axeXpPerHit or 0) > 0 then
        character:getXp():AddXP(Perks.Axe, settings.axeXpPerHit * multiplier)
    end

    -- Build 42 gates chopping on ItemTag.CHOP_TREE, but this mod's balance keys off
    -- WeaponCategory.AXE. Those sets are not identical. Log the first mismatch we ever see so the
    -- question is answered from real play rather than guessed at. See AGENTS.md §10 item 11.
    if not isAxe and Woodcutting.canChopTree(handWeapon) then
        Woodcutting.diag("chopTreeNotAxe:" .. tostring(handWeapon:getFullType()),
            "Weapon " .. tostring(handWeapon:getFullType()) .. " has ItemTag.CHOP_TREE but is not "
            .. "WeaponCategory.AXE - it chops trees but receives no axe bonuses from this mod")
    end
end

-- Per tree hit, chance to save 1 weapon condition point scales with Woodcutting level.
-- Base: 1 in 10 at level 1; 1 in 2 (capped) at level 9+.
-- bonusConditionLowerOneInPerLevel controls how fast the OneIn value drops per level.
local function saveWeaponCondition(character, weapon)
    if not character or not weapon then return end
    if not instanceof(weapon, "HandWeapon") then return end
    local woodcuttingPerk = Woodcutting.getPerk()
    if not woodcuttingPerk then return end
    local lvl = character:getPerkLevel(woodcuttingPerk) or 0
    if lvl == 0 then return end
    local S      = Woodcutting.Settings
    local bonus  = lvl * (S.bonusConditionLowerOneInPerLevel or 0)
    local oneIn  = math.max(2, math.floor(10 - bonus))
    if ZombRand(oneIn) == 0 then
        local curCond = weapon:getCondition()
        local maxCond = weapon:getConditionMax()
        if curCond < maxCond then
            weapon:setCondition(curCond + 1)
        end
    end
end

local function addTreeFelledXP(character, weapon)
    if not character or not weapon then return end

    local woodcuttingPerk = Woodcutting.getPerk()
    if not woodcuttingPerk then
        Woodcutting.diag("addTreeFelledXP:noperk", "addTreeFelledXP() bailed: Woodcutting.getPerk() returned nil")
        return
    end

    local settings = Woodcutting.Settings
    local multiplier = settings.xpMultiplier or 1
    local woodcuttingXp = (settings.treeFelledXp or 0) * multiplier
    local axeXp = (settings.axeXpOnTreeFelled or 0) * multiplier

    if woodcuttingXp > 0 then
        character:getXp():AddXP(woodcuttingPerk, woodcuttingXp)
        Woodcutting.diag("addTreeFelledXP:granted", "Granted " .. tostring(woodcuttingXp) .. " Woodcutting XP on tree felled")
    end
    if axeXp > 0 and Woodcutting.isAxe(weapon) then
        character:getXp():AddXP(Perks.Axe, axeXp)
    end

    local modData = character:getModData()
    modData.treekills = (modData.treekills or 0) + 1
    character:transmitModData()
end

-- Bushes are cheaper than trees: a flat, smaller grant, and no axe XP.
local function addBushRemovedXP(character, weapon)
    if not character then return end

    local woodcuttingPerk = Woodcutting.getPerk()
    if not woodcuttingPerk then return end

    local settings = Woodcutting.Settings
    local xpAmount = (settings.bushRemovedXp or 0) * (settings.xpMultiplier or 1)
    if xpAmount > 0 then
        character:getXp():AddXP(woodcuttingPerk, xpAmount)
        Woodcutting.diag("addBushRemovedXP:granted", "Granted " .. tostring(xpAmount) .. " Woodcutting XP on bush removed")
    end

    local modData = character:getModData()
    modData.bushkills = (modData.bushkills or 0) + 1
    character:transmitModData()
end

Woodcutting.addOnTreeHit(addWoodcuttingXP)
Woodcutting.addOnTreeHit(saveWeaponCondition)
Woodcutting.addOnTreeFelled(addTreeFelledXP)
Woodcutting.addOnBushRemoved(addBushRemovedXP)
