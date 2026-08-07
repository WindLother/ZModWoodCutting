# AGENTS.md — Woodcutting Skill (Build 42)

Operating manual for anyone (human or AI) modifying this mod. **Read this fully before editing any
file.** It describes the Build 42 mod layout, the engine facts that were verified by decompiling
the running game jar, and the known-broken areas that must not be "re-fixed" from memory.

- **Target game version:** Build 42.20.2 (`revision=ffe7a8a4b1`) — Build 42 only, no B41 tree here.
- **Mod ID:** `WoodcuttingSkill_B42` · **Workshop ID:** `3559783131`
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
            └── 42/                    <- ██ resolves to game version 42.0 → loads on every 42.x ██
                ├── mod.info
                ├── poster.png
                ├── steamdesc.txt      <- stale copy of the listing; not read by the game
                └── media/
                    ├── perks.txt
                    ├── sandbox-options.txt
                    ├── ui/Traits/trait_woodcutter.png
                    └── lua/
                        ├── client/
                        │   ├── IsCharacterTreeKills.lua      <- Kill Count mod integration
                        │   └── WoodcuttingSkillTraits.lua    <- empty compatibility stub
                        ├── server/
                        │   ├── Woodcutting/WoodCuttingDamagePerLevel.lua
                        │   ├── Woodcutting/WoodcuttingExtraLoot.lua
                        │   └── XpSystem/WoocuttingHitTree.lua   <- note the typo in the filename
                        └── shared/
                            ├── B42_TimedActionPacthes.lua       <- note the typo in the filename
                            ├── WoodcuttingSandboxBridge.lua
                            ├── WoodcuttingSkillDefinitions.lua
                            ├── WoodcuttingSkillTraits.lua
                            └── translate/…                      <- ⚠ wrong case, see §7
```

### ⚠ There is no `common/` folder

The wiki calls `common/` mandatory. In practice Build 42 detects the mod from the `42/` version
folder alone, which is why it works today. Adding `common/` is still the correct move — it is where
build-agnostic assets (translations, the trait icon) belong, and `CustomPerks.init()` /
`Translator` both fall back to it. Do this as part of the translation fix in §7, not on its own.

### Version-folder resolution

Folder names resolve as `build.major`; the minor component is discarded. `42/` resolves to `42.0`,
so it loads for **every** 42.x release including 42.20.2. Only add a second folder (e.g. `42.20/`)
if you genuinely need different code for newer builds — it duplicates maintenance and is the most
common source of "my change didn't apply" confusion.

### `mod.info`

There is exactly one, at `Contents/mods/WoodcuttingSkill - Build 42/42/mod.info`. It currently
declares only `name`, `id`, `poster`, `description`.

`ChooseGameInfo$Mod` also exposes `author`, `icon`, `modversion`, `versionMin`, `versionMax`,
`require`. **`author` and `modversion` should be added** — without `modversion` there is no way for
a player or a server admin to tell which build they are running, which makes bug reports much
harder to triage. Name the file all-lowercase `mod.info`; Linux is case-sensitive.

---

## 3. What the mod actually does

| Feature | Implemented in | Depends on |
|---|---|---|
| Registers the `Woodcutting` perk | `42/media/perks.txt` | `CustomPerks` (§4) |
| Woodcutting + Axe XP per tree hit | `server/XpSystem/WoocuttingHitTree.lua` | `OnWeaponHitTree` ⚠ §5 |
| Woodcutting + Axe XP on tree felled | `server/XpSystem/WoocuttingHitTree.lua` | `Woodcutting.onTreeFelled` ⚠ §5 |
| Weapon-condition save per level | `server/XpSystem/WoocuttingHitTree.lua` | `OnWeaponHitTree` ⚠ §5 |
| Tree-damage scaling / one-hit threshold | `server/Woodcutting/WoodCuttingDamagePerLevel.lua` | `OnEquipPrimary`, `LevelPerk`, `OnWeaponHitTree` |
| Extra loot on medium/large trees | `server/Woodcutting/WoodcuttingExtraLoot.lua` | `Woodcutting.onTreeFelled` ⚠ §5 |
| Endurance refund + no severe exhaustion | `shared/B42_TimedActionPacthes.lua` | `useEndurance` wrapper |
| Faster bush removal per level | `shared/B42_TimedActionPacthes.lua` | `ISRemoveBush.new` wrapper |
| Felled-tree detection | `shared/B42_TimedActionPacthes.lua` | `OnWeaponHitTree` ⚠ §5 |
| Woodcutter trait + profession/trait XP boosts | `shared/WoodcuttingSkillTraits.lua` | `CharacterTraitDefinition` |
| Sandbox → `Woodcutting.Settings` | `shared/WoodcuttingSandboxBridge.lua` | `SandboxVars.Woodcutting` |
| Tree/bush counters in the Kill Count mod | `client/IsCharacterTreeKills.lua` | `modData.treekills` / `bushkills` |

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

### Consequence

> **`Events.OnWeaponHitTree` never fires when a player chops a tree in Build 42.**

Everything in this mod that hangs off it is dead:

| Listener | File | Effect of the failure |
|---|---|---|
| `addWoodcuttingXP` | `WoocuttingHitTree.lua` | **No Woodcutting XP, ever.** The reported bug. |
| `saveWeaponCondition` | `WoocuttingHitTree.lua` | No condition saving |
| `onHitTree` (damage rescale) | `WoodCuttingDamagePerLevel.lua` | Falls back to `OnEquipPrimary`/`LevelPerk` |
| `checkTreeFelled` | `B42_TimedActionPacthes.lua` | `Woodcutting.onTreeFelled` never dispatches |

and because `onTreeFelled` never dispatches, the tree-felled XP bonus, the extra-loot system and
the `modData.treekills` counter are all dead too. The skill can therefore never leave level 0,
which in turn zeroes the damage scaling, the one-hit threshold, the endurance refund and the
loot-chance skill bonus. **One missing event silently disables almost the entire mod.**

`modData.bushkills` is read by `client/IsCharacterTreeKills.lua` but is never written by anything —
that half of the Kill Count integration has no producer at all.

### The correct Build 42 hook points

There is no vanilla event for this. The supported approach is to wrap the timed action, the same
way `B42_TimedActionPacthes.lua` already wraps `new` and `useEndurance`:

- **Per swing:** wrap `ISChopTreeAction.animEvent` and act on `event == "ChopTree"`, under
  `if not isClient()`.
- **Tree felled:** inside that same wrapper, `self.tree:getObjectIndex() == -1` **after** the
  original `animEvent` has run is the authoritative "this swing toppled it" test — vanilla uses
  exactly that check to force-complete the action. This removes the need for the current
  `OnTick` + `findAdjacentTree` heuristic entirely.
- **Bushes:** wrap `ISRemoveBush.animEvent` (`event == "Chop"`), which is where vanilla applies
  endurance and weapon damage.

Note that `ISRemoveBush:animEvent` guards its endurance block with `isServer()`, so in
**singleplayer** `ISRemoveBush:useEndurance` is never called — the existing endurance-refund
wrapper on that class is a no-op in SP. `ISChopTreeAction` has no such guard and does refund
correctly.

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

### What is in the repo today

| Path | Status |
|---|---|
| `42/media/lua/shared/translate/…` | ⚠ lowercase `translate` — works on Windows (case-insensitive NTFS), **fails on Linux dedicated servers** |
| `translate/en/`, `translate/ptbr/` | ⚠ lowercase language codes — same problem. Vanilla uses `EN`, `PTBR`, `ES`, `FR`, `PT` |
| `*/IG_UI.json` (EN, ES, FR, PT, PTBR) | ✅ correct type and keys |
| `*_EN.txt`, `*_ES.txt`, `*_FR.txt`, `*_PTBR.txt` | ❌ **dead files** — never read by 42.20.2 |
| `Sandbox.json` | ❌ **missing in every language** → the whole Sandbox page renders raw keys |
| `UI.json` | ❌ **missing in every language** → the Woodcutter trait renders `UI_trait_woodcutter` |
| Literal `%` in `IG_UI.json` descriptions | ❌ violates the 42.20.1 `%%` rule |
| ES `IG_UI_ES.txt`, `UI_ES.txt` | ❌ mojibake (legacy Cp1252 bytes) — irrelevant once deleted |

So today: **English and Portuguese players see a correct skill name and description, but an
entirely untranslated Sandbox page and trait.** The `README` and `workshop.txt` claim EN + PT-BR
support; in reality ES, FR and PT-BR skill names ship too, and no language has working Sandbox or
UI strings.

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

`42/media/sandbox-options.txt` defines 18 options, all on `page = Woodcutting`, all namespaced
`Woodcutting.<name>` so they arrive in Lua as `SandboxVars.Woodcutting.<name>`.

`shared/WoodcuttingSandboxBridge.lua` copies them into `Woodcutting.Settings` on `OnGameStart`,
`OnServerStarted` and `OnInitGlobalModData`.

Adding an option requires **four** edits, and skipping any one of them fails silently:

1. the `option` block in `sandbox-options.txt`
2. the copy line in `WoodcuttingSandboxBridge.lua`
3. `Sandbox_Woodcutting_<Name>` + `_tooltip` in `Sandbox.json`, **per language**
4. a matching default in `Woodcutting.Settings` (`WoodcuttingSkillDefinitions.lua`)

### Settings not exposed to Sandbox

These live only in `Woodcutting.Settings` and cannot be changed by a server admin:

`skillLevelForNoSevereExhaustion`, `enduranceSavedPerPerkLevel`,
`bonusConditionLowerOneInPerLevel`, `caloriesSavedModifierPerLevel`,
`bonusAxeTreeDamagePerLevel`.

`caloriesSavedModifierPerLevel` is declared but **never read anywhere** — it is dead configuration.
Either wire it into the `ISChopTreeAction` calorie modifier (`o.caloriesModifier = 8` in vanilla)
or delete it.

### `Woodcutting.AdjustNatureAbundance()` mutates in place

It multiplies `Settings.ChanceOfExtrasOneIn` by the abundance factor and writes the result back
into the same table. It is registered on **both** `OnGameStart` and `OnServerStarted`. On a listen
server both can fire, compounding the multiplier. It also runs *before* or *after* the sandbox
bridge depending on event order, so which values get scaled is not deterministic. Make it pure —
compute from a pristine base table — when you next touch it.

---

## 9. Multiplayer model

There is no custom network protocol; the mod has no `OnClientCommand` handler. It relies entirely
on the fact that the relevant code paths already run server-side:

- `server/` Lua does not load on MP clients at all.
- `ISChopTreeAction:animEvent` and `ISRemoveBush:animEvent` gate their gameplay effects on
  `not isClient()` / `isServer()`, and `serverStart()` emulates the anim events server-side.

**Open risk:** `WoodCuttingDamagePerLevel.lua` lives in `server/` and applies `setTreeDamage` from
`OnEquipPrimary`. Equipping is a client-side action; whether `OnEquipPrimary` fires on a dedicated
server for a remote player is **unverified**. If it does not, tree-damage scaling silently does
nothing in multiplayer while working fine in singleplayer. Applying the scaling inside the
`animEvent` wrapper (§5) instead would remove the doubt entirely, since that is guaranteed to run
server-side immediately before `WeaponHit` reads `getTreeDamage()`.

### Mod data

Stored directly on `player:getModData()`, un-namespaced:

```lua
modData.treekills = <int>   -- written by addTreeFelledXP, read by IsCharacterTreeKills.lua
modData.bushkills = <int>   -- READ but never written (§5)
```

Weapons carry one key:

```lua
weapon:getModData().__WDC_baseTreeDamage = <int>   -- one-time snapshot, see below
```

Nothing calls `transmitModData()`. Add it if these values ever need to reach an MP client.

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

## 10. Known bugs and open items

Ordered by player impact. Items 1–3 are confirmed against 42.20.2; the rest are unverified.

1. **No Woodcutting XP is ever awarded.** Root cause fully established in §5 —
   `Events.OnWeaponHitTree` does not fire for the Build 42 chop-tree timed action. Reported
   independently by three players. Fix by wrapping `ISChopTreeAction:animEvent`.
2. **Tree-felled XP, extra loot and the tree counter never trigger**, same root cause, via the
   dead `Woodcutting.onTreeFelled` dispatch.
3. **The Sandbox page and the Woodcutter trait are untranslated in every language**, because
   `Sandbox.json` and `UI.json` do not exist and 42.20.2 ignores the `.txt` files (§7).
4. **Translation directories use the wrong case** (`translate/en`) — invisible on Windows, fatal on
   Linux dedicated servers (§7).
5. **Literal `%` in translation JSON** violates the 42.20.1 rule and will break when the
   compatibility shim is removed (§7).
6. **`modData.bushkills` has no producer** — the bush half of the Kill Count integration is dead
   (§5).
7. **`findAdjacentTree` picks an arbitrary adjacent tree**, not the one being chopped. It scans the
   3×3 around the character and returns the first hit. With two adjacent trees it can attribute a
   felling to the wrong one. Wrapping `animEvent` gives us `self.tree` directly and makes the whole
   heuristic unnecessary.
8. **`AdjustNatureAbundance` can compound** on a listen server (§8).
9. **`caloriesSavedModifierPerLevel` is dead configuration** (§8).
10. **`OnEquipPrimary` on a dedicated server is unverified** (§9).
11. **`isAxe()` uses `WeaponCategory.AXE`, but the game gates chopping on `ItemTag.CHOP_TREE`.**
    These are different sets. An item tagged `CHOP_TREE` that is not category `AXE` chops trees but
    receives none of this mod's axe bonuses; the reverse is also possible. Decide deliberately
    which one the mod should key off.
12. **`mod.info` has no `author` and no `modversion`** (§2).
13. **Two filenames are misspelled** — `WoocuttingHitTree.lua` (missing `d`) and
    `B42_TimedActionPacthes.lua` (`Pacthes`). Harmless to the game; rename only alongside a change
    that already touches them, since renames are noisy in diffs.
14. **`steamdesc.txt` ships inside `Contents/`** and duplicates `workshop.txt`. Harmless but it is
    documentation inside the upload; move it to the repo root.
15. **`client/WoodcuttingSkillTraits.lua` is an empty stub.** Delete it once nothing requires it.
16. **`poster.png` is 685×665.** The convention is 1024×1024. `preview.png` is correctly 256×256.

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

```bash
cd "Contents/mods/WoodcuttingSkill - Build 42"

# 1. Percent rule
grep -rnP '(?<!%)%(?!%)' .

# 2. Lua syntax (Kahlua is Lua 5.1)
find . -name "*.lua" -exec luac5.1 -p {} \;
#   or, with node: npm i luaparse && parse each file with luaVersion:"5.1"

# 3. JSON validity + UTF-8
find . -name "*.json" -exec python -c "import json,sys;json.load(open(sys.argv[1],encoding='utf-8'))" {} \;

# 4. No documentation inside Contents
find . -name "*.md"
```

### In-game checks

1. **New singleplayer save, 42.20.2** — Woodcutting appears in the Skills tab under Survivalist;
   its name and description are translated; no errors in `console.txt`.
2. **Chop one tree with an axe** — XP appears in the skill panel. This is the regression test for
   §5. Watch for `[Woodcutting][DIAG]` lines confirming the hook fired.
3. **Fell a tree** — bonus XP, `treekills` increments, extra loot rolls.
4. **Sandbox page** — every option shows a translated label and tooltip, no raw `Sandbox_*` keys.
5. **Level to the one-hit threshold** — a tree falls in one swing.
6. **Dedicated server, two clients** — XP replicates and is granted server-side only. Confirm on a
   **Linux** server that translations still load (§7).
7. **`console.txt` / `translationProblems.txt`** — zero percent-handling errors, zero missing keys.

---

## 12. Releasing

Semantic versioning. Add `modversion=` to `mod.info` first (§2) so there is something to bump.

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
