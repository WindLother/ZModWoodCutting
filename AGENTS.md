# AGENTS.md — Woodcutting Skill (Build 42)

Operating manual for anyone (human or AI) modifying this mod. **Read this fully before editing any
file.** It describes the Build 42 mod layout, the engine facts that were verified by decompiling
the running game jar, and the known-broken areas that must not be "re-fixed" from memory.

- **Target game version:** Build 42.20.2 (`revision=ffe7a8a4b1`) — Build 42 only, no B41 tree here.
- **Mod version:** `1.1.0` · **Mod ID:** `WoodcuttingSkill_B42` · **Workshop ID:** `3559783131`
- **Lua namespace:** `Woodcutting` (single global table) · **Perk ID:** `Woodcutting`
- **Sandbox namespace:** `SandboxVars.Woodcutting`
- **Upstream:** overhaul of *Woodcutting Skill* by Champy (Workshop `2944004910`)
- **Reference docs:** [PZ Modding wiki](https://pzwiki.net/wiki/Modding) ·
  [Mod structure](https://pzwiki.net/wiki/Mod_structure) ·
  [Translation](https://pzwiki.net/wiki/Translation) ·
  [B42 JavaDocs](https://demiurgequantified.github.io/ProjectZomboidJavaDocs/)

---

## 1. Hard rules

These are not style preferences. Breaking any of them breaks the mod for players.

1. **Documentation never ships.** `README.md`, `AGENTS.md`, `.git/`, `.claude/` live at the
   repository root, **outside `Contents/`**. Only `Contents/` is uploaded to Steam. Never place a
   `.md` file inside `Contents/`.
2. **Never trust a Build 41 tutorial or the original Champy mod for API.** Build 42 moved tree
   chopping out of the combat path entirely (§5). Anything you remember about `OnWeaponHitTree`
   from B41 is wrong here.
3. **Verify Java API against the jar before calling it.** The recipe is in §11. Guessing is what
   produced the current XP bug.
4. **Translations are JSON only.** Build 42.20.2 reads *only*
   `media/lua/shared/Translate/<LANG>/<Type>.json`. Legacy `<Type>_<LANG>.txt` files are dead
   weight — see §7.
5. **Directory case matters.** `Translate`, not `translate`. `EN`, not `en`. Windows hides this;
   Linux dedicated servers do not. See §7.
6. **`%` must be written `%%` in every file the game parses as text** (translation JSON,
   `perks.txt`, `sandbox-options.txt`, `mod.info`, `workshop.txt`). Build 42.20.1/42.20.2 change,
   with a compatibility shim that *will be removed*. Lua `string.format` specifiers are exempt.
7. **Never overwrite a vanilla file.** This mod wraps timed-action classes in place; it must not
   add a file whose path shadows a vanilla path (e.g. `media/lua/shared/TimedActions/…`).
8. **All gameplay mutation must stay server-authoritative.** Build 42.20 re-enabled anti-cheat and
   specifically patched an XP exploit. Clients must never grant XP.

---

## 2. Repository layout

The repository root **is** the Steam Workshop staging folder
(`Zomboid/Workshop/WoodcuttingSkill_B42/`). Everything beside `Contents/` is ignored by the game
and by the in-game uploader.

```
WoodcuttingSkill_B42/                  <- repo root · NOT uploaded
├── README.md                          <- player-facing
├── AGENTS.md                          <- this file
├── workshop.txt                       <- Steam listing (BBCode). Description capped at 8000 bytes
├── preview.png                        <- 256x256 exactly, enforced by the game
├── .gitattributes                     <- LF for text, binary for png
├── .gitignore
├── .claude/                           <- Claude Code settings + CLAUDE.md
└── Contents/                          <- ██ THE ONLY FOLDER UPLOADED TO STEAM ██
    └── mods/
        └── WoodcuttingSkill - Build 42/
            ├── common/                <- ██ shared across all 42.x ██
            │   └── media/lua/shared/Translate/{EN,PT,PTBR,ES,FR}/{IG_UI,Sandbox,UI}.json
            └── 42/                    <- ██ resolves to game version 42.0 → loads on every 42.x ██
                ├── mod.info
                ├── poster.png
                └── media/
                    ├── perks.txt
                    ├── sandbox-options.txt
                    ├── ui/Traits/trait_woodcutter.png
                    └── lua/
                        ├── client/
                        │   └── IsCharacterTreeKills.lua      <- Kill Count mod integration
                        ├── server/
                        │   ├── Woodcutting/WoodCuttingDamagePerLevel.lua
                        │   ├── Woodcutting/WoodcuttingExtraLoot.lua
                        │   └── XpSystem/WoocuttingHitTree.lua   <- note the typo in the filename
                        └── shared/
                            ├── B42_TimedActionPacthes.lua       <- note the typo in the filename
                            ├── WoodcuttingSandboxBridge.lua
                            ├── WoodcuttingSkillDefinitions.lua
                            └── WoodcuttingSkillTraits.lua
```

### Why translations live in `common/`

`Translator` calls `tryFillMapFromFile` with `getCommonDir()` **first**, then `getVersionDir()`,
merging both — verified in the 42.20.2 bytecode. Translations are identical across all 42.x, so
`common/` is where they belong: a future `42.20/` folder then never has to duplicate them. It also
satisfies the wiki's rule that `common/` should exist.

### Version-folder resolution

Folder names resolve as `build.major`; the minor component is discarded. `42/` resolves to `42.0`,
so it loads for **every** 42.x release including 42.20.2. Only add a second folder (e.g. `42.20/`)
if you genuinely need different code for newer builds — it duplicates maintenance and is the most
common source of "my change didn't apply" confusion.

### `mod.info`

There is exactly one, at `Contents/mods/WoodcuttingSkill - Build 42/42/mod.info`. It declares
`name`, `id`, `author`, `modversion`, `poster`, `description`.

`ChooseGameInfo$Mod` also exposes `icon`, `versionMin`, `versionMax` and `require` if they are ever
needed. **Bump `modversion` on every release** — it is the only thing that tells a player or server
admin which build they are running, and bug reports are near-impossible to triage without it. Name
the file all-lowercase `mod.info`; Linux is case-sensitive.

---

## 3. What the mod actually does

| Feature | Implemented in | Depends on |
|---|---|---|
| Registers the `Woodcutting` perk | `42/media/perks.txt` | `CustomPerks` (§4) |
| Woodcutting + Axe XP per tree hit | `server/XpSystem/WoocuttingHitTree.lua` | `Woodcutting.onTreeHit` (§5) |
| Woodcutting + Axe XP on tree felled | `server/XpSystem/WoocuttingHitTree.lua` | `Woodcutting.onTreeFelled` (§5) |
| Woodcutting XP per bush removed | `server/XpSystem/WoocuttingHitTree.lua` | `Woodcutting.onBushRemoved` (§5) |
| Weapon-condition save per level | `server/XpSystem/WoocuttingHitTree.lua` | `Woodcutting.onTreeHit` |
| Tree-damage scaling / one-hit threshold | `server/Woodcutting/WoodCuttingDamagePerLevel.lua` | `OnEquipPrimary`, `LevelPerk`, + the `animEvent` hook |
| Extra loot on medium/large trees | `server/Woodcutting/WoodcuttingExtraLoot.lua` | `Woodcutting.onTreeFelled` |
| Endurance refund + no severe exhaustion | `shared/B42_TimedActionPacthes.lua` | `useEndurance` wrapper |
| Calorie saving per level | `shared/B42_TimedActionPacthes.lua` | `caloriesModifier` in the `new` wrapper |
| Faster bush removal per level | `shared/B42_TimedActionPacthes.lua` | `ISRemoveBush.new` wrapper |
| Felled-tree detection | `shared/B42_TimedActionPacthes.lua` | `ISChopTreeAction.animEvent` wrapper (§5) |
| Woodcutter trait + profession/trait XP boosts | `shared/WoodcuttingSkillTraits.lua` | `CharacterTraitDefinition` |
| Sandbox → `Woodcutting.Settings` | `shared/WoodcuttingSandboxBridge.lua` | `SandboxVars.Woodcutting` |
| Tree/bush counters in the Kill Count mod | `client/IsCharacterTreeKills.lua` | `modData.treekills` / `bushkills` |

### The three internal events

`WoodcuttingSkillDefinitions.lua` owns a small callback registry so that the code which *detects*
gameplay (shared, engine-facing) stays separate from the code which *rewards* it (server-only).

| Register with | Dispatched from | Fires |
|---|---|---|
| `Woodcutting.addOnTreeHit(cb)` | `B42_TimedActionPacthes.lua` | once per axe swing that lands on a tree |
| `Woodcutting.addOnTreeFelled(cb)` | `B42_TimedActionPacthes.lua` | once, on the swing that topples a tree |
| `Woodcutting.addOnBushRemoved(cb)` | `B42_TimedActionPacthes.lua` | once per bush cleared |

Callbacks are invoked through `pcall`, so one broken listener cannot take the others down; failures
print `[Woodcutting] <event> callback failed: …`. Add new rewards by registering a callback, never
by adding another engine hook.

### Load order

Project Zomboid loads `media/lua/shared/` → `client/` → `server/`, alphabetically within each
directory. Every file starts with `require "WoodcuttingSkillDefinitions"`, so ordering between mod
files does not matter. `WoodcuttingSkillDefinitions.lua` owns the `Woodcutting` global, the
settings table, the perk resolver, the tree-felled callback registry and the diagnostics helper.

**`client/` files do not load on a dedicated server; `server/` files do not load on a multiplayer
client.** `shared/` loads everywhere. That split is deliberate here and is why the XP and loot
logic lives under `server/`.

### `Woodcutting.diag(key, message)`

Prints once per unique key regardless of `Woodcutting.testMode`, prefixed `[Woodcutting][DIAG]`.
Its whole purpose is that silent-failure paths (perk lookup, patch application, event firing) show
up in `console.txt`, so a bug report arrives with actionable output. **Keep it on every new
early-return path.** `Woodcutting.noise(text)` is the opposite: verbose, gated on `testMode`.

---

## 4. The perk, and how Build 42 registers it

Verified in `zombie.characters.skills.CustomPerks` (42.20.2).

`CustomPerks.init()` walks every enabled mod ID and reads **`<versionDir>/media/perks.txt`**,
falling back to `<commonDir>/media/perks.txt`. So `42/media/perks.txt` is the correct, current
path — despite vanilla itself no longer shipping a `perks.txt`.

The parser is `zombie.scripting.ScriptParser`. It requires:

- a top-level `VERSION = 1,` (any other value throws `invalid or missing VERSION`)
- every child block typed `perk` (anything else throws)
- a non-empty block id
- optional `parent`, `translation`, `passive`, and `xp1`..`xp10` (values ≤ 0 are ignored)

An unknown `parent` silently degrades to `Perks.None`. `Survivalist` exists in B42, so the current
file is valid.

> **Parser hazard:** `CustomPerks.readFile` concatenates lines **without re-inserting newlines**
> before handing the text to `ScriptParser.stripComments`. A `--` comment would therefore swallow
> the rest of the file. Do not put comments in `perks.txt`.

`CustomPerks.initLua()` then writes each custom perk into the Lua `Perks` table under its **id**,
so **`Perks.Woodcutting` is a valid global in Build 42.** `Perks.FromString("Woodcutting")` also
works — it is a plain `PerkById.getOrDefault(name, Perks.MAX)` lookup.

### ⚠ `PerkFactory.getPerkFromName` is keyed by the *translated* name

`PerkFactory.initTranslations()` sets `perk.name = Translator.getText("IGUI_perks_" + translation)`
and indexes `PerkByName` by that translated string. So `PerkFactory.getPerkFromName("Woodcutting")`
— the third fallback in `Woodcutting.getPerk()` — **only resolves when the game language is
English**. It is harmless as a last-resort fallback, but never rely on it, and never use it as the
primary lookup.

### XP curve

`perks.txt` values are **per-level** XP costs.

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Per-level | 50 | 100 | 200 | 500 | 1000 | 2000 | 3000 | 4000 | 5000 | 6000 |
| Cumulative | 50 | 150 | 350 | 850 | 1850 | 3850 | 6850 | 10850 | 15850 | 21850 |

### Awarding XP

`character:getXp():AddXP(perk, amount)` — confirmed present on `IsoGameCharacter$XP`, taking a
`PerkFactory$Perk` (not an enum, not a string). Overloads with 3–6 arguments exist; the two-argument
form applies the character's XP multipliers, which is what we want.

---

## 5. ██ Build 42 tree chopping — the critical engine change ██

**This is the single most important section in this file.**

### What Build 41 did

Chopping a tree ran through the combat/swipe path, so `OnWeaponHitTree` fired on every axe swing
against a tree. Every mod that awarded woodcutting XP hung off that event.

### What Build 42.20.2 actually does

Confirmed by disassembling `zombie.iso.objects.IsoTree` and `zombie.CombatManager`:

1. `ISWorldObjectContextMenu.doChopTree` queues `ISChopTreeAction`
   (`media/lua/shared/TimedActions/ISChopTreeAction.lua`).
2. `ISChopTreeAction:animEvent("ChopTree")` runs under `if not isClient()` and calls
   `self.tree:WeaponHit(self.character, self.axe)`.
3. `IsoTree.WeaponHit` runs `damageCheck` → `WeaponHitEffects` → reads `getTreeDamage()` → applies
   the `AXEMAN` trait ×1.5 → subtracts from the tree's `damage` field → `toppleTree()` at ≤ 0.

**`IsoTree.WeaponHit` does not trigger any Lua event.** The string `OnWeaponHitTree` appears in
exactly two classes in the whole jar:

| Class | Role |
|---|---|
| `zombie.Lua.LuaEventManager` | event registration only |
| `zombie.CombatManager` | the **only** trigger site |

and the trigger in `CombatManager.processMaintenanceCheck` is gated on
`IsoGameCharacter.isActuallyAttackingWithMeleeWeapon()` — a real melee swing that happens to land
on an `IsoTree`. A timed action is not an attack.

### Consequence, and what this mod does about it

> **`Events.OnWeaponHitTree` never fires when a player chops a tree in Build 42.**

Up to and including 1.0.x this mod hung every reward off that event, so **no Woodcutting XP was
ever awarded**, `Woodcutting.onTreeFelled` never dispatched, and with it the felled-tree XP bonus,
the entire extra-loot system and the `treekills` counter. The skill could never leave level 0,
which in turn zeroed the damage scaling, the one-hit threshold and the loot-chance skill bonus.
One missing event silently disabled almost the whole mod.

### The hook, as implemented (1.1.0)

There is no vanilla event, so `B42_TimedActionPacthes.lua` wraps the timed actions directly:

| Wrapper | Guard | Raises |
|---|---|---|
| `ISChopTreeAction:animEvent`, `event == "ChopTree"` | `not isClient()` | `onTreeHit` every swing; `onTreeFelled` when `self.tree:getObjectIndex() == -1` after delegating |
| `ISRemoveBush:complete` | none needed — see below | `onBushRemoved` |
| `Events.OnWeaponHitTree` | engine-side (server/SP only) | `onTreeHit` with `tree = nil` |

Three things make this correct, and each is easy to get wrong:

1. **Read tree size and sprite *before* delegating.** A lethal swing removes the tree, so
   `getProperty("TreeSize")` and `getSprite()` must be sampled first or the extra-loot system sees
   nils.
2. **`self.tree` is the tree.** No `OnTick` polling, no scanning the 3×3 around the character. The
   pre-1.1.0 `findAdjacentTree` heuristic returned an arbitrary neighbouring tree and has been
   deleted.
3. **The `ChopTree` anim event repeats** for as long as the action runs. Per-swing rewards belong
   there; once-per-tree rewards need the `self.__WDC_felled` latch.

**Bushes are hooked on `complete()`, not `animEvent()`,** for exactly that reason: `Chop` repeats
throughout the action, so awarding there would pay out several times for one bush. `complete()` runs
once and is where vanilla actually removes the bush. It also needs no `isClient()` guard —
`LuaTimedActionNew.complete()` returns *before* invoking the Lua `complete` function when
`GameClient.client` is true, so the body only ever runs in singleplayer or on the server.

Note that `ISRemoveBush:animEvent` guards its endurance block with `isServer()`, so in
**singleplayer** `ISRemoveBush:useEndurance` is never called — the endurance-refund wrapper on that
class is a no-op in SP. That is vanilla's behaviour, not ours. `ISChopTreeAction` has no such guard
and does refund correctly.

### Do not re-add the old approach

`Events.OnWeaponHitTree` is still listened to, but only as the **melee-swing** path: a plain attack
that lands on a tree does fire it, and does damage the tree (`CombatManager` calls
`IsoTree.WeaponHit` on its `treeHit` field). On that path the engine does not tell us *which* tree,
so `tree` is `nil` and felled-detection is impossible. That is a deliberate limitation, not a gap
to fill with another heuristic.

### Multiplayer

Both actions have a `serverStart()` that calls `emulateAnimEvent(self.netAction, 1500, …)`, so the
server raises the same anim events. `if not isClient()` in an `animEvent` wrapper is therefore the
right guard: it is satisfied in singleplayer and on the server, and skipped on MP clients. Do not
"fix" it into a `sendClientCommand` round-trip.

---

## 6. Verified Build 42.20.2 API facts

Do not re-derive these from memory. Every row was checked with `javap` against the shipped jar
(§11).

| Fact | Consequence |
|---|---|
| `IsoTree.WeaponHit` triggers **no** Lua event | §5 — the root cause of the XP bug |
| `CombatManager.processMaintenanceCheck` is the only `OnWeaponHitTree` trigger, gated on `isActuallyAttackingWithMeleeWeapon()` | The event survives, but not for chopping |
| `IsoTree.WeaponHit` applies `CharacterTrait.AXEMAN` ×1.5 to tree damage | Mod scaling stacks on top of this, not instead of it |
| `ISChopTreeAction:getDuration()` returns `-1` (animation-driven) | `scaleFiniteDuration` correctly bails; never try to shorten chopping via `maxTime` |
| `ISRemoveBush:getDuration()` returns `100` | Bush-speed scaling does work |
| `ISChopTreeAction` lives in `media/lua/shared/TimedActions/`, not `client/` | `require "TimedActions/ISChopTreeAction"` is correct |
| `ISChopTreeAction:isValid()` requires `ItemTag.CHOP_TREE` on the primary hand item | Not `WeaponCategory.AXE`. The mod's `isAxe()` uses AXE, which is a *different* set |
| `HandWeapon.getTreeDamage()` / `setTreeDamage(int)` exist | Damage scaling approach is sound |
| `Stats.get/set/add/remove(CharacterStat, float)` all exist | The endurance refund code is valid |
| `Perks.Woodcutting` is populated by `CustomPerks.initLua()` | Primary lookup is correct |
| `PerkByName` is keyed by the **translated** perk name | `getPerkFromName("Woodcutting")` is EN-only, §4 |
| `Translator` reads **only** `%s/media/lua/shared/Translate/%s/%s.json` | All `_EN.txt` files are ignored, §7 |
| `_Description` appears nowhere in the jar; `ISSkillProgressBar.lua` builds `"IGUI_perks_"..perk:getName().."_Description"` from the **translated** name | The odd `IGUI_perks_<translated name>_Description` keys in ES/FR/PT are a **correct workaround**, not a mistake — do not delete them |
| `CharacterTrait.GARDENER / HIKER / SCOUT / AXEMAN` exist | Trait boosts are valid |
| `CharacterProfession.LUMBERJACK / PARK_RANGER / FARMER` exist | Profession boosts are valid |
| `forageSystem.forageSkillDefinitions` lives in `media/lua/shared/Foraging/forageSkills.lua` | `require "Foraging/forageSkills"` is correct |
| `Base.Log`, `Base.TreeBranch2`, `Base.Twigs`, `Base.Pinecone`, `Base.DeadSquirrel`, `Base.Acorn` all exist | Loot table item IDs are valid |
| `Perks.PlantScavenging` is B42's foraging perk | `Perks.Foraging` does not exist |

⚠ **`pcall` no longer hides broken API calls.** Build 42.20.0 shipped *"Fixed certain exceptions not
being reported when running Lua code"*. A `pcall`-wrapped call to a nonexistent method now prints a
red error every time it runs. `pcall` is not a substitute for checking that a method exists.

---

## 7. Translations — currently broken

### The rule

Build 42.15+ dropped `.txt` translation tables and the `_<LANG>` filename suffix. 42.20.2's
`Translator.tryFillMapFromFile` builds exactly one path:

```
<modVersionDir-or-commonDir>/media/lua/shared/Translate/<LANG>/<Type>.json
```

Files are UTF-8, parsed with `org.json`. Nothing else is read.

### What is in the repo (1.1.0)

`common/media/lua/shared/Translate/<LANG>/` for `EN`, `PT`, `PTBR`, `ES`, `FR`, each with
`IG_UI.json`, `Sandbox.json` and `UI.json`. All UTF-8, LF, `%%`-compliant.

Fixed in 1.1.0 — for the record, since all four were shipping simultaneously:

| Was | Now |
|---|---|
| `42/media/lua/shared/translate/en/…` — lowercase `translate` **and** lowercase language codes. Worked on Windows (case-insensitive NTFS), silently failed on **Linux dedicated servers** | `common/…/Translate/EN/…` |
| `*_EN.txt`, `*_ES.txt`, `*_FR.txt`, `*_PTBR.txt` — dead files, never read by 42.20.2 | deleted |
| No `Sandbox.json` in any language → the whole Sandbox page rendered raw keys | present, 19 options × label + tooltip × 5 languages |
| No `UI.json` in any language → the Woodcutter trait rendered `UI_trait_woodcutter` | present |
| Literal `%` in every description | `%%` |

The 15 files are **generated, not hand-edited**:

```bash
python scripts/gen_translations.py     # rewrites every Translate/<LANG>/*.json
```

Edit the tables in `scripts/gen_translations.py` and re-run it. That is what keeps 5 languages × 3
files from drifting apart, and the script asserts the `%%` rule on every string it writes, so a
lone `%` fails the run instead of reaching a player. Adding a language means one new entry per
table, nothing else.

### Type → key-prefix table

| Type | Filename | Key prefix | Retrieved with |
|---|---|---|---|
| IGUI | `IG_UI.json` | `IGUI_` | `getText()` |
| Sandbox | `Sandbox.json` | `Sandbox_` | sandbox UI, via `translation =` in `sandbox-options.txt` |
| UI | `UI.json` | `UI_` | `getText()` |
| Tooltip | `Tooltip.json` | `Tooltip_` | `getText()` |

Filename `IG_UI` with key prefix `IGUI_` is a vanilla asymmetry, not a mistake.

Perk names are `IGUI_perks_<PerkID>`. Perk descriptions are
`IGUI_perks_<translated perk name>_Description` — see the `ISSkillProgressBar` row in §6.

Sandbox keys come from `translation = Woodcutting_<Name>` in `sandbox-options.txt`, which resolves
to `Sandbox_Woodcutting_<Name>` and `Sandbox_Woodcutting_<Name>_tooltip`. The page header itself is
`Sandbox_Woodcutting`.

### Fixing it

Move the whole tree to `common/media/lua/shared/Translate/<LANG>/` (translations are identical
across all 42.x, so `common/` is where they belong), rename the directories to the correct case,
delete every `.txt`, add `Sandbox.json` and `UI.json` per language by converting the existing
`.txt` content, and double every literal `%`.

Verification:

```bash
# no single % that is not part of %%
grep -rnP '(?<!%)%(?!%)' "Contents/mods/WoodcuttingSkill - Build 42"

# every JSON parses
find Contents -name "*.json" -exec python -c "import json,sys;json.load(open(sys.argv[1],encoding='utf-8'))" {} \;

# nothing left with a legacy suffix
find Contents -name "*_EN.txt" -o -name "*_PTBR.txt" -o -name "*_ES.txt" -o -name "*_FR.txt"
```

Also check `Zomboid/console.txt` after launching — 42.20.2 logs an error line for every offending
`%`, and `Zomboid/translationProblems.txt` for missing keys.

---

## 8. Sandbox options

`42/media/sandbox-options.txt` defines 19 options, all on `page = Woodcutting`, all namespaced
`Woodcutting.<name>` so they arrive in Lua as `SandboxVars.Woodcutting.<name>`.

`shared/WoodcuttingSandboxBridge.lua` copies them into `Woodcutting.Settings` on `OnGameStart`,
`OnServerStarted` and `OnInitGlobalModData`.

Adding an option requires **four** edits, and skipping any one of them fails silently:

1. the `option` block in `sandbox-options.txt`
2. the copy line in `WoodcuttingSandboxBridge.lua`
3. an entry in the `SANDBOX` table in `scripts/gen_translations.py`, then re-run it
4. a matching default in `Woodcutting.Settings` (`WoodcuttingSkillDefinitions.lua`)

### Settings not exposed to Sandbox

These live only in `Woodcutting.Settings` and cannot be changed by a server admin:

`skillLevelForNoSevereExhaustion`, `enduranceSavedPerPerkLevel`,
`bonusConditionLowerOneInPerLevel`, `caloriesSavedModifierPerLevel`,
`bonusAxeTreeDamagePerLevel`.

`caloriesSavedModifierPerLevel` was dead configuration until 1.1.0. It is now applied in the
`new` wrapper, which scales vanilla's `o.caloriesModifier = 8` down by
`caloriesSavedModifierPerLevel × level / 10`, capped at 90%. Java reads `caloriesModifier` off the
Lua table when the action is queued — *after* `:new()` returns — which is why modifying it there
takes effect.

### `Woodcutting.AdjustNatureAbundance()` is pure

`Woodcutting.BaseChanceOfExtrasOneIn` holds the un-scaled chances; `AdjustNatureAbundance()`
derives `Settings.ChanceOfExtrasOneIn` from it. **The Sandbox bridge writes into the base table,
never into the effective one**, and calls `AdjustNatureAbundance()` itself once the copy is done.

Before 1.1.0 the function multiplied `Settings.ChanceOfExtrasOneIn` in place and was registered on
both `OnGameStart` and `OnServerStarted`, so it could compound on a listen server — and because
`WoodcuttingSkillDefinitions.lua` is pulled in by `require` before the bridge file's own event
registration, abundance ran *first* and the sandbox copy then overwrote it, meaning the abundance
setting was ignored whenever a Woodcutting sandbox block existed. Keeping the function pure and
calling it from the end of the bridge removes both failure modes. **Do not re-register it in a way
that depends on event ordering.**

---

## 9. Multiplayer model

There is no custom network protocol; the mod has no `OnClientCommand` handler. It relies entirely
on the fact that the relevant code paths already run server-side:

- `server/` Lua does not load on MP clients at all.
- `ISChopTreeAction:animEvent` and `ISRemoveBush:animEvent` gate their gameplay effects on
  `not isClient()` / `isServer()`, and `serverStart()` emulates the anim events server-side.

`WoodCuttingDamagePerLevel.lua` lives in `server/` and applies `setTreeDamage` from
`OnEquipPrimary`, `LevelPerk` and `OnWeaponHitTree`. Equipping is a client-side action, and whether
`OnEquipPrimary` fires on a dedicated server for a remote player is **unverified** — so since 1.1.0
the `animEvent` wrapper also calls `Woodcutting.prepareWeaponForTreeHit` immediately before
delegating to vanilla, i.e. immediately before `IsoTree.WeaponHit` reads `getTreeDamage()`. That
call is guaranteed to run server-side, so damage scaling no longer depends on the answer.

### Mod data

Stored directly on `player:getModData()`, un-namespaced:

```lua
modData.treekills = <int>   -- written by addTreeFelledXP,  read by IsCharacterTreeKills.lua
modData.bushkills = <int>   -- written by addBushRemovedXP, read by IsCharacterTreeKills.lua
```

Both writers call `character:transmitModData()` afterwards, so the counters reach the client that
renders them. (`transmitModData` is inherited from `IsoObject`; vanilla B42 Lua calls it on
characters in `ISHotbar.lua` and `ISWidgetTitleHeader.lua`.)

Weapons carry one key:

```lua
weapon:getModData().__WDC_baseTreeDamage = <int>   -- one-time snapshot, see below
```

### The `__WDC_baseTreeDamage` snapshot

`weapon:getTreeDamage()` reflects whatever the mod last wrote, so re-deriving "base" from the live
value each hit is self-referential and ratchets. The code snapshots the value once per item
instance and freezes it for that item's lifetime. **Do not remove this.** `InventoryItemFactory` is
not exposed to Lua here (it errors with `non-table: null`), so peeking at a fresh reference item is
not an option.

One consequence worth knowing: the snapshot is taken the first time the mod ever sees that item.
If another mod raises an axe's `TreeDamage` *before* this one, the inflated value becomes our
"base" permanently.

---

## 10. Bug status

### Fixed in 1.1.0

All statically verified — Lua parses as 5.1, every Java API called was checked against the 42.20.2
jar, all 15 translation JSONs parse as UTF-8, and no game-parsed file contains a lone `%`.
**None of it has been exercised in a running game yet — see §11 for the test list.**

| # | Bug | Fix |
|---|---|---|
| 1 | **No Woodcutting XP is ever awarded** (the reported bug, 3 players) | `ISChopTreeAction:animEvent` wrapper raising `Woodcutting.onTreeHit` (§5) |
| 2 | Tree-felled XP, extra loot and `treekills` never trigger | same wrapper raises `onTreeFelled` on the toppling swing (§5) |
| 3 | Sandbox page and Woodcutter trait untranslated in every language | `Sandbox.json` + `UI.json` added for 5 languages (§7) |
| 4 | Translation folders `translate/en` — broken on Linux servers | moved to `common/…/Translate/EN` (§7) |
| 5 | Literal `%` in translation JSON | `%%` throughout, asserted by the generator (§7) |
| 6 | `modData.bushkills` had no producer | `ISRemoveBush:complete` wrapper raising `onBushRemoved` (§5) |
| 7 | `findAdjacentTree` attributed a felling to an arbitrary neighbouring tree | deleted; `self.tree` is exact (§5) |
| 8 | `AdjustNatureAbundance` compounded, and was overwritten by the sandbox bridge | made pure, driven from the bridge (§8) |
| 9 | `caloriesSavedModifierPerLevel` was dead configuration | applied to `caloriesModifier` in the `new` wrapper (§8) |
| 10 | Damage scaling depended on `OnEquipPrimary` firing server-side | also applied in the `animEvent` wrapper (§9) |
| 12 | `mod.info` had no `author`, no `modversion` | added (§2) |
| 14 | `steamdesc.txt` shipped inside `Contents/` | moved to the repo root |
| 15 | `client/WoodcuttingSkillTraits.lua` was an empty stub, and collided by basename with the `shared/` file of the same name | deleted |

### Still open

11. **`isAxe()` uses `WeaponCategory.AXE`, but the game gates chopping on `ItemTag.CHOP_TREE`.**
    These are different sets. An item tagged `CHOP_TREE` that is not category `AXE` chops trees but
    receives none of this mod's axe bonuses. Deliberately **not** changed in 1.1.0 — it is a balance
    decision, not a bug, and this release should not mix the two. `addWoodcuttingXP` now logs a
    one-time `[Woodcutting][DIAG] chopTreeNotAxe:<fullType>` line the first time it sees such a
    weapon, so the decision can be made from real data. Check `console.txt` before choosing.
13. **Two filenames are misspelled** — `WoocuttingHitTree.lua` (missing `d`) and
    `B42_TimedActionPacthes.lua` (`Pacthes`). Harmless to the game; rename only alongside a change
    that already touches them, since renames are noisy in diffs.
16. **`poster.png` is 685×665.** The convention is 1024×1024. `preview.png` is correctly 256×256.
17. **Bush XP is flat.** `bushRemovedXp` grants the same amount regardless of bush type or skill
    level. Fine as a starting point; revisit if it turns out to be a grinding vector.

---

## 11. Verification

There is no test harness — Project Zomboid Lua only runs inside the game. These are the checks that
actually catch things.

### Checking a Java API before you call it

The single most valuable check available, and the one that would have caught the XP bug. Never
guess whether a method exists or what it does — the jar is the only authority.

```bash
PZ="/g/SteamLibrary/steamapps/common/ProjectZomboid"   # adjust to your install
mkdir -p /tmp/pz && cd /tmp/pz
unzip -o -q "$PZ/projectzomboid.jar" "zombie/iso/objects/IsoTree.class"
javap -p -classpath . zombie.iso.objects.IsoTree | grep -i weaponhit
javap -c -p -classpath . zombie.iso.objects.IsoTree | awk '/public void WeaponHit\(/,/^$/'
```

`grep`-ing the jar directly does **not** work — entries are deflated, so identifiers are not
present as plain text. Always extract the `.class` first.

To find *where* a Lua event is triggered, scan every class's decompressed bytes:

```python
import zipfile
z = zipfile.ZipFile(r"G:\SteamLibrary\steamapps\common\ProjectZomboid\projectzomboid.jar")
print([i.filename for i in z.infolist()
       if i.filename.endswith(".class") and b"OnWeaponHitTree" in z.read(i)])
# -> ['zombie/CombatManager.class', 'zombie/Lua/LuaEventManager.class']
```

The game ships a JRE with no `javap`. Use any JDK 21+ on the machine; class files are version 69
(Java 25), and JDK 21's `javap` reads them fine.

### Reading vanilla Lua

`$PZ/media/lua/{client,server,shared}/` is the authoritative source for how a timed action behaves.
Read `shared/TimedActions/ISChopTreeAction.lua` before changing anything in §5.

### Static checks

Run all four from the repo root. `grep -P` needs a UTF-8 locale; on Git Bash for Windows it errors
out with *"-P supports only unibyte and UTF-8 locales"*, so the percent check uses Python instead.

```bash
# 1. Percent rule - no lone % in anything the game parses as text
python - <<'PY'
import re, glob, io
pat = re.compile(r'(?<!%)%(?!%)')
files = [f for e in ("json","txt","info") for f in glob.glob("Contents/**/*."+e, recursive=True)]
files.append("workshop.txt")
bad = sum(1 for f in files for _ in pat.finditer(io.open(f, encoding="utf-8").read()))
print(len(files), "files checked,", bad, "problems")
PY

# 2. Lua syntax (Kahlua is Lua 5.1)
npm install --no-save luaparse
node -e 'const L=require("luaparse"),fs=require("fs"),p=require("path");let n=0,bad=0;
(function w(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const q=p.join(d,e.name);
if(e.isDirectory())w(q);else if(e.name.endsWith(".lua")){n++;try{L.parse(fs.readFileSync(q,"utf8"),
{luaVersion:"5.1"})}catch(err){bad++;console.log("FAIL",q,err.message)}}}})("Contents");
console.log(n+" lua parsed, "+bad+" failed.")'

# 3. JSON validity + UTF-8
python -c "import json,glob,io;[json.load(io.open(f,encoding='utf-8')) for f in glob.glob('Contents/**/*.json',recursive=True)];print('json ok')"

# 4. No documentation inside Contents
find Contents -name "*.md"
```

A cheap fifth check that has already earned its keep — every `Woodcutting.*` call resolves to a
definition somewhere in the mod:

```bash
python - <<'PY'
import re, glob, io
d, c = set(), {}
for f in glob.glob("Contents/**/*.lua", recursive=True):
    s = io.open(f, encoding="utf-8").read()
    d |= set(re.findall(r'function\s+Woodcutting\.(\w+)', s))
    d |= set(re.findall(r'^\s*Woodcutting\.(\w+)\s*=', s, re.M))
    for m in re.finditer(r'Woodcutting\.(\w+)\s*\(', s): c.setdefault(m.group(1), set()).add(f)
print("undefined:", {k: sorted(v) for k, v in c.items() if k not in d} or "none")
PY
```

### In-game checks

**None of these have been run against 1.1.0 yet.** Items 1–3 are the regression tests for the bug
this release exists to fix and should be run first.

1. **New singleplayer save, 42.20.2** — Woodcutting appears in the Skills tab under Survivalist,
   with a translated name and description. `console.txt` shows
   `patch:applied:ISChopTreeAction:animEvent` and no errors.
2. **Chop one tree with an axe** — XP appears in the skill panel on the *first swing*, before the
   tree falls. This is the regression test for §5.
3. **Fell that tree** — bonus XP lands, `treekills` increments in the Kill Count panel if that mod
   is installed, extra loot rolls on a medium/large tree.
4. **Clear a bush** — XP lands exactly **once**, not once per swing. This is the regression test
   for hooking `complete()` rather than `animEvent()`.
5. **Sandbox page** — all 19 options show a translated label and tooltip, no raw `Sandbox_*` keys,
   no stray `%%`.
6. **Woodcutter trait** in character creation shows a name and description, not `UI_trait_*`.
7. **Level to the one-hit threshold** — a tree falls in one swing.
8. **Nature Abundance** — set it to Very Poor and Very Abundant on two saves and confirm the loot
   rate actually differs. This never worked before 1.1.0 (§8).
9. **Dedicated server, two clients** — XP replicates, is granted server-side only, and damage
   scaling applies for a remote player. Confirm on a **Linux** server that translations load (§7).
10. **`console.txt` / `translationProblems.txt`** — zero percent-handling errors, zero missing keys,
    and check for any `chopTreeNotAxe:` diagnostic (§10 item 11).

---

## 12. Releasing

Semantic versioning, tracked in `mod.info`'s `modversion=`.

| Bump | When |
|---|---|
| MAJOR | Save-breaking mod-data change |
| MINOR | New feature, sandbox option or language |
| PATCH | Bug fix, balance tweak, translation fix |

1. Bump `modversion=` in `mod.info`.
2. Run the static checks in §11.
3. Update the `[h1]What's new[/h1]` section of `workshop.txt`.
4. Commit, tag `vX.Y.Z`, push.
5. Upload `Contents/` via the in-game Workshop uploader.

`workshop.txt` is the Steam listing, not a build artifact. Its `description=` lines are
concatenated and submitted on **every** upload. ⚠ **Steam caps the description at 8000 bytes** —
exceeding it fails the whole publish with `EResult 8 (InvalidParam)`, an error that names no field
and is easy to misattribute to the change notes. The current listing is comfortably under.
`workshop.txt` obeys the `%%` rule too.
