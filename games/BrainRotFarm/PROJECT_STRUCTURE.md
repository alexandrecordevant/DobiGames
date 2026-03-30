# PROJECT_STRUCTURE.md — Cartographie réelle du dépôt
> Généré le 2026-03-30 — Audit technique DobiGames

---

## shared-lib/ (46 fichiers — systèmes réutilisables)

```
shared-lib/src/
├── BRFilterSystem/
│   ├── FilterManager.lua          ✅ shared — gestionnaire centralisé filtres visuels
│   ├── FilterRegistry.lua         ❌ BRF-specific — GetRarityColor() hardcode MYTHIC/SECRET/BRAINROT_GOD
│   ├── Filters/Scale/
│   │   ├── Miniature.lua          ✅ shared — scale ×0.5
│   │   ├── Normal.lua             ✅ shared — scale ×1.0
│   │   ├── Large.lua              ✅ shared — scale ×1.5
│   │   └── Geant.lua              ✅ shared — scale ×2.5
│   ├── Filters/Rarity/
│   │   ├── RarityCOMMON.lua       ✅ shared — couleur grise générique
│   │   ├── RarityRARE.lua         ✅ shared — couleur bleue générique
│   │   ├── RarityEPIC.lua         ✅ shared — couleur violette générique
│   │   ├── RarityLEGENDARY.lua    ✅ shared — couleur dorée générique
│   │   ├── RarityMYTHIC.lua       ❌ BRF-specific — couleur + particules hardcodées
│   │   └── RaritySECRET.lua       ❌ BRF-specific — feu rouge + sparkles hardcodés
│   ├── Filters/Element/
│   │   ├── ElementEau.lua         ❌ BRF-specific — mutant system BRF
│   │   ├── ElementFeu.lua         ❌ BRF-specific — mutant system BRF
│   │   ├── ElementTerre.lua       ❌ BRF-specific — mutant system BRF
│   │   └── ElementVent.lua        ❌ BRF-specific — mutant system BRF
│   └── Filters/Visual/
│       ├── Billboard.lua          ✅ shared — texte + couleur configurable
│       ├── Glow.lua               ✅ shared — éclairage générique
│       ├── Trail.lua              ✅ shared — traînée générique
│       ├── Sparkles.lua           ✅ shared — scintillement générique
│       ├── Pickupable.lua         ✅ shared — état ramassable
│       ├── Deposited.lua          ✅ shared — état déposé
│       └── Carried.lua            ✅ shared — état porté
│
├── shared/
│   ├── UITheme.lua                ❌ BRF-specific — palette couleurs "Farm Brain Rot" hardcodée
│   ├── CollectSystem.lua          ✅ shared — tirage rareté, multiplicateurs
│   └── UpgradeSystem.lua          ✅ shared — coûts upgrades exponentiels
│
├── server/
│   ├── AssignationSystem.lua      ✅ shared — assigne joueurs → bases (1..N)
│   ├── BaseProgressionSystem.lua  ✅ shared — déblocage étages/spots générique
│   ├── CarrySystem.lua            ✅ shared — carry stack sur tête, capacity
│   ├── DropSystem.lua             ✅ shared — drop BRs à la mort/batte
│   ├── IncomeSystem.lua           🔶 hybride — calcul générique MAIS visuals BRF-specific
│   ├── PickupSystem.lua           ❌ BRF-specific — Billboard avec raretés BRF + animations GOD/SECRET
│   ├── RebirthSystem.lua          🔶 hybride — générique MAIS fallback "BRAINROT_GOD" hardcodé
│   ├── RebirthCosmeticsSystem.lua ❌ BRF-specific — auras/trails BRF hardcodées
│   ├── BrainrotInventoryService.lua ❌ BRF-specific — nom service + RemoteEvent "BrainrotCollected"
│   ├── EventManager.lua           ❌ BRF-specific — types d'events BRF hardcodés
│   ├── MonetizationHandler.lua    ❌ BRF-specific — produits SkipSeedTimer/SeedPack BRF-specific
│   └── Events/
│       ├── EventGolden.lua        ❌ BRF-specific — event thème "doré" BRF
│       ├── EventNightMode.lua     ❌ BRF-specific — nuit BRF
│       ├── EventMeteorDrop.lua    ❌ BRF-specific — météore BRF
│       └── EventRain.lua          ❌ BRF-specific — pluie BRF
│
├── server/Combat/
│   ├── BatSystem.lua              ✅ shared — 8 validations anti-exploit, drop générique
│   ├── SafeZoneTracker.lua        ✅ shared — désactive PvP dans SafeZone
│   ├── RespawnInvincibility.lua   ✅ shared — invincibilité post-respawn
│   └── BatEquipHandler.lua        🔶 hybride — "BaseballBat" depuis ServerStorage.Weapons
│
└── client/
    ├── BrainrotCarryUI.client.lua ❌ BRF-specific — labels "Carry Upgrade" BRF
    ├── NotificationHandler.client.lua ✅ shared — queue notifs (générique)
    ├── RebirthHUD.client.lua      ❌ BRF-specific — "BRAINROT_GOD" dans icone
    └── Combat/
        └── BatController.client.lua ✅ shared — animation swing + validation locale
```

---

## BrainRotFarm/src/ (25 fichiers — jeu spécifique)

```
BrainRotFarm/src/
├── ReplicatedStorage/
│   └── GameConfig.lua             ⭐ SEUL fichier à modifier pour reskins
│
├── ServerScriptService/
│   ├── Main.server.lua            ❌ BRF-specific — orchestrateur (450+ lignes)
│   ├── DataStoreManager.lua       ❌ BRF-specific — schéma BRF + DS "BrainRotIdleV1"
│   ├── LeaderboardSystem.lua      ❌ BRF-specific — panneaux 3D Studio
│   ├── ShopSystem.lua             🔶 hybride — logique générique, contenu BRF
│   ├── SprinklerSystem.lua        ❌ BRF-specific — arroseur accélère spawn
│   ├── TracteurSystem.lua         ❌ BRF-specific — auto-collect selon rareté
│   ├── ArbreSystem.lua            ❌ BRF-specific — système arbre agraire
│   ├── BaleSystem.lua             ❌ BRF-specific — bottes de paille
│   ├── SpawnManager.lua           ❌ BRF-specific — spawns ChampCommun
│   ├── CommunSpawner.lua          ❌ BRF-specific — spawner ChampCommun
│   ├── MutantGenerator.lua        ❌ BRF-specific — BR mutants (FlowerPot)
│   ├── SeedInventory.lua          ❌ BRF-specific — graines FlowerPot
│   ├── BoardSystem.lua            ❌ BRF-specific — panneaux progression base
│   └── DiscordWebhook.lua         ❌ BRF-specific — intégration Discord
│
├── ServerScriptService/Systems/
│   └── FlowerPotSystem/
│       └── FlowerPotGrowthSystem.lua ❌ BRF-specific — plantation BR MYTHIC/SECRET
│
└── StarterPlayer/StarterPlayerScripts/
    ├── SlotMenuHUD.client.lua     ❌ BRF-specific — menu slots base
    ├── ShopHUD.client.lua         ❌ BRF-specific — boutique upgrades
    ├── SeedsHUD.client.lua        ❌ BRF-specific — interface graines
    ├── FlowerPotHUD.client.lua    ❌ BRF-specific — interface FlowerPot
    └── CollectAllButton.client.lua ❌ BRF-specific — bouton ramasser tout
```

---

## Légende
- ✅ **shared** — 100% réutilisable cross-game tel quel
- ❌ **BRF-specific** — couplé à BrainRotFarm, ne pas utiliser pour reskins
- 🔶 **hybride** — base réutilisable mais contient des éléments BRF-specific
- ⭐ **SEUL fichier** à modifier pour reskins (GameConfig.lua)

---

## Statistiques
| Catégorie | Fichiers | %  |
|-----------|----------|----|
| shared (propre) | 22 | 31% |
| BRF-specific | 38 | 54% |
| hybride | 11 | 15% |
| **TOTAL** | **71** | **100%** |
