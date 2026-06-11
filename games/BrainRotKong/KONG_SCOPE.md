# KONG_SCOPE.md — Périmètre figé de la duplication BrainRotFarm → BrainRotKong

> **Référence de vérité** pour toute la session de duplication.
> Ne pas dévier sans mettre à jour ce fichier.
> Source : duplication `games/BrainRotFarm` → `games/BrainRotKong`, **full reskin**.

## Principe

- **PAS de** : pot de fleur · seed · arbre · sprinkler · tracteur · bale (full reskin Kong).
- **shared-lib** : référencé via `default.project.json` (chemin partagé `../shared-lib`), **jamais copié**.
- **DataStore** : isolé automatiquement par expérience Roblox. Renommé `BrainRotKongV1` (clarté, non bloquant).
- **Contenu Kong-specific** (tour, Kong combat, sorts, GiantBR, contribution) + **combat** = **HORS scope de cette session** (voir BRAINROT_KONG_DESIGN.md).

---

## 1. Fichiers `src/` — 43 .lua au total

### DUP / DUP* — 31 fichiers copiés (17 serveur + 14 client)

**Serveur (17)** — `src/ServerScriptService/`
| Fichier | Tag | Note |
|---|---|---|
| Main.server.lua | DUP* | chirurgie (voir §4) |
| DataStoreManager.lua | DUP* | chirurgie + DataStore name |
| SpawnManager.lua | DUP* | chirurgie |
| CommunSpawner.lua | DUP* | require FilterManager à neutraliser |
| ShopSystem.lua | DUP | pur |
| LeaderboardSystem.lua | DUP* | chirurgie |
| DiscordWebhook.lua | DUP | textes cosmétiques |
| MutantGenerator.lua | DUP* | require FilterManager à neutraliser |
| IndexSystem.lua | DUP* | chirurgie |
| BRPreviewsBuilder.lua | DUP | |
| EventVisuals.lua | DUP | |
| Systems/CodeRedeemSystem.lua | DUP* | DataStore "PromoCodesGlobal" |
| Events/EventAdminAbuse.lua | DUP* | **rework reward → Brainrots** (voir §4) |
| Events/EventLuckyHour.lua | DUP | |
| Events/EventMeteorDrop.lua | DUP | |
| Events/EventNightMode.lua | DUP | |
| Events/EventRain.lua | DUP | require RainWeatherSystem (shared-lib) |

**Client (14)** — `src/StarterPlayer/StarterPlayerScripts/`
| Fichier | Tag | Note |
|---|---|---|
| BrainrotCarryUI.client.lua | DUP* | textes hardcodés |
| CodeRedeemAnimations.lua | DUP* | sound IDs |
| CodeRedeemGUI.client.lua | DUP* | textes |
| CollectAllButton.client.lua | DUP* | texte |
| IndexClient.client.lua | DUP* | mutations + asset IDs |
| NightSkyClient.client.lua | DUP | |
| ObjectifHUD.client.lua | DUP | |
| RainWeatherClient.client.lua | DUP* | thunder sound ID |
| ShopHUD.client.lua | DUP | |
| SideMenuHUD.client.lua | DUP | asset ID proxy |
| SlotMenuHUD.client.lua | DUP | stub |
| SoundManager.client.lua | DUP* | chirurgie (SonGraine) |
| SpeedTrailClient.client.lua | DUP* | textes/couleurs |
| TimerHUD.client.lua | DUP* | chirurgie (label ARBRE) |

### VIDÉ — 1 fichier (structure copiée, valeurs purgées)
- `src/ReplicatedStorage/GameConfig.lua` (voir §3)

### EXCLU — 11 fichiers `src/` NON copiés
**Serveur (7)**
- ArbreSystem.lua
- BaleSystem.lua
- SprinklerSystem.lua
- TracteurSystem.lua
- SeedInventory.lua
- Systems/FlowerPotSystem/FlowerPotGrowthSystem.lua
- Systems/FlowerPotSystem/FlowerPotPickupHandler.lua

**Client (4)**
- FlowerPotHUD.client.lua
- SeedsHUD.client.lua
- MiniTutoHUD.client.lua
- OnboardingArrow.client.lua

### EXCLU — Modules / assets (hors compte des 43)
- `src/ReplicatedStorage/Modules/BaleMotion.lua` (module Bale)
- `BrainRotFarm.rbxl` (place file = assets 3D Brainrots BRF)
- `tools/FillFuseTiers_CommandBar.lua`, `tools/audit_fuse_machine.lua` (Fuse BRF)

### NON copiés cette session (hors 31)
- `tools/*` (outils dev — recréables au besoin)
- Docs `.md` (CLAUDE/AUDIT/EVOLUTIONS/STRATEGY/TEMPLATES) → RECRÉÉS si besoin

---

## 2. shared-lib — RÉF préservées (jamais copiées)

Montées via `default.project.json` (chemin `../shared-lib`) :
- `src/server/` (entier) · `src/client/` (entier) · modules `src/shared/` explicites
  (UIConfig, ModalManager, StudsBackground, UITheme, AmelioConfig, FormatNumber, CollectSystem, UpgradeSystem)

### Dead code shared-lib — RÉF à NEUTRALISER (ne pas monter, ne pas requérir)
- `BRFilterSystem/` (29 .lua + README) — retirer le mount `default.project.json`
- `server/BrainrotInventoryService.lua` (1) — aucun require

---

## 3. GameConfig.lua — blocs SUPPRIMÉS (ne pas recopier, même vidés)

- `FlowerPotConfig` (entier)
- `SprinklerVitesses`
- `TracteurConfig`
- `SonGraine`
- Shop upgrades : `Arroseur`, `Tracteur`, `SeedDoubler`
- GamePassIds : `Tracteur`, `ArroseurMAX`, `FlowerPot4`, `SeedDoubler`
- DevProductIds : `SkipSeedTimer`, `SeedPackx3`, `SecretSeed`

**Shop Kong final** = `Speed` · `Carry` · `Magnet (Aimant)` · `LuckyCharm` UNIQUEMENT.

**Conservé** : `MutantTypes` (sert mutations champ + Fuse, pas que les pots).

Le reste : structure copiée, valeurs en `TODO` commentés. DataStore → `"BrainRotKongV1"`.

---

## 4. Chirurgie — fichiers GARDÉS (numéros de ligne INDICATIFS, localiser par contenu, opérer du bas vers le haut)

| Fichier | Action |
|---|---|
| Main.server.lua | retirer requires Sprinkler/Tracteur/FlowerPot/Seed/Arbre/Bale · bloc `InitialiserPots` · remotes seed/pot (UpdateGraines, ClaimDailySeed, RequestSkipDailySeed, GetSeedInfo) · appels `SprinklerSystem.ActiverBase` / `TracteurSystem.Activer` / `BaleSystem.Init` · restore graines au join |
| DataStoreManager.lua | retirer champ `graines` + migration `grainesMigratedV2` + defaults `hasTracteur`/`hasSeedDoubler` · DataStore name → `BrainRotKongV1` |
| SpawnManager.lua | retirer `getFlowerPotSystem` + son appel · neutraliser require FilterManager |
| LeaderboardSystem.lua | retirer lecture `FlowerPotConfig` + infos timer arbre |
| IndexSystem.lua | retirer stockage Mutant FlowerPot |
| TimerHUD.client.lua | retirer `SPECIAL_LABELS` / `SPECIAL_COLORS` ARBRE |
| SoundManager.client.lua | retirer clé `SonGraine` |
| CommunSpawner.lua / MutantGenerator.lua | neutraliser require FilterManager (dead code) |
| **EventAdminAbuse.lua** (rework DUP*) | `questSeuils` → **récompenser des Brainrots PAR RARETÉ** au lieu de `SeedInventory.Add` · `earlyBirdRarity` → Brainrot SECRET · adapter le message de quête (plus de référence graine) |

---

## 5. Exécution — 4 étapes, STOP entre C et D

- **0** Figer périmètre (ce fichier) ✅
- **A** Copie brute des 31 DUP + arbo + project.json + DataStore name
- **B** GameConfig.lua structure vidée + blocs supprimés
- **C** Chirurgie fichiers gardés + rework AdminAbuse + neutralisation dead code → **STOP** (rapport éditions + refs orphelines)
- **D** Validation boot (après GO) : 0 require cassé, 0 appel vers EXCLU, 0 réf dead code, 0 clé GameConfig supprimée encore lue

---

## 6. Déviations / décisions d'exécution (Étape C)

1. **IndexSystem — MUTANTS conservé** (scope disait « retirer stockage Mutant FlowerPot »). À l'inspection, `data.indexObtenu.MUTANTS` est un index **générique** de tout Brainrot mutant déposé (champ + Fuse, conservés par Kong) ; le retirer casserait l'index des mutants gardés. → **Logique conservée**, seul le commentaire trompeur corrigé.
2. **GameConfig — `SonBale` aussi retiré** (conséquence du retrait Bale ; n'était pas listé en §3). Aucun fichier conservé ne le lit.
3. **SpawnManager — `rollBonusTracteur` / `TRACTEUR_CONFIG` / `spawnerBRBonus` CONSERVÉS** (hors périmètre de surgery défini pour SpawnManager). Lisent `TracteurConfig` / `GamePassIds.Tracteur` / `hasTracteur` via fallbacks gardés → **s'auto-désactivent** (no-op) sans crash. Candidat nettoyage ultérieur.
4. **ShopSystem — hooks sprinkler/tracteur CONSERVÉS** (hors périmètre). Le bloc sprinkler (`effet.spawnRateMultiplier`) est **inatteignable** (plus aucun upgrade n'a cet effet) ; `tracteurActif` idem. Boot-safe.
5. **CodeRedeemSystem — `donnerGraines` CONSERVÉ** (gardé par `if not SeedInventory then return`, et `PromoCodes = {}`). Dead code boot-safe.
6. **EventAdminAbuse — reward** implémenté via `SpawnManager.SpawnerBRDansBase(baseIndex, rarete)` + `GetBase(player)`. Champ config renommé `seed` → `rarete` (compat `q.seed` conservée en fallback).
7. **Main — DropSystem.OnMutantDepose/Retire** : lecture `FlowerPotConfig` remplacée par les couleurs littérales (les visuels mutant spot restent).
8. **Early bird AdminAbuse** : `donnerGraineEarlyBird` était un local **non appelé** dans Main BRF (dead) → non recréé. `earlyBirdRarity` reste en config pour câblage futur.
