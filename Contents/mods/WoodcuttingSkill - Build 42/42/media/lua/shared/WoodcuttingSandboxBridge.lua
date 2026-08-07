-- WoodcuttingSandboxBridge.lua (Shared)
-- Lê as Sandbox Options e injeta nos Settings do mod.
require "WoodcuttingSkillDefinitions"

Woodcutting.diag("WoodcuttingSandboxBridge:fileloaded", "WoodcuttingSandboxBridge.lua chunk executed (file is being loaded)")

local function applySandboxToSettings()
    Woodcutting = Woodcutting or {}
    Woodcutting.Settings = Woodcutting.Settings or {}

    local sv = SandboxVars and SandboxVars.Woodcutting or nil
    if not sv then
        Woodcutting.diag("applySandboxToSettings:nosandbox", "SandboxVars.Woodcutting is nil - keeping built-in defaults")
        -- Still derive the effective loot chances, so NatureAbundance applies even without a
        -- Woodcutting sandbox block.
        Woodcutting.AdjustNatureAbundance()
        return
    end

    -- Copia valores do SandboxVars para os Settings utilizados pelo mod
    local S = Woodcutting.Settings

    -- Dano
    if sv.damageBaseMultiplier ~= nil then S.damageBaseMultiplier = sv.damageBaseMultiplier end
    if sv.damagePerLevel       ~= nil then S.damagePerLevel       = sv.damagePerLevel       end
    if sv.damageMaxMultiplier  ~= nil then S.damageMaxMultiplier  = sv.damageMaxMultiplier  end
    if sv.oneHitLevelThreshold ~= nil then S.oneHitLevelThreshold = sv.oneHitLevelThreshold end
    if sv.oneHitTreeDamage     ~= nil then S.oneHitTreeDamage     = sv.oneHitTreeDamage     end
    if sv.onlyForAxes          ~= nil then S.onlyForAxes          = sv.onlyForAxes          end

    -- XP
    if sv.xpMultiplier         ~= nil then S.xpMultiplier         = sv.xpMultiplier         end
    if sv.axeXpPerHit          ~= nil then S.axeXpPerHit          = sv.axeXpPerHit          end
    if sv.treeFelledXp         ~= nil then S.treeFelledXp         = sv.treeFelledXp         end
    if sv.axeXpOnTreeFelled    ~= nil then S.axeXpOnTreeFelled    = sv.axeXpOnTreeFelled    end
    if sv.bushRemovedXp        ~= nil then S.bushRemovedXp        = sv.bushRemovedXp        end

    -- Extra Looting.
    -- Writes go into BaseChanceOfExtrasOneIn, never into Settings.ChanceOfExtrasOneIn:
    -- AdjustNatureAbundance() derives the effective table from the base one. Writing into the
    -- effective table would let the abundance multiplier compound, and would make the result
    -- depend on whether this function or AdjustNatureAbundance ran first.
    local C = Woodcutting.BaseChanceOfExtrasOneIn or {}
    Woodcutting.BaseChanceOfExtrasOneIn = C
    if sv.FruitTreeExtra ~= nil then C.FruitTreeExtra = sv.FruitTreeExtra end
    if sv.Winter         ~= nil then C.Winter         = sv.Winter         end
    if sv.Pinecone       ~= nil then C.Pinecone       = sv.Pinecone       end
    if sv.PineTreeExtra  ~= nil then C.PineTreeExtra  = sv.PineTreeExtra  end
    if sv.Log            ~= nil then C.Log            = sv.Log            end
    if sv.TreeBranch     ~= nil then C.TreeBranch     = sv.TreeBranch     end
    if sv.Twigs          ~= nil then C.Twigs          = sv.Twigs          end

    if sv.cumulatedForagingAndWoodcuttingSkillLevelForFruit ~= nil then
        S.cumulatedForagingAndWoodcuttingSkillLevelForFruit = sv.cumulatedForagingAndWoodcuttingSkillLevelForFruit
    end

    -- Recompute the effective chances now that the base table is final. Must run after the copy
    -- above, which is why it is called here rather than relying on event ordering.
    Woodcutting.AdjustNatureAbundance()
end

-- Aplica em SP/MP (client + server) nos momentos confiáveis:
Events.OnGameStart.Add(applySandboxToSettings)
Events.OnServerStarted.Add(applySandboxToSettings)
Events.OnInitGlobalModData.Add(applySandboxToSettings)  -- fallback em alguns fluxos
