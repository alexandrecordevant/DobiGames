# shared-lib

## server/
- **AssignationSystem.lua** — Assigne une base unique à chaque joueur, gère la téléportation au spawn (via callback `GetSpawnCFrame` injecté par Main)
- **CarrySystem.lua** — Ramassage des BR, transport en main, dépôt sur spot doré (callback `OnCarryChange` optionnel pour notifier d'autres systèmes)
- **DropSystem.lua** — Persistance des BR déposés sur les spots de la base, visuels mini-modèles, SurfaceGui, récupération/remplacement
- **RebirthSystem.lua** — Rebirth : reset progression contre multiplicateur permanent (callbacks Config + IsProgressionComplete + OnRebirthComplete)
- **BaseProgressionSystem.lua** — Déblocage progressif des étages et spots de la base selon la progression du joueur
- **EventManager.lua** — Déclenchement des events automatiques (Lucky Hour, Admin Abuse, etc.)
- **IncomeSystem.lua** — Boucle de revenus passifs (coins/sec par BR déposé)
- **MonetizationHandler.lua** — Vérification et attribution des Game Passes au join
- **Events/EventGolden.lua** — Event Golden : tous les BR deviennent dorés, gains ×5 pendant 60s

## client/
- **HUDController.client.lua** — HUD principal : affichage des coins, tier, VFX de collecte

## shared/
- **CollectSystem.lua** — Calcul du multiplicateur de collecte et du revenu offline
- **UpgradeSystem.lua** — Calcul des coûts et application des upgrades tier/prestige
