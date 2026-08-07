# Woodcutting Skill — Overhaul (Build 42)

![Woodcutting Skill preview](preview.png)

A Project Zomboid mod that adds a dedicated **Woodcutting** skill and makes tree felling scale with
it: faster chopping, less endurance burned, better loot from medium and large trees, and an
optional one-hit threshold for veteran lumberjacks.

Built for **Build 42** (tested against 42.20.2). Everything is configurable from a dedicated
Sandbox page, in singleplayer, hosted multiplayer and on dedicated servers.

| | |
|---|---|
| **Steam Workshop** | [3559783131](https://steamcommunity.com/sharedfiles/filedetails/?id=3559783131) |
| **Mod ID** | `WoodcuttingSkill_B42` |
| **Build 41 version** | [3559242180](https://steamcommunity.com/sharedfiles/filedetails/?id=3559242180) |
| **Original mod by Champy** | [2944004910](https://steamcommunity.com/sharedfiles/filedetails/?id=2944004910) |

---

## Features

- **A real Woodcutting skill**, 10 levels, listed under Survivalist in the Skills tab.
- **Tree damage that scales with level**, with a configurable cap and an optional *one-hit
  threshold* — at level 6+ by default, a tree falls in a single swing.
- **`+2` tree damage per level with axes**, keeping the spirit of the original mod.
- **Endurance savings per level** (7% by default), and from level 8 chopping no longer escalates
  into severe exhaustion.
- **Faster bush removal**, up to 70% quicker at high level.
- **Weapon condition savings** — a chance per swing to avoid wear, improving with level.
- **Extra loot from medium and large trees**: logs, branches, twigs, pinecones from conifers, plus
  rare fruit and other finds gated by skill and season. Chances respect the Sandbox
  **Nature Abundance** setting.
- **Woodcutter trait** (`+1` Woodcutting, better at finding firewood) and XP boosts for the
  Lumberjack, Park Ranger and Farmer professions and the Gardener, Hiker and Scout traits.
- **Optional integrations**: adds tree and bush counters to the *Kill Count* mod, and recognises
  traits from *More Simple Traits*, *Dynamic Traits* and *Toad Traits* when installed.
- **No vanilla file overrides.** The mod wraps Build 42's timed actions in place, so it stays
  compatible with most other mods.

---

## Installation

### Steam Workshop

Subscribe to [3559783131](https://steamcommunity.com/sharedfiles/filedetails/?id=3559783131) and
enable **Woodcutting Skill — Overhaul (B42)** in the mod list.

For a server, add both IDs to `servertest.ini`:

```ini
WorkshopItems=3559783131
Mods=WoodcuttingSkill_B42
```

### From this repository

The mod itself is everything under `Contents/`. To test locally, copy

```txt
Contents/mods/WoodcuttingSkill - Build 42
```

into your `Zomboid/mods/` folder, then enable it in-game.

---

## Configuration

### Singleplayer and hosted multiplayer

When creating a world, open **Sandbox Options → Woodcutting** and adjust before starting.

### Dedicated server

Edit the save's Sandbox settings, or build a Sandbox preset, containing:

```lua
SandboxVars.Woodcutting = {
    -- Damage
    damageBaseMultiplier = 1.0,   -- multiplier at level 0
    damagePerLevel       = 0.15,  -- +15% per level
    damageMaxMultiplier  = 8.0,   -- upper cap
    oneHitLevelThreshold = 6,     -- trees fall in one swing at this level
    oneHitTreeDamage     = 2000,
    onlyForAxes          = true,

    -- XP
    xpMultiplier         = 1.0,
    axeXpPerHit          = 0.05,
    treeFelledXp         = 5.0,
    axeXpOnTreeFelled    = 1.0,

    -- Extra loot (1 in N — lower is more likely)
    cumulatedForagingAndWoodcuttingSkillLevelForFruit = 8,
    FruitTreeExtra = 80,
    Winter         = 130,
    Pinecone       = 20,
    PineTreeExtra  = 120,
    Log            = 40,
    TreeBranch     = 35,
    Twigs          = 30,
}
```

Set `oneHitLevelThreshold` above 10 to disable the one-hit behaviour entirely.

---

## Compatibility

- Build 42 only. Build 41 players should use the separate B41 release linked above.
- Works by wrapping `ISChopTreeAction` and `ISRemoveBush` rather than replacing them, so it only
  conflicts with mods that *replace* those classes outright.
- Safe to add to an existing save. Removing it mid-save leaves the Woodcutting skill unreadable in
  the character panel until the mod is re-enabled.

## Languages

| Language | Skill name & description | Sandbox page | Trait |
|---|:--:|:--:|:--:|
| English | ✅ | ⚠️ | ⚠️ |
| Portuguese (Brazil) | ✅ | ⚠️ | ⚠️ |
| Portuguese | ✅ | ⚠️ | ⚠️ |
| Spanish | ✅ | ⚠️ | ⚠️ |
| French | ✅ | ⚠️ | ⚠️ |

⚠️ Build 42.15 replaced the old `.txt` translation tables with `.json`, and the Sandbox and trait
strings have not been converted yet — those currently render as raw keys such as
`Sandbox_Woodcutting_xpMultiplier`. Being fixed; see
[AGENTS.md §7](AGENTS.md#7-translations--currently-broken).

Translation contributions are very welcome — add
`Contents/mods/WoodcuttingSkill - Build 42/42/media/lua/shared/Translate/<LANG>/IG_UI.json` and open
a pull request.

## Known issues

| Issue | Status |
|---|---|
| **No Woodcutting XP is awarded when chopping trees** | Root cause identified — Build 42 moved tree chopping off the `OnWeaponHitTree` event. Fix in progress. |
| Tree-felled bonus XP and extra loot never trigger | Same root cause. |
| Sandbox page and Woodcutter trait show untranslated keys | Missing `Sandbox.json` / `UI.json`. |
| Translations do not load on Linux dedicated servers | Translation folders use the wrong letter case. |

Full technical detail, including the decompiled evidence, is in
[AGENTS.md §5](AGENTS.md#5--build-42-tree-chopping--the-critical-engine-change) and
[§10](AGENTS.md#10-known-bugs-and-open-items).

---

## Repository layout

```txt
WoodcuttingSkill_B42/          <- repo root, not uploaded to Steam
├── README.md
├── AGENTS.md                  <- developer / AI operating manual — read this before editing
├── workshop.txt               <- Steam Workshop listing (BBCode)
├── preview.png                <- 256x256
└── Contents/                  <- the only folder uploaded to Steam
    └── mods/
        └── WoodcuttingSkill - Build 42/
            └── 42/            <- Build 42 payload
                ├── mod.info
                ├── poster.png
                └── media/
                    ├── perks.txt
                    ├── sandbox-options.txt
                    ├── ui/Traits/
                    └── lua/{client,server,shared}/
```

## Contributing

Read **[AGENTS.md](AGENTS.md)** first. It documents the Build 42 mod structure, the engine
behaviour that was verified by decompiling the game jar, and the checks to run before opening a
pull request. Several plausible-looking "fixes" are explicitly ruled out there with the reason why.

## Credits

- **Original concept and Build 41 implementation** — Champy
- **Build 42 overhaul and maintenance** — [WindLother](https://github.com/WindLother)

Happy chopping.
