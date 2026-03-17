# 🎮 DobiGames — BrainRot Idle Engine Factory

## 🎮 Jeux DobiGames

| Jeu | Statut | Concept | Priorité |
|-----|--------|---------|----------|
| 🌾 BrainRotFarm | 🔨 En développement | Carry/farm idle + FlowerPots | 1 |
| 🦍 BrainRot Kong | 📋 En conception | Tower + BR Géant vs Kong | 2 |
| 🧬 MutantGrow | ❌ À faire | Mutation + croissance | 3 |
| 🦁 BrainRotZoo | ❌ À faire | Reskin Farm → Zoo | 4 |
| 🌊 BrainRotOcean | ❌ À faire | Reskin Farm → Ocean | 5 |
| 🚀 BrainRotGalaxy | ❌ À faire | Reskin Farm → Galaxie | 6 |
| 🪖 BrainRotArmy | ❌ À faire | Reskin Farm → Militaire | 7 |
| ⛏️ BrainRotMine | ❌ À faire | Reskin Farm → Mine | 8 |
| 🍳 BrainRotKitchen | ❌ À faire | Reskin Farm → Cuisine | 9 |

## 📁 Structure du repo
```
DobiGames/
├── _template/          ← moteur commun à tous les jeux
├── games/
│   ├── BrainRotFarm/   ← jeu 1 (flagship)
│   └── BrainRotKong/   ← jeu 2 (en conception)
└── README.md
```

## 🏭 Principe Factory
1. `_template/` contient toute la logique Common réutilisable
2. Chaque jeu = `GameConfig.lua` modifié + scripts Specialized
3. Lancer un nouveau jeu = copier `_template/` + remplir `GameConfig.lua`

## 📖 Game Design Documents
- [BrainRot Kong — GDD complet](games/BrainRotKong/BRAINROT_KONG_DESIGN.md)

## Pipeline Rojo
```bash
# Nouveau jeu depuis le template
cp -r _template/ games/NouveauJeu/
# Modifier games/NouveauJeu/src/ReplicatedStorage/Specialized/GameConfig.lua
cd games/NouveauJeu && rojo serve
```

1. `rojo serve` dans le dossier du jeu
2. Studio → Plugins → Rojo → Connect
3. Tester → Publish sous DobiGames group
