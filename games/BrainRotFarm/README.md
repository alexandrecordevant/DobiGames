# BrainRotFarm

## ServerScriptService/Common/
- **Main.server.lua** — Boot principal : charge tous les modules, crée les RemoteEvents, connecte PlayerAdded/Removing
- **DataStoreManager.lua** — Sauvegarde et chargement des données joueur (DataStore)
- **SpawnManager.lua** — Spawn des BR dans les champs individuels de chaque base
- **CommunSpawner.lua** — Spawn des BR dans la zone commune (MYTHIC + SECRET)
- **LeaderboardSystem.lua** — Leaderstats in-game et classement Discord hebdomadaire
- **ShopSystem.lua** — Achats d'upgrades et items via ProximityPrompt
- **EventVisuals.lua** — Effets visuels et gameplay pendant les events (NightMode, MeteorDrop, Rain…)
- **DiscordWebhook.lua** — Notifications Discord (captures rares, Top Farmer hebdo)
- **Events/EventMeteorDrop.lua** — Event pluie de météorites
- **Events/EventNightMode.lua** — Event nuit (ambiance + boost)
- **Events/EventRain.lua** — Event pluie

## ServerScriptService/Specialized/
- **FlowerPotSystem.lua** — Pots de fleurs : faire pousser des BR rares avec un timer
- **SprinklerSystem.lua** — Arroseur rotatif sur la base (accélère le spawn)
- **TracteurSystem.lua** — Tracteur qui collecte automatiquement les BR au-dessus d'un seuil de rareté

## ReplicatedStorage/Specialized/
- **GameConfig.lua** — Configuration centrale : rarités, upgrades, rebirth, events, shop
- **BrainrotSpawnConfig.lua** — Poids et valeurs de spawn par rareté

## ReplicatedStorage/Test/
- **TestConfig.lua** — Paramètres des tests (AutoResetOnJoin, intervalles réduits)
- **TestRunner.lua** — Tests automatisés en Studio
- **ResetSystem.lua** — Reset complet des données joueur (TEST_MODE uniquement)

## StarterPlayerScripts/Common/
- **FlowerPotHUD.client.lua** — UI des pots (timer, bouton récolte, états)
- **ShopHUD.client.lua** — Interface du shop (upgrades, items)
- **RebirthHUD.client.lua** — Barre de progression Rebirth, bouton pulse, animation flash

## shared-lib
- **server/AssignationSystem.lua** — Assignation base + téléportation spawn
- **server/BaseProgressionSystem.lua** — Déblocage des spots de base
- **server/CarrySystem.lua** — Ramassage et transport des BR
- **server/DropSystem.lua** — Dépôt des BR sur les spots, visuels, revenus
- **server/RebirthSystem.lua** — Rebirth : reset progression contre multiplicateur permanent
- **server/EventManager.lua** — Events automatiques
- **server/IncomeSystem.lua** — Revenus passifs
- **server/MonetizationHandler.lua** — Game Passes
- **server/Events/EventGolden.lua** — Event Golden
- **client/HUDController.client.lua** — HUD principal
- **shared/CollectSystem.lua** — Multiplicateur de collecte
- **shared/UpgradeSystem.lua** — Upgrades tier/prestige
