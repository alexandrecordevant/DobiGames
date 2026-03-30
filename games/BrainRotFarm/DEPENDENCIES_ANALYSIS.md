# DEPENDENCIES_ANALYSIS.md — Analyse des require()
> Généré le 2026-03-30 — Audit technique DobiGames

---

## Shared-lib — dépendances

### BaseProgressionSystem.lua
- ✅ `require(GameConfig)` — couplage autorisé
- ✅ `require(CarrySystem)` — shared ↔ shared OK
- ✅ `require(DropSystem)` — shared ↔ shared OK
- ✅ Aucun require() BRF-specific

### AssignationSystem.lua
- ✅ `require(GameConfig)` — couplage autorisé
- ✅ Aucun require() BRF-specific
- 💡 Callbacks `OnAssigned`, `GetSpawnCFrame` injectés depuis Main (bon pattern)

### CollectSystem.lua
- ✅ `require(GameConfig)` — couplage autorisé
- ✅ Aucun require() BRF-specific

### UpgradeSystem.lua
- ✅ `require(GameConfig)` — couplage autorisé
- ✅ Aucun require() BRF-specific

### CarrySystem.lua
- ✅ `require(GameConfig)` (implicite via callbacks)
- ✅ Aucun require() BRF-specific

### DropSystem.lua
- ✅ Aucun require() documenté
- ✅ Aucun require() BRF-specific

### RebirthSystem.lua
- ✅ `require(BaseProgressionSystem)` — shared ↔ shared OK
- ⚠️ Fallback `"BRAINROT_GOD"` hardcodé en dur (ligne 63-65) — pas un require() mais une valeur couplée

### BatSystem.lua
- ✅ `require(CarrySystem)` — shared ↔ shared OK
- ✅ `require(MarketplaceService)` — service Roblox OK
- ✅ Aucun require() BRF-specific

### SafeZoneTracker.lua
- ✅ Aucun require()
- ✅ Lit `Config.SafeZoneEnabled` en runtime (OK)

### RespawnInvincibility.lua
- ✅ Aucun require()
- ✅ Lit `Config.RespawnInvincibilityDuration` en runtime (OK)

### BatEquipHandler.lua
- ✅ Aucun require()
- ⚠️ Accès direct à `ServerStorage.Weapons` (couplage nommage)

### FilterManager.lua
- ✅ Aucun require()
- ✅ Générique (FindFirstChild récursif)

### FilterRegistry.lua
- ❌ `GetRarityColor("BRAINROT_GOD")` — valeur BRF hardcodée dans shared-lib
- ❌ `GetRarityColor("MYTHIC")` — rareté BRF hardcodée
- ❌ `GetRarityColor("SECRET")` — rareté BRF hardcodée
- 💡 Devrait lire depuis `GameConfig.Rarities[].Color`

### PickupSystem.lua
- ✅ `require(CollectionService)` — service Roblox OK
- ✅ `require(CarrySystem)` — shared ↔ shared OK
- ❌ `RARETE_COULEURS` hardcodé dans le fichier (toutes les raretés BRF)
- ❌ Animations spéciales "GOD" et "SECRET" hardcodées

### EventManager.lua
- ✅ `require(GameConfig)` — couplage autorisé
- ✅ `require(CollectSystem)` — shared ↔ shared OK
- ❌ `types = {"NightMode", "MeteorDrop", "Rain", "Golden", "LuckyHour", "DoubleCoins"}` hardcodé
- ❌ Lazy `require(EventVisuals)` — contenu BRF-specific

### MonetizationHandler.lua
- ✅ `require(GameConfig)` — couplage autorisé
- ✅ `require(CollectSystem)` — shared ↔ shared OK
- ✅ `require(ShopSystem)` — OK
- ❌ `require(FlowerPotSystem)` — **RED FLAG** : shared-lib dépend d'un système BRF-specific
- ❌ Produits `SkipSeedTimer`, `SeedPack×3`, `SecretSeed` hardcodés (BRF-specific)

### BrainrotInventoryService.lua
- ✅ Aucun require()
- ❌ Nom du RemoteEvent : `"BrainrotCollected"` — BRF-specific dans shared

### UITheme.lua
- ✅ Aucun require()
- ❌ Couleurs thème "Farm Brain Rot" hardcodées

### RebirthCosmeticsSystem.lua
- ✅ Aucun require()
- ❌ `PALIERS_COSMETIQUES [1, 3, 5, 10]` avec `"REBIRTH_GOD"` hardcodés

---

## BRF-specific — dépendances

### Main.server.lua
- ✅ `require(GameConfig)` — couplage autorisé
- ✅ `require(DataStoreManager)` — BRF ↔ BRF OK
- ✅ `require(EventManager)` — BRF ↔ shared OK
- ✅ `require(CarrySystem)` — BRF ↔ shared OK
- ✅ `require(BaseProgressionSystem)` — BRF ↔ shared OK
- ✅ `require(AssignationSystem)` — BRF ↔ shared OK
- ✅ `require(RebirthSystem)` — BRF ↔ shared OK
- ✅ `require(BatSystem)` — BRF ↔ shared OK
- ✅ `require(BoardSystem)` — BRF ↔ BRF OK
- ✅ `require(ArbreSystem)` — BRF ↔ BRF OK
- ✅ `require(BaleSystem)` — BRF ↔ BRF OK
- ✅ `require(RebirthCosmeticsSystem)` — BRF ↔ shared OK
- 💡 19 modules au total — orchestrateur complexe (450+ lignes)

### DataStoreManager.lua
- ✅ `require(CollectSystem)` — BRF ↔ shared OK
- ❌ DataStore nommé `"BrainRotIdleV1"` — hardcodé (devrait être `GameConfig.DataStoreName`)

### ShopSystem.lua
- ✅ `require(GameConfig)` — couplage autorisé
- ✅ Contenu shop via `Config.ShopUpgrades` (bien paramétré)

### FlowerPotGrowthSystem.lua
- ✅ BRF-specific — pas de dépendance shared problématique

---

## RED FLAGS critiques (violations architecture)

| Fichier (dans shared-lib) | Violation | Impact reskin |
|---------------------------|-----------|---------------|
| `MonetizationHandler.lua` | `require(FlowerPotSystem)` — shared dépend de BRF | ❌ CRITIQUE |
| `FilterRegistry.lua` | Couleurs MYTHIC/SECRET/BRAINROT_GOD hardcodées | ❌ CRITIQUE |
| `EventManager.lua` | Types d'events BRF hardcodés | ❌ ÉLEVÉ |
| `PickupSystem.lua` | RARETE_COULEURS + animations GOD/SECRET hardcodées | ❌ ÉLEVÉ |
| `MonetizationHandler.lua` | Produits SkipSeedTimer/SeedPack BRF hardcodés | ❌ ÉLEVÉ |
| `BrainrotInventoryService.lua` | RemoteEvent "BrainrotCollected" — nom BRF | ⚠️ MOYEN |
| `UITheme.lua` | Thème "Farm Brain Rot" hardcodé | ⚠️ MOYEN |
| `RebirthSystem.lua` | Valeur "BRAINROT_GOD" fallback | ⚠️ MOYEN |
| `DataStoreManager.lua` | DS name "BrainRotIdleV1" hardcodé | ⚠️ MOYEN |
| `BatEquipHandler.lua` | `ServerStorage.Weapons` couplage nommage | ⚠️ FAIBLE |
