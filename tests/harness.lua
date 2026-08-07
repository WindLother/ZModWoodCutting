-- Behavioural harness for WoodcuttingSkill_B42.
--
-- Loads the REAL vanilla ISBaseObject / ISBaseTimedAction / ISChopTreeAction / ISRemoveBush from
-- the Build 42.20.2 install, then the REAL mod Lua on top, with the Project Zomboid globals
-- stubbed. Nothing under test is reimplemented: the wrappers are exercised against vanilla's own
-- animEvent() and complete() bodies.
--
-- What it cannot prove: that the engine raises "ChopTree"/"Chop" anim events at the rates assumed,
-- or anything about rendering, networking or persistence. Those need the game.

-- Run from the repository root:
--     lua tests/harness.lua
-- Override either path with the PZ_DIR / MOD_DIR environment variables.
local PZ  = os.getenv("PZ_DIR") or "G:/SteamLibrary/steamapps/common/ProjectZomboid"
local MOD = os.getenv("MOD_DIR") or "Contents/mods/WoodcuttingSkill - Build 42"

local VANILLA = PZ .. "/media/lua"
local MODLUA  = MOD .. "/42/media/lua"

--==========================================================================
-- test plumbing
--==========================================================================
local pass, fail, failures = 0, 0, {}
local function check(name, cond, detail)
    if cond then
        pass = pass + 1
        print(string.format("  PASS  %s", name))
    else
        fail = fail + 1
        failures[#failures + 1] = name
        print(string.format("  FAIL  %s   %s", name, detail or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, string.format("got %s, want %s", tostring(got), tostring(want)))
end
local function approx(name, got, want)
    check(name, math.abs(got - want) < 1e-6, string.format("got %s, want %s", tostring(got), tostring(want)))
end

--==========================================================================
-- Project Zomboid global stubs
--==========================================================================
local Env = { isClient = false, isServer = false }

function isClient() return Env.isClient end
function isServer() return Env.isServer end
function isTable(o) return type(o) == "table" end

local rngQueue = {}
function ZombRand(n) -- deterministic: 0 unless a value was queued
    if #rngQueue > 0 then return table.remove(rngQueue, 1) % n end
    return 0
end

Perks = {}
Perks.MAX = { id = "MAX" }
Perks.Woodcutting     = { id = "Woodcutting" }
Perks.Axe             = { id = "Axe" }
Perks.PlantScavenging = { id = "PlantScavenging" }
Perks.Farming         = { id = "Farming" }
function Perks.FromString(s) return Perks[s] or Perks.MAX end
PerkFactory = { getPerkFromName = function(n) return Perks[n] end }

WeaponCategory = { AXE = "AXE", LONG_BLADE = "LB", SMALL_BLADE = "SB" }
ItemTag        = { CHOP_TREE = "CHOP_TREE" }
CharacterStat  = { ENDURANCE = "ENDURANCE" }
Metabolics     = { ForestryAxe = "ForestryAxe", DiggingSpade = "DiggingSpade" }
CharacterActionAnims = { Chop_tree = "Chop_tree" }
IsoFlagType    = { canBeCut = "canBeCut" }
CharacterProfession = { LUMBERJACK = "LUMBERJACK", PARK_RANGER = "PR", FARMER = "F" }
CharacterTrait = { GARDENER = "G", HIKER = "H", SCOUT = "S", AXEMAN = "A" }

SandboxVars = { NatureAbundance = 3 }

function getGameTime() return { getMonth = function() return 5 end } end -- June, not winter
ScriptManager = { instance = { FindItem = function(_, t) return { t } end } }
function getActivatedMods() return { contains = function() return false end } end
function getCell() return { getGridSquare = function() return nil end } end
function addSound() end
function emulateAnimEvent() end
function syncPlayerStats() end
function showDebugInfoInChat() end
function getText(k) return k end
function instanceof(o, t) return type(o) == "table" and o.__javaType == t end

-- Events
Events = {}
local eventNames = {
    "OnGameBoot", "OnGameStart", "OnServerStarted", "OnInitGlobalModData",
    "OnWeaponHitTree", "OnEquipPrimary", "LevelPerk", "OnTick",
}
for _, n in ipairs(eventNames) do
    local handlers = {}
    Events[n] = {
        Add = function(f) handlers[#handlers + 1] = f end,
        Remove = function(f)
            for i, g in ipairs(handlers) do if g == f then table.remove(handlers, i) break end end
        end,
        __fire = function(...)
            for _, f in ipairs(handlers) do
                local ok, err = pcall(f, ...)
                if not ok then print("    [event " .. n .. " handler error] " .. tostring(err)) end
            end
        end,
    }
end

-- require
local loaded = {}
local searchRoots = {
    VANILLA .. "/shared/", VANILLA .. "/client/", VANILLA .. "/server/",
    MODLUA .. "/shared/", MODLUA .. "/client/", MODLUA .. "/server/",
}
function require(name)
    if loaded[name] then return loaded[name] end
    loaded[name] = true
    for _, root in ipairs(searchRoots) do
        local path = root .. name .. ".lua"
        local fh = io.open(path, "r")
        if fh then
            local src = fh:read("a")
            fh:close()
            -- Kahlua is Lua 5.1, where assigning to a numeric-for control variable is legal and
            -- has no effect on iteration. Lua 5.4+ makes it const and refuses to compile.
            -- ISRemoveBush.lua:152 does exactly that (vanilla even tags it "FIXME: illegal in
            -- Lua"). Neutralising it matches 5.1 semantics exactly - the assignment was already
            -- dead - and is the only source edit this harness performs.
            src = src:gsub("\n(%s*)i = i %- 1;", "\n%1--[[harness: no-op under 5.1]]")
            local chunk, err = load(src, "@" .. path)
            if not chunk then error("parse " .. path .. ": " .. tostring(err)) end
            local r = chunk()
            loaded[name] = r or true
            return loaded[name]
        end
    end
    error("require: not found: " .. name)
end

--==========================================================================
-- fake world objects
--==========================================================================
local function newWeapon(fullType, isAxe, treeDamage, chopTag)
    local md = {}
    return {
        __javaType = "HandWeapon",
        getType = function() return fullType end,
        getFullType = function() return "Base." .. fullType end,
        getModData = function() return md end,
        getScriptItem = function()
            return { containsWeaponCategory = function(_, c) return isAxe and c == WeaponCategory.AXE end }
        end,
        hasTag = function(_, t) return chopTag and t == ItemTag.CHOP_TREE end,
        getTreeDamage = function(self) return self.__treeDamage end,
        setTreeDamage = function(self, v) self.__treeDamage = v end,
        __treeDamage = treeDamage or 35,
        getCondition = function() return 8 end,
        getConditionMax = function() return 10 end,
        setCondition = function() end,
        isUseEndurance = function() return false end,
        isTwoHandWeapon = function() return false end,
        getWeight = function() return 3 end,
        getFatigueMod = function() return 1 end,
        getEnduranceMod = function() return 1 end,
        getConditionLowerChance = function() return 5 end,
        damageCheck = function() return false end,
        checkSyncItemFields = function() end,
        setJobType = function() end,
        setJobDelta = function() end,
        isBroken = function() return false end,
    }
end

local function newTree(health, size, sprite)
    local t
    t = {
        __javaType = "IsoTree",
        __health = health,
        __index_ = 0,
        getObjectIndex = function() return t.__index_ end,
        hasProperty = function(_, p) return p == "TreeSize" end,
        getProperty = function(_, p) return tostring(size) end,
        getSprite = function() return { getName = function() return sprite end } end,
        setHealth = function(_, h) t.__health = h end,
        WeaponHit = function(_, _, weapon)  -- mirrors IsoTree.WeaponHit: subtract TreeDamage, topple at <=0
            t.__health = t.__health - weapon:getTreeDamage()
            if t.__health <= 0 then t.__index_ = -1 end
        end,
        WeaponHitEffects = function() end,
        setHighlighted = function() end,
    }
    return t
end

local function newSquare(hasBush)
    local objs = {}
    if hasBush then
        objs[1] = { getProperties = function() return { has = function(_, f) return f == IsoFlagType.canBeCut end } end,
                    getSprite = function() return { getProperties = function() return { has = function(_, f) return f == IsoFlagType.canBeCut end } end } end,
                    getAttachedAnimSprite = function() return nil end }
    end
    return {
        getX = function() return 10 end, getY = function() return 10 end, getZ = function() return 0 end,
        getObjects = function() return { size = function() return #objs end, get = function(_, i) return objs[i + 1] end } end,
        transmitRemoveItemFromSquare = function(_, o) for i, v in ipairs(objs) do if v == o then table.remove(objs, i) break end end end,
        AddWorldInventoryItem = function() end,
        playSound = function() end,
        removeErosionObject = function() end,
        HasTree = function() return false end,
    }
end

local function newCharacter(level)
    local md, xp = {}, {}
    local inv = {}
    local c
    c = {
        __javaType = "IsoPlayer",
        __xp = xp, __level = level or 0,
        getModData = function() return md end,
        transmitModData = function() c.__transmitted = (c.__transmitted or 0) + 1 end,
        getPerkLevel = function(_, p) return (p == Perks.Woodcutting) and c.__level or 0 end,
        getXp = function()
            return { AddXP = function(_, perk, amount) xp[perk.id] = (xp[perk.id] or 0) + amount end }
        end,
        getStats = function()
            return { get = function() return 0.5 end, add = function() end, set = function() end, remove = function() end }
        end,
        getInventory = function() return { AddItem = function(_, t) inv[#inv + 1] = t end } end,
        __inv = inv,
        getPrimaryHandItem = function() return c.__primary end,
        getSecondaryHandItem = function() return nil end,
        getCurrentSquare = function() return c.__square end,
        getDescriptor = function() return { isCharacterProfession = function() return false end } end,
        addCombatMuscleStrain = function() end,
        addBackMuscleStrain = function() end,
        faceThisObject = function() end,
        faceLocation = function() end,
        shouldBeTurning = function() return false end,
        isTimedActionInstant = function() return false end,
        isEnduranceSufficientForAction = function() return true end,
        setMetabolicTarget = function() end,
        getSpriteDef = function() return { getFrame = function() return 0 end } end,
        getFatigueMod = function() return 1 end,
        getMaintenanceMod = function() return 1 end,
    }
    return c
end

--==========================================================================
-- load vanilla, then the mod
--==========================================================================
print("Loading vanilla timed actions...")
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISChopTreeAction"
require "TimedActions/ISRemoveBush"

print("Loading mod Lua...")
require "WoodcuttingSkillDefinitions"
require "WoodcuttingSandboxBridge"
require "B42_TimedActionPacthes"
require "Woodcutting/WoodCuttingDamagePerLevel"
require "Woodcutting/WoodcuttingExtraLoot"
require "XpSystem/WoocuttingHitTree"

print("Firing OnGameBoot / OnServerStarted...\n")
Events.OnGameBoot.__fire()
Events.OnServerStarted.__fire()

--==========================================================================
-- scenarios
--==========================================================================
local S = Woodcutting.Settings

local function chopAction(character, tree)
    local a = ISChopTreeAction:new(character, tree)
    a.axe = character:getPrimaryHandItem()
    a.netAction = { forceComplete = function() end }
    a.action = { forceComplete = function() end, forceStop = function() end }
    a.forceComplete = function() end
    return a
end

print("[1] Singleplayer: chopping a tree grants XP per swing and fells exactly once")
do
    Env.isClient, Env.isServer = false, false
    S.oneHitLevelThreshold = 99          -- keep one-hit out of this scenario
    local ch = newCharacter(0)
    ch.__primary = newWeapon("Axe", true, 35, true)
    local tree = newTree(100, 7, "e_virginia_pine_1_0")
    local a = chopAction(ch, tree)

    a:animEvent("ChopTree", nil)
    approx("XP after 1st swing", ch.__xp.Woodcutting or 0, 0.2)
    eq("tree still standing", tree:getObjectIndex(), 0)

    a:animEvent("ChopTree", nil)
    approx("XP after 2nd swing", ch.__xp.Woodcutting or 0, 0.4)

    a:animEvent("ChopTree", nil)          -- 3 x 35 damage = 105 > 100 -> topples
    eq("tree felled", tree:getObjectIndex(), -1)
    approx("XP includes treeFelledXp", ch.__xp.Woodcutting or 0, 0.6 + S.treeFelledXp)
    eq("treekills", ch:getModData().treekills, 1)
    check("axe XP granted", (ch.__xp.Axe or 0) > 0)

    local before = ch.__xp.Woodcutting
    a:animEvent("ChopTree", nil)          -- latch must stop a second felled payout
    approx("no second felled payout", ch.__xp.Woodcutting - before, 0.2)
    eq("treekills still 1", ch:getModData().treekills, 1)
end

print("\n[2] Multiplayer client: the timed action grants nothing")
do
    Env.isClient, Env.isServer = true, false
    local ch = newCharacter(0)
    ch.__primary = newWeapon("Axe", true, 35, true)
    local a = chopAction(ch, newTree(100, 7, "x"))
    a:animEvent("ChopTree", nil)
    eq("no XP on MP client", ch.__xp.Woodcutting, nil)
    Env.isClient = false
end

print("\n[3] Tree metadata is sampled before the tree is removed")
do
    Env.isClient, Env.isServer = false, false
    local seen = {}
    Woodcutting.addOnTreeFelled(function(_, _, _, size, sprite) seen.size, seen.sprite = size, sprite end)
    local ch = newCharacter(0)
    ch.__primary = newWeapon("Axe", true, 500, true)   -- one swing kills
    local a = chopAction(ch, newTree(100, 8, "e_canadianhemlock_1_0"))
    a:animEvent("ChopTree", nil)
    eq("treeSize survived removal", seen.size, 8)
    eq("sprite survived removal", seen.sprite, "e_canadianhemlock_1_0")
end

print("\n[4] Wall vines vs bushes")
do
    Env.isClient, Env.isServer = false, true
    -- bush
    local ch = newCharacter(0)
    ch.__primary = newWeapon("Axe", true, 35, true)
    local bush = ISRemoveBush:new(ch, newSquare(true), false)
    bush.weapon = ch.__primary
    bush:complete()
    approx("bush grants bushRemovedXp", ch.__xp.Woodcutting or 0, S.bushRemovedXp)
    eq("bushkills 1", ch:getModData().bushkills, 1)

    -- wall vine
    local ch2 = newCharacter(0)
    ch2.__primary = newWeapon("Axe", true, 35, true)
    local vine = ISRemoveBush:new(ch2, newSquare(false), true)
    vine.weapon = ch2.__primary
    vine:complete()
    eq("wall vine grants no XP", ch2.__xp.Woodcutting, nil)
    eq("wall vine leaves bushkills unset", ch2:getModData().bushkills, nil)

    -- stale square: not a wall vine, but nothing cuttable left
    local ch3 = newCharacter(0)
    ch3.__primary = newWeapon("Axe", true, 35, true)
    local stale = ISRemoveBush:new(ch3, newSquare(false), false)
    stale.weapon = ch3.__primary
    stale:complete()
    eq("stale square grants no XP", ch3.__xp.Woodcutting, nil)
    eq("stale square leaves bushkills unset", ch3:getModData().bushkills, nil)
end

print("\n[5] oneHitLevelThreshold edges")
do
    Env.isClient, Env.isServer = false, false
    S.oneHitTreeDamage = 2000

    S.oneHitLevelThreshold = 0
    local ch = newCharacter(0)
    local w = newWeapon("Axe", true, 35, true)
    ch.__primary = w
    Woodcutting.prepareWeaponForTreeHit(ch, w)
    eq("threshold 0 -> one-hit at level 0", w:getTreeDamage(), 2000)

    S.oneHitLevelThreshold = 99
    local ch2 = newCharacter(10)
    local w2 = newWeapon("Axe", true, 35, true)
    ch2.__primary = w2
    Woodcutting.prepareWeaponForTreeHit(ch2, w2)
    check("threshold 99 -> never one-hit at level 10", w2:getTreeDamage() < 2000,
          "treeDamage=" .. tostring(w2:getTreeDamage()))
    -- (35 base + 2/level * 10) * (1.0 * (1 + 0.15*10)) = 55 * 2.5 = 137.5 -> 138
    eq("threshold 99 -> scaled damage", w2:getTreeDamage(), 138)

    S.oneHitLevelThreshold = 6
    local ch3 = newCharacter(5)
    local w3 = newWeapon("Axe", true, 35, true)
    Woodcutting.prepareWeaponForTreeHit(ch3, w3)
    check("level 5 below threshold 6", w3:getTreeDamage() < 2000)
    local ch4 = newCharacter(6)
    local w4 = newWeapon("Axe", true, 35, true)
    Woodcutting.prepareWeaponForTreeHit(ch4, w4)
    eq("level 6 at threshold 6", w4:getTreeDamage(), 2000)
end

print("\n[6] Base TreeDamage is snapshotted once, never re-derived")
do
    S.oneHitLevelThreshold = 99
    local w = newWeapon("Axe", true, 35, true)
    local ch = newCharacter(2)
    Woodcutting.prepareWeaponForTreeHit(ch, w)
    local first = w:getTreeDamage()
    for _ = 1, 20 do Woodcutting.prepareWeaponForTreeHit(ch, w) end
    eq("no ratcheting over 20 applications", w:getTreeDamage(), first)
end

print("\n[7] Nature abundance is idempotent and actually applies")
do
    SandboxVars.NatureAbundance = 1                       -- very poor, x1.2
    Woodcutting.AdjustNatureAbundance()
    local once = Woodcutting.Settings.ChanceOfExtrasOneIn.Log
    Woodcutting.AdjustNatureAbundance()
    Woodcutting.AdjustNatureAbundance()
    eq("idempotent across repeated calls", Woodcutting.Settings.ChanceOfExtrasOneIn.Log, once)
    eq("very poor scales 40 -> 48", once, 48)
    SandboxVars.NatureAbundance = 5                       -- very abundant, x0.8
    Woodcutting.AdjustNatureAbundance()
    eq("very abundant scales 40 -> 32", Woodcutting.Settings.ChanceOfExtrasOneIn.Log, 32)
    SandboxVars.NatureAbundance = 3
    Woodcutting.AdjustNatureAbundance()
    eq("normal leaves 40", Woodcutting.Settings.ChanceOfExtrasOneIn.Log, 40)
end

print("\n[8] Melee-swing path still awards XP")
do
    Env.isClient, Env.isServer = false, false
    local ch = newCharacter(0)
    local w = newWeapon("Axe", true, 35, true)
    Events.OnWeaponHitTree.__fire(ch, w)
    approx("OnWeaponHitTree grants XP", ch.__xp.Woodcutting or 0, 0.2)
end

print(string.format("\n================  %d passed, %d failed  ================", pass, fail))
for _, f in ipairs(failures) do print("   failed: " .. f) end
os.exit(fail == 0 and 0 or 1)
