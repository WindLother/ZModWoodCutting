-- Build 42 timed-action compatibility patches.
--
-- ██ WHY THIS FILE OWNS THE XP HOOK ██
--
-- In Build 41, chopping a tree ran through the combat path, so Events.OnWeaponHitTree fired on
-- every swing and every woodcutting mod hung off it.
--
-- In Build 42.20.2 it does not. Verified by disassembling projectzomboid.jar:
--
--   * ISChopTreeAction:animEvent("ChopTree")  ->  tree:WeaponHit(character, axe)
--   * IsoTree.WeaponHit triggers NO Lua event at all. It runs damageCheck, WeaponHitEffects,
--     reads getTreeDamage(), applies the AXEMAN trait x1.5, subtracts, and topples at <= 0.
--   * The string "OnWeaponHitTree" exists in exactly two classes in the whole jar:
--     LuaEventManager (registration) and CombatManager (the only trigger), and that trigger sits
--     in processMaintenanceCheck behind isActuallyAttackingWithMeleeWeapon(). A timed action is
--     not an attack.
--
-- So OnWeaponHitTree fires only when a player *melee swings* at a tree, never for the Chop Tree
-- action. We therefore hook the timed action directly and route both paths into
-- Woodcutting.onTreeHit / onTreeFelled.
--
-- Do not "simplify" this back to Events.OnWeaponHitTree. It will silently award no XP.

require "WoodcuttingSkillDefinitions"

Woodcutting.diag("B42_TimedActionPacthes:fileloaded", "B42_TimedActionPacthes.lua chunk executed (file is being loaded)")

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function getWoodcuttingLevel(character)
    local perk = Woodcutting.getPerk()
    if not character or not perk then return 0 end
    return character:getPerkLevel(perk) or 0
end

local function scaleFiniteDuration(action, speedPerLevel, minimumMultiplier)
    local duration = action and action.maxTime
    if not duration or duration < 0 then return end

    local level = getWoodcuttingLevel(action.character)
    local multiplier = math.max(minimumMultiplier, 1.0 - speedPerLevel * level)
    action.maxTime = math.max(5, math.floor(duration * multiplier + 0.5))
end

local function scaleCalories(action)
    local base = action and action.caloriesModifier
    if not base or base <= 0 then return end

    local level = getWoodcuttingLevel(action.character)
    local saved = clamp((Woodcutting.Settings.caloriesSavedModifierPerLevel or 0) * level / 10, 0, 0.9)
    action.caloriesModifier = base * (1.0 - saved)
end

local function refundEndurance(character, before, savedPerLevel)
    if not character or not before then return end
    local stats = character:getStats()
    if not stats then return end

    local after = stats:get(CharacterStat.ENDURANCE)
    local spent = math.max(0, before - after)
    if spent <= 0 then return end

    local level = getWoodcuttingLevel(character)
    local savedFraction = clamp(savedPerLevel * level, 0, 0.9)
    stats:add(CharacterStat.ENDURANCE, spent * savedFraction)

    local threshold = Woodcutting.Settings.skillLevelForNoSevereExhaustion
    if threshold and level >= threshold
        and stats:get(CharacterStat.ENDURANCE) < 0.15 then
        stats:set(CharacterStat.ENDURANCE, 0.15)
    end
end

local function getTreeSize(tree)
    if not tree then return nil end
    local hasOk, has = pcall(function() return tree:hasProperty("TreeSize") end)
    if not hasOk or not has then return nil end
    local ok, value = pcall(function() return tree:getProperty("TreeSize") end)
    return (ok and value) and tonumber(value) or nil
end

local function getTreeSpriteName(tree)
    if not tree then return nil end
    local ok, sprite = pcall(function() return tree:getSprite() end)
    if not ok or not sprite then return nil end
    local okName, name = pcall(function() return sprite:getName() end)
    return okName and name or nil
end

local function requireClass(className)
    local loaded = pcall(require, "TimedActions/" .. className)
    if not loaded then
        Woodcutting.diag("patch:requirefail:" .. className, "require('TimedActions/" .. className .. "') errored - " .. className .. " cannot be patched")
        return nil
    end

    local class = _G[className]
    if not class then
        Woodcutting.diag("patch:noclass:" .. className, "_G['" .. className .. "'] is nil after require - class is not a global, patch cannot apply")
        return nil
    end
    return class
end

local function patchTimedAction(className, speedPerLevel, minimumMultiplier, savedPerLevel)
    local class = requireClass(className)
    if not class then return end
    if class.__WDC_patched then return end
    class.__WDC_patched = true
    Woodcutting.diag("patch:applied:" .. className, "patchTimedAction(" .. className .. ") patched successfully")

    local originalNew = class.new
    local originalUseEndurance = class.useEndurance

    function class:new(character, ...)
        local action = originalNew(self, character, ...)
        scaleFiniteDuration(action, speedPerLevel, minimumMultiplier)
        scaleCalories(action)
        return action
    end

    if originalUseEndurance then
        function class:useEndurance()
            local stats = self.character and self.character:getStats()
            local before = stats and stats:get(CharacterStat.ENDURANCE) or nil
            originalUseEndurance(self)
            refundEndurance(self.character, before, savedPerLevel)
        end
    end
end

-- ============================================================================
-- Chop Tree: the XP hook
-- ============================================================================
--
-- Vanilla ISChopTreeAction:animEvent already contains the authoritative felled test - it checks
-- self.tree:getObjectIndex() == -1 right after WeaponHit and force-completes the action. We reuse
-- exactly that test after delegating, which is why this needs no OnTick polling and no guessing
-- about which tree was hit: self.tree IS the tree.
--
-- Tree size and sprite must be read BEFORE delegating, because a lethal swing removes the tree.

local function patchChopTreeAction()
    local class = requireClass("ISChopTreeAction")
    if not class then return end
    if class.__WDC_animPatched then return end
    class.__WDC_animPatched = true
    Woodcutting.diag("patch:applied:ISChopTreeAction:animEvent", "ISChopTreeAction:animEvent patched successfully - Woodcutting XP hook is live")

    local originalAnimEvent = class.animEvent

    function class:animEvent(event, parameter)
        -- isClient() is true only on a multiplayer client, where vanilla does nothing but play
        -- effects. Singleplayer and the server both fall through, matching vanilla's own guard.
        local ours = event == "ChopTree" and self.axe and self.tree and not isClient()

        local treeSize, spriteName
        if ours then
            treeSize = getTreeSize(self.tree)
            spriteName = getTreeSpriteName(self.tree)
            -- Refresh the scaled TreeDamage immediately before WeaponHit reads getTreeDamage().
            -- This is also what makes damage scaling work on a dedicated server, where
            -- OnEquipPrimary is not guaranteed to fire for a remote player.
            if Woodcutting.prepareWeaponForTreeHit then
                Woodcutting.prepareWeaponForTreeHit(self.character, self.axe)
            end
        end

        originalAnimEvent(self, event, parameter)

        if not ours then return end

        Woodcutting.onTreeHit(self.character, self.axe, self.tree, treeSize, spriteName)

        -- The ChopTree anim event repeats for as long as the action runs. Vanilla force-completes
        -- on the swing that topples the tree, but the flag makes the felled dispatch exactly-once
        -- regardless of whether that force-complete is honoured on this frame.
        if self.tree:getObjectIndex() == -1 and not self.__WDC_felled then
            self.__WDC_felled = true
            Woodcutting.diag("treeFelled:detected", "Tree felled detected in ISChopTreeAction:animEvent (size=" .. tostring(treeSize) .. ", sprite=" .. tostring(spriteName) .. ")")
            Woodcutting.onTreeFelled(self.character, self.axe, self.tree, treeSize, spriteName)
        end
    end
end

-- ============================================================================
-- Remove Bush
-- ============================================================================
--
-- Hooked on complete(), not animEvent(): the "Chop" anim event repeats for the whole duration of
-- the action, so awarding there would pay out several times for one bush. complete() runs once,
-- and it is where vanilla actually removes the bush.
--
-- No isClient() guard is needed. LuaTimedActionNew.complete() returns before invoking the Lua
-- complete function when GameClient.client is true, so this body only ever runs in singleplayer
-- or on the server - which is exactly where the grant belongs.

local function patchRemoveBushAction()
    local class = requireClass("ISRemoveBush")
    if not class then return end
    if class.__WDC_completePatched then return end
    class.__WDC_completePatched = true
    Woodcutting.diag("patch:applied:ISRemoveBush:complete", "ISRemoveBush:complete patched successfully")

    local originalComplete = class.complete

    function class:complete()
        local result = originalComplete(self)
        Woodcutting.onBushRemoved(self.character, self.weapon)
        return result
    end
end

local function applyPatches()
    Woodcutting.diag("applyPatches:ran", "applyPatches() ran")

    local settings = Woodcutting.Settings or {}
    local savedPerLevel = settings.enduranceSavedPerPerkLevel or 0.07

    -- Tree chopping has duration -1 in Build 42 and must remain animation-driven, so speedPerLevel
    -- is 0 here. The per-level benefit comes from tree damage instead.
    patchTimedAction("ISChopTreeAction", 0, 1, savedPerLevel)
    patchTimedAction("ISRemoveBush", 0.10, 0.30, savedPerLevel)

    patchChopTreeAction()
    patchRemoveBushAction()
end

Events.OnGameBoot.Add(applyPatches)
Events.OnGameStart.Add(applyPatches)
Events.OnServerStarted.Add(applyPatches)

-- Secondary path: a plain melee swing that lands on a tree still fires OnWeaponHitTree from
-- CombatManager, and still damages the tree. The engine does not tell us which tree, so `tree` is
-- nil here and felled-detection is not possible on this path.
Events.OnWeaponHitTree.Add(function(character, weapon)
    Woodcutting.diag("OnWeaponHitTree:fired", "OnWeaponHitTree fired (melee swing path) weapon=" .. tostring(weapon and weapon:getType()))
    Woodcutting.onTreeHit(character, weapon, nil, nil, nil)
end)
