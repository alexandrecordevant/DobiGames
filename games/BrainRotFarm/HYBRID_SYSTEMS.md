# HYBRID_SYSTEMS.md — Systèmes hybrides (partiellement réutilisables)
> Généré le 2026-03-30 — Audit technique DobiGames

---

## Systèmes avec base réutilisable + extensions BRF

---

### IncomeSystem.lua (shared-lib/server/)

**Statut : 🔶 Hybride**

```
✅ Core logic réutilisable :
   - CalculerIncome(rarity, multiplicateurs) → coins
   - Gestion offline income (coinsParMinute × tempsAbsent)
   - Cumul multiplicateurs (tier, prestige, VIP, event)

❌ BRF-specific :
   - Visuals slots (Button TouchPart, label "$offline")
   - Référence aux raretés BRF dans le calcul
   - Structure couplée à DataStoreManager BRF

💡 Recommandation :
   - Core réutilisable tel quel via GameConfig.IncomeMultipliers
   - Visuals slots = garder dans BRF côté client
   - Déjà bien paramétré via Config → effort minimal
```

**Effort extraire core : 0 min (déjà paramétré via Config.IncomeMultipliers)**

---

### ShopSystem.lua (BrainRotFarm/)

**Statut : 🔶 Hybride**

```
✅ Core logic réutilisable :
   - GetCoutUpgrade(upgradeId, level) → coût exponentiel
   - AcheterUpgrade(player, upgradeId) → valide coins, incrémente level
   - GamePass validation (MarketplaceService:UserOwnsGamePassAsync)

❌ BRF-specific (contenu) :
   - Upgrades hardcodés : Arroseur, Speed, Carry, Aimant, Tracteur, LuckyCharm
   - Max levels spécifiques BRF
   - ProximityPrompts liés aux objets 3D BRF

✅ Déjà bien paramétré :
   - Config.ShopUpgrades [] → contenu vient de GameConfig (bon pattern)

💡 Recommandation :
   - Déplacer ShopSystem vers shared-lib/ (logique générique)
   - Contenu shop dans GameConfig.ShopUpgrades (déjà fait)
   - Effort : LOW (renommer + déplacer fichier)
```

**Effort déplacer vers shared : 15 min**

---

### RebirthSystem.lua (shared-lib/server/)

**Statut : 🔶 Hybride**

```
✅ Core logic réutilisable :
   - Reset progressif (coins, tier, inventory) contre multiplicateur
   - Notification globale REBIRTH_GLOBAL
   - Callbacks injectés (IsProgressionComplete, OnRebirthComplete)

❌ BRF-specific :
   - Fallback rareté "BRAINROT_GOD" (ligne 63-65)
   - Condition rebirth niveau 5+ couplée à cette rareté

💡 Recommandation :
   - Remplacer fallback par GameConfig.RebirthConfig.RequiredRarity[level]
   - Fix minimal : 1 ligne dans GameConfig + 2 lignes dans RebirthSystem
   - Effort : 10 min
```

**Effort fix : 10 min — PRIORITÉ HAUTE (casse reskins)**

---

### BatEquipHandler.lua (shared-lib/server/Combat/)

**Statut : 🔶 Hybride**

```
✅ Core logic réutilisable :
   - Clone arme depuis ServerStorage.Weapons
   - Anti-duplication (vérif si arme déjà équipée)
   - Cleanup à la mort du personnage

❌ BRF-specific :
   - Nom "BaseballBat" hardcodé (ServerStorage.Weapons.BaseballBat)

💡 Recommandation :
   - Ajouter GameConfig.Combat.StartingWeapon = "BaseballBat"
   - Lire depuis Config dans BatEquipHandler
   - Effort : 5 min
```

**Effort fix : 5 min**

---

### BrainrotInventoryService.lua (shared-lib/server/)

**Statut : 🔶 Hybride**

```
✅ Core logic réutilisable :
   - Log serveur des collectibles (name, rarity, timestamp)
   - Structure générique {name, rarity, timestamp}

❌ BRF-specific :
   - Nom service : "BrainrotInventoryService" (BRF dans le nom)
   - RemoteEvent "BrainrotCollected" (BRF dans le nom)

💡 Recommandation :
   - Renommer → CollectibleInventoryService
   - RemoteEvent → GameConfig.CollectibleName .. "Collected"
   - Impact faible, mais important pour lisibilité multi-jeu
   - Effort : 10 min
```

**Effort fix : 10 min**

---

### EventGolden.lua (shared-lib/server/Events/)

**Statut : 🔶 Hybride**

```
✅ Core logic réutilisable :
   - Durée configurable (DUREE_DEFAUT = 60s)
   - Multiplicateur income paramétrisé via config
   - Lazy loading IncomeSystem, CollectSystem

❌ BRF-specific :
   - Nom "Golden" lié à l'univers ferme BRF
   - Couleurs dorées hardcodées (255, 215, 0)
   - Highlight sur tous BR actifs (concept BRF-specific)

💡 Recommandation :
   - Paramétrer couleur depuis GameConfig.EventGolden.Color
   - Le concept "tout devient doré" est adaptable à Zoo (tout devient doré aussi)
   - Effort : 15 min
```

---

### PickupSystem.lua (shared-lib/server/)

**Statut : 🔶 Hybride (très couplé)**

```
✅ Core logic réutilisable :
   - Billboard animé au-dessus des collectibles
   - ProximityPrompt 3s hold duration
   - TAG CollectionService générique

❌ BRF-specific (très couplé) :
   - RARETE_COULEURS table entière hardcodée
   - Animations spéciales BRAINROT_GOD (rainbow)
   - Animations spéciales SECRET (pulse effect)
   - Labels "nom, rareté, prix, CPS" formatés BRF

💡 Recommandation :
   - Lire couleurs depuis GameConfig.Rarities[].Color
   - Lire animations spéciales depuis GameConfig.Rarities[].SpecialAnimation
   - Labels lisibles depuis GameConfig (CollectibleName, etc.)
   - Effort : 30 min — PRIORITÉ HAUTE (casse visuals sur reskins)
```

**Effort fix : 30 min**

---

### FilterRegistry.lua (shared-lib/BRFilterSystem/)

**Statut : ❌ BRF-specific déguisé en shared**

```
❌ Entièrement couplé à BRF :
   - Mapping rarity → couleur codé en dur (MYTHIC, SECRET, BRAINROT_GOD)
   - Pas de mécanique générique sous-jacente

💡 Recommandation :
   - GetRarityColor(rarity) → lire depuis GameConfig.Rarities[rarity].Color
   - RegisterFilter(name) → déjà générique (OK)
   - Effort : 20 min — PRIORITÉ CRITIQUE
```

---

### MonetizationHandler.lua (shared-lib/server/)

**Statut : ❌ BRF-specific déguisé en shared**

```
❌ Violations multiples :
   - require(FlowerPotSystem) → dépendance circulaire shared→BRF
   - Produits Dev hardcodés (SkipSeedTimer, SeedPack, SecretSeed)
   - Logique LuckyHour hardcodée

💡 Recommandation :
   - Pattern callback : injecter handler produits depuis Main.server.lua
   - ProductHandlers = {} → chaque système enregistre son handler
   - MonetizationHandler appelle ProductHandlers[productId](player)
   - Effort : 45 min — PRIORITÉ CRITIQUE
```

---

## Systèmes 100% réutilisables (aucun changement nécessaire)

| Système | Pourquoi réutilisable |
|---------|----------------------|
| `BaseProgressionSystem.lua` | Étages/spots via GameConfig.Seuils |
| `AssignationSystem.lua` | MaxBases via Config |
| `CarrySystem.lua` | Capacity via Config |
| `DropSystem.lua` | Aucun couplage |
| `BatSystem.lua` | Config.Combat.* |
| `SafeZoneTracker.lua` | Config.SafeZoneEnabled |
| `RespawnInvincibility.lua` | Config.RespawnInvincibilityDuration |
| `FilterManager.lua` | FindFirstChild générique |
| `CollectSystem.lua` | Config.Raretes |
| `NotificationHandler.client.lua` | Queue générique |
| `BatController.client.lua` | Config.Combat.BatEnabled |
| Filtres Scale (×4) | Aucun couplage |
| Filtres Visual (Billboard, Glow, Trail, Sparkles) | Aucun couplage |
| Filtres State (Pickupable, Deposited, Carried) | Aucun couplage |

---

## Systèmes 100% BRF-specific (ne pas tenter de généraliser)

| Système | Pourquoi non-généralisable |
|---------|---------------------------|
| `FlowerPotGrowthSystem.lua` | Feature unique BRF |
| `SprinklerSystem.lua` | Mécanisme agraire BRF |
| `TracteurSystem.lua` | Feature unique BRF |
| `ArbreSystem.lua` | Feature unique BRF |
| `BaleSystem.lua` | Feature unique BRF |
| `MutantGenerator.lua` | Extension FlowerPot BRF |
| `CommunSpawner.lua` | ChampCommun = feature BRF |
| `DiscordWebhook.lua` | Intégration Discord BRF |
| Filtres Element (×4) | Système mutants BRF |
