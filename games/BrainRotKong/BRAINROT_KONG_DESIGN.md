# 🦍 BrainRot Kong — Game Design Document
> DobiGames Factory — Jeu n°2
> Statut : En conception
> Priorité : Après publication de BrainRotFarm

---

## 🎯 Concept en une phrase
Fais pousser un Brain Rot Géant en montant une tour gardée par Kong,
puis affronte-le en coopération avec tous les joueurs du serveur.

---

## 🔄 Boucle de jeu complète

### PHASE 1 — Montée de la tour (2-3 min par run)
```
Kong est au sommet d'une tour centrale
→ Il lance des boules en permanence vers les joueurs
→ Les joueurs montent en esquivant les boules
→ Plus tu montes, plus les BR sont rares :
   Bas de la tour    → COMMON / OG / RARE
   Mi-tour           → EPIC / LEGENDARY
   Sommet            → MYTHIC / SECRET (très rare)
→ Si tu meurs → tu lâches tes BR + tu retombes en bas
→ Option R$ : 🛡️ Shield (25 R$) — survivre 1 boule sans mourir
```

### PHASE 2 — Nourrissage du BR Géant (boucle sociale)
```
Le BR Géant est au centre de la map, visible par tous
→ Les joueurs déposent leurs BR récoltés sur la Feeding Zone
→ Chaque BR déposé = points de croissance :
   COMMON       → +1 pt
   OG           → +2 pts
   RARE         → +5 pts
   EPIC         → +15 pts
   LEGENDARY    → +50 pts
   MYTHIC       → +150 pts
   SECRET       → +400 pts
→ Classement de contribution visible en temps réel
→ Le BR Géant grossit visuellement selon la jauge
→ Option R$ : 💪 Power Feed (49 R$) → +500 pts instantanés
```

### PHASE 3 — Seuil atteint → Vote combat
```
Quand la jauge est pleine (ex: 10 000 pts)
→ Les 3 top contributeurs peuvent voter pour lancer le combat
→ Countdown 30s visible par tous
→ Notification : "⚔️ KONG FIGHT in 30s! Get your spells ready!"
→ Tension maximale
```

### PHASE 4 — Combat épique (30-60 secondes)
```
Animation : BR Géant se lève et affronte Kong
→ Barres de vie visibles pour les deux
→ Combat automatique en temps réel
→ TOUS les joueurs peuvent lancer des sorts :

  Sort              Effet                    Obtention
  ──────────────────────────────────────────────────────
  ⚡ Thunder Strike  -500 HP Kong             Gratuit (1/combat)
  💚 Heal           +200 HP BR Géant          Gratuit (1/combat)
  🔥 Fire Blast     -1000 HP + brûlure 3s    15 R$
  🧊 Ice Freeze     Kong ralenti 5s           25 R$
  🌪️ Tornado        Kong désorienté 3s        25 R$
  ⚔️ Rage Mode      BR Géant attaque ×2 / 5s 35 R$
  💥 Mega Blast     -3000 HP (sort ultime)    99 R$

→ Feed en temps réel : "🔥 Player3 used Fire Blast! -1000 HP Kong!"
→ Déclencheur achat optimal : Kong à 20% HP
  → Notification : "⚠️ Kong almost dead! Use your spells!"
```

### PHASE 5A — Victoire 🎉
```
→ Animation : Kong tombe + explosion de particules
→ Récompenses proportionnelles à la contribution :
  🥇 Top 1 → ×3 coins + Aura dorée 10min + Badge round
  🥈 Top 2 → ×2 coins + Aura argentée + 2 sorts gratuits suivant round
  🥉 Top 3 → ×1.5 coins + Aura bronze + 1 sort gratuit
  Autres   → ×1 coins
→ Reset → nouveau cycle recommence
→ Record serveur mis à jour si nouveau record
```

### PHASE 5B — Défaite 💀
```
→ Animation : Kong détruit le BR Géant
→ Les joueurs gardent 50% de leurs coins (pas de punition totale)
→ Option R$ : 🔄 Revive (99 R$) → repart à 50% de la jauge
→ Reset
```

---

## 🏆 Système de Prestige

### Récompenses immédiates (par round)

| Rang | Récompense |
|------|-----------|
| 🥇 Top 1 | Aura dorée 10min + ×3 coins + déclenche combat en premier |
| 🥈 Top 2 | Aura argentée + ×2 coins + 2 sorts gratuits |
| 🥉 Top 3 | Aura bronze + ×1.5 coins + 1 sort gratuit |
| Autres | ×1 coins |

### Récompenses de prestige (cumulatives)
```
10 victoires Top 1  → Titre "Kong Slayer" sous le pseudo
25 victoires Top 1  → Couronne dorée permanente
50 victoires Top 1  → Skin exclusif "BR Légendaire"
```

---

## 💰 Monétisation

### Game Passes (achat unique)

| Pass | Prix | Effet |
|------|------|-------|
| 🛡️ Shield Pass | 149 R$ | Shield permanent (1/run) |
| 👑 VIP Aura | 49 R$ | Aura dorée permanente visible par tous |
| ⚡ Spell Master | 199 R$ | Sorts gratuits à chaque combat |
| 🚀 Speed Climber | 99 R$ | Vitesse de montée ×1.5 |
| 💎 Lucky Drops | 99 R$ | BR rares ×2 dans la tour |

### Developer Products (achat répétable)

| Produit | Prix | Effet |
|---------|------|-------|
| 🛡️ Shield (1x) | 25 R$ | Survivre 1 boule |
| 💪 Power Feed | 49 R$ | +500 pts croissance |
| 🔥 Fire Blast | 15 R$ | Sort combat |
| 🧊 Ice Freeze | 25 R$ | Sort combat |
| 🌪️ Tornado | 25 R$ | Sort combat |
| ⚔️ Rage Mode | 35 R$ | Sort combat |
| 💥 Mega Blast | 99 R$ | Sort ultime |
| 🔄 Revive BR | 99 R$ | Relance à 50% après défaite |

### Estimation revenus
```
6 joueurs / serveur, ~10 combats/jour :
  2× Fire Blast     →  30 R$
  1× Rage Mode      →  35 R$
  1× Mega Blast     →  99 R$
  Total/jour        → ~164 R$/serveur
  ×30 jours         → ~4 920 R$/mois/serveur
  ×50 serveurs      → ~246 000 R$/mois
  → DevEx (~0.0035€) → ~860 €/mois
  (hors Game Passes)
```

---

## 🗺️ Structure de la map
```
Centre de la map :
├── Tour centrale (15-20 étages)
│   ├── Kong au sommet (modèle géant, animé)
│   ├── Plateformes à escalader
│   ├── BR qui spawent sur les plateformes
│   └── Boules lancées par Kong en permanence
│
├── BR Géant (zone centrale, visible de partout)
│   ├── Scale augmente avec la jauge
│   ├── Aura change de couleur selon la force
│   └── Feeding Zone au pied (ProximityPrompt)
│
└── Spawn des joueurs (autour de la tour)
    ├── Leaderboard contribution visible
    ├── Classement top contributeurs
    └── Barres de vie pendant le combat
```

---

## 📈 Rétention

### Boucles de rétention
```
Court terme (2-3 min)  : Montée de la tour
Moyen terme (15-20 min): Nourrir le BR Géant jusqu'au combat
Long terme (jours)     : Accumuler titres + prestige
```

### Mécaniques de rétention
- **Streak quotidien** : 7 jours consécutifs → BR Géant de départ plus fort
- **Saisons** : Kong évolue (doré, glace, feu...) — nouveau contenu sans nouveau code
- **Records serveur** : visible sur leaderboard, pousse à battre
- **Défaite non punitive** : 50% coins conservés → recommencent au lieu de partir
- **Classement contribution** : compétition entre joueurs = sessions plus longues

---

## 🔧 Architecture technique

### Fichiers Specialized (uniques à BrainRot Kong)
```
ServerScriptService/Specialized/
├── TowerSpawner.lua        ← spawn BR dans la tour + boules Kong
├── GiantBRSystem.lua       ← croissance BR Géant + jauge
├── KongCombatSystem.lua    ← combat automatique + sorts
├── ContributionSystem.lua  ← classement contribution
└── GameConfig.lua          ← toutes les valeurs du jeu
```

### Fichiers Common (réutilisés depuis BrainRotFarm)
```
ServerScriptService/Common/
├── DataStoreManager.lua
├── AssignationSystem.lua
├── IncomeSystem.lua
├── LeaderboardSystem.lua
├── MonetizationHandler.lua
├── EventManager.lua
├── DiscordWebhook.lua
└── Main.server.lua
```

### GameConfig.lua — Clés spécifiques
```lua
GameConfig.NomDuJeu           = "BrainRot Kong"
GameConfig.MaxBases           = 6
GameConfig.TowerConfig        = { nbEtages=15, hauteurEtage=8 }
GameConfig.KongConfig         = { hpBase=10000, vitesseBoules=20 }
GameConfig.GiantBRConfig      = { jaugeMax=10000, scaleMax=5.0 }
GameConfig.SpellsConfig       = { ... }
GameConfig.ContributionConfig = { ... }
GameConfig.SaisonsConfig      = { saison=1, nom="Classic Kong" }
```

---

## 🚀 Roadmap développement
```
Étape 1 : Map + tour + Kong animé (Studio)
Étape 2 : TowerSpawner (BR spawent dans la tour)
Étape 3 : GiantBRSystem (croissance + jauge)
Étape 4 : KongCombatSystem (combat + sorts)
Étape 5 : ContributionSystem (classement)
Étape 6 : Monétisation (Game Passes + Products)
Étape 7 : Tests + équilibrage
Étape 8 : Publish
```

---

## ✅ Checklist avant publish
- [ ] Concept compréhensible en 5 secondes ?
- [ ] Dopamine régulière (chaque run = récompense) ?
- [ ] UI épurée ?
- [ ] Leaderboard contribution visible dès le spawn ?
- [ ] Points d'achat R$ naturels et non intrusifs ?
- [ ] Combat épique et clipable TikTok ?
