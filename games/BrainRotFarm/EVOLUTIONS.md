# 🚀 EVOLUTIONS — BrainRotFarm
> DobiGames — Fonctionnalités futures planifiées
> Dernière mise à jour : Mars 2026

---

## Légende
- 💡 Idée validée — à implémenter
- 🔨 En cours de développement
- ✅ Terminé
- ⭐ Priorité haute

---

## 1. EFFET WAOUH — Indicateur de progression visuel

**Concept :** Un champignon Brain Rot pousse dans chaque champ individuel,
proportionnellement au % de remplissage de la base du joueur.
Visible par tous les joueurs depuis toute la map.

**Stages visuels :**
| Stage | % Base | Visuel | Effet |
|---|---|---|---|
| 1 | 0-20% | Spore au sol | Quasi invisible |
| 2 | 20-40% | Petit champignon | Couleur terne |
| 3 | 40-60% | Champignon moyen | Commence à briller |
| 4 | 60-80% | Grand champignon | Aura légère |
| 5 | 80-99% | Champignon géant | Lumière pulsante |
| 6 | 100% | COLOSSAL | Visible map entière + particules + son |

**Notification à 100% :** `"🍄 Player3's field is FULL!"` → tous les joueurs

**Statut :** 💡 À implémenter
**Complexité :** 🟢 Faible — scale progressif sur modèle existant
**Impact waouh :** ⭐⭐⭐⭐⭐

---

## 2. EFFET WAOUH — L'Éruption de la Base

**Concept :** Quand un joueur remplit tous les spots de son dernier étage,
sa base "s'embrase" avec une éruption spectaculaire visible par tous.

**Séquence :**
```
Base 100% remplie
→ Camera shake
→ Fissure au centre de la base
→ BR jaillissent du sol comme un geyser (10 secondes)
→ Effet lumière dorée + lave
→ Notification tous les joueurs : "🌋 Player3's base is ERUPTING!"
→ BR éjectés collectables par tout le monde
→ Retour au calme
```

**Statut :** 💡 À implémenter
**Complexité :** 🟡 Moyenne — ParticleEmitters + camera shake + notification
**Impact waouh :** ⭐⭐⭐⭐⭐
**Viral TikTok :** ⭐⭐⭐⭐⭐

---

## 3. EFFET WAOUH — Le Trône du Roi BR

**Concept :** Le joueur en tête du leaderboard reçoit un trône doré
dans sa base, visible par tous. Si quelqu'un le dépasse, le trône se
déplace vers la nouvelle base du leader.

**Mécanique :**
```
1er du leaderboard depuis 5 min
→ Trône doré apparaît dans sa base
→ Personnage s'assoit automatiquement
→ Couronne flotte au-dessus de sa tête
→ BR rares orbitent autour de lui
→ Leaderboard : "👑 KING : Player3"
→ Si dépassé → trône se brise + se déplace
```

**Statut :** 💡 À implémenter
**Complexité :** 🟢 Faible — modèle + logique leaderboard existante
**Impact waouh :** ⭐⭐⭐⭐
**Impact rétention :** ⭐⭐⭐⭐⭐

---

## 4. RÉCOMPENSE HEBDOMADAIRE — Tracteur Rouge

**Concept :** Chaque semaine, le joueur ayant le plus joué reçoit
automatiquement le skin exclusif "Tracteur Rouge" pour 7 jours.
Visible par tous les autres joueurs.

**Fonctionnement :**
```
Tracking temps de jeu dans playerData.tempsJeuSemaine
→ Chaque lundi minuit UTC :
  → Script vérifie le top joueur de la semaine
  → Active skin Tracteur Rouge pour 7 jours
  → Webhook Discord : "🏆 Player3 est le Top Farmer !"
  → Reset des compteurs hebdomadaires
```

**Récompenses possibles :**
| Récompense | Pour qui | Durée |
|---|---|---|
| 🚜 Tracteur Rouge | Top joueur semaine | 7 jours |
| 👑 Couronne dorée | 1er leaderboard vendredi | 7 jours |
| 🌟 Aura BR Géant | Plus de BR collectés | 7 jours |
| 🏆 Badge semaine | Top 3 joueurs | Permanent |
| ⚡ Boost ×2 income | Top 5 joueurs | 24h |

**Contrainte Roblox :** Pas de redistribution de Robux (ToS).
Uniquement des cosmétiques et avantages in-game.

**Statut :** 💡 À implémenter
**Complexité :** 🟡 Moyenne — tracking + skin + webhook + reset hebdo
**Impact rétention :** ⭐⭐⭐⭐⭐

---

## 5. FLOWERPOT SYSTEM — Améliorations futures

**Concept :** Suite au système FlowerPot existant, plusieurs améliorations
visuelles et de game design à implémenter.

### 5.1 Plante + BR synchronisés (en cours)
```
La plante pousse en même temps que le BR dans le pot
→ Plante Studio (4 stages) ou procédurale (fallback)
→ MYTHIC : couleurs violettes + sparkles
→ SECRET : couleurs rouges + flammes
```

### 5.2 Daily Seed Panel
```
Bouton HUD permanent (bas gauche)
→ "🌱 Day 3/7" ou "🌱 Seed Ready!" (pulsant)
→ Clic → popup avec les 7 jours du cycle
→ Anti-écrasement : jamais écraser un BR en cours automatiquement
→ Choix du pot si tous occupés
```

### 5.3 ServerStorage/PlantModels
```
Créer dans Studio :
ServerStorage/PlantModels/
├── MYTHIC/
│   ├── Plant_Stage1 → Plant_Stage4
└── SECRET/
    ├── Plant_Stage1 → Plant_Stage4
```

**Statut :** 🔨 En cours
**Complexité :** 🟡 Moyenne

---

## 6. DISCORD — Système de récompenses communautaires

**Concept :** Utiliser le serveur DobiGames Discord comme hub
de communication avec les joueurs et canal de récompenses.

**Webhooks automatiques :**
```
#events   → Lucky Hour, Admin Abuse, Golden Event
#records  → BRAINROT_GOD capturé, records battus
#top-week → Annonce Top Farmer hebdomadaire
#dev-logs → Erreurs critiques (admin only)
```

**Statut :** 💡 À implémenter (serveur Discord créé ✅)
**Complexité :** 🟢 Faible — script Python + webhooks

---

## 7. BRAINROT KONG — Jeu n°2

**Concept :** Jeu séparé dans la factory DobiGames.
Tour gardée par Kong + BR Géant collectif + combat sorts.

**Voir :** `games/BrainRotKong/BRAINROT_KONG_DESIGN.md`

**Statut :** 📋 Game design documenté — développement après BrainRotFarm
**Complexité :** 🔴 Élevée

---

## 8. RESKINS — Factory DobiGames

**7 reskins prévus après validation de BrainRotFarm :**

| Jeu | Thème | Priorité |
|---|---|---|
| BrainRotZoo | Zoo / Animaux | 1 |
| BrainRotOcean | Océan | 2 |
| BrainRotGalaxy | Espace | 3 |
| BrainRotArmy | Militaire | 4 |
| BrainRotMine | Mine | 5 |
| BrainRotKitchen | Cuisine | 6 |
| MutantGrow | Mutation / Croissance | 7 |

**Principe :** modifier `GameConfig.lua` uniquement.
Tous les scripts `Common/` restent identiques.

**Statut :** 💡 En attente de la publication de BrainRotFarm

---

## 9. CONTENU TIKTOK — Pipeline automatique

**Phase 1 (dès publication) :** Filmer soi-même les moments forts
**Phase 2 (50+ joueurs) :** Recruter 2-3 créateurs de contenu joueurs
**Phase 3 (500+ joueurs) :** Pipeline semi-auto OBS + Python + webhooks

**Voir analyse complète dans les notes de conversation.**

**Statut :** 💡 Phase 1 à démarrer dès publication

---

## Roadmap synthétique

```
MAINTENANT
→ Finir les tests BrainRotFarm
→ Corriger bug TracteurSystem
→ Brancher Discord webhooks
→ Publish BrainRotFarm

APRÈS PUBLICATION (Mois 1)
→ Champignon progression visuel (#1)
→ Trône du Roi BR (#3)
→ Récompense hebdomadaire Tracteur Rouge (#4)
→ Filmer TikTok (Phase 1)

MOIS 2-3
→ Éruption de la base (#2)
→ FlowerPot améliorations (#5)
→ Premiers reskins (Zoo, Ocean, Galaxy)

MOIS 4-6
→ BrainRot Kong (développement)
→ Reskins restants
→ Pipeline TikTok automatisé
```
