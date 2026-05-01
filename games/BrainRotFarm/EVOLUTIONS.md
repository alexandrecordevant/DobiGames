# 🚀 EVOLUTIONS — BrainRotFarm
> DobiGames — Fonctionnalités futures planifiées
> Dernière mise à jour : Mai 2026

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
**Cible :** Update Semaine 1

---

## 2. EFFET WAOUH — Le Trône du Roi BR

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
**Cible :** Update Semaine 3

---

## 3. FLOWERPOT — Plante Carnivore

**Concept :** Suite au système FlowerPot existant, faire évoluer la plante
qui pousse dans le pot vers une **plante carnivore animée**, plus crédible
visuellement et thématique avec l'univers Brainrot.

**Stages visuels :**
```
Stage 1 (0%-25%) : Bourgeon mauve au sol, légers spasmes
Stage 2 (25%-50%) : Tige noire qui sort, feuilles dentelées
Stage 3 (50%-75%) : Bouche carnivore se forme + dents
Stage 4 (75%-99%) : Plante complète qui claque les mâchoires
Stage 5 (100%) : La plante CRACHE le BR muté avec animation
```

**Variantes par mutation :**

| Mutation | Couleur plante | Effet spécifique |
|---|---|---|
| ✨ GALAXY | Violet + sparkles galaxy | Étoiles tournent autour |
| ☠️ TOXIC | Vert toxique + bave | Gouttes acide qui tombent |
| 🌈 RAINBOW | Multicolore changeante | Arc-en-ciel qui pulse |
| 🕳️ VOID | Noir + portail | Aspire les particules autour |

**Bonus interactif :** quand le joueur s'approche, la plante claque les
mâchoires (animation idle) → effet "vivant".

**Statut :** 💡 À implémenter
**Complexité :** 🟡 Moyenne — modèles 4 stages + animations + variantes mutation
**Impact waouh :** ⭐⭐⭐⭐⭐
**Viral TikTok :** ⭐⭐⭐⭐⭐
**Cible :** Update Semaine 4-5

---

## 4. MUTATION MASTER — Système de badges progressifs

**Concept :** 4 badges à débloquer en remplissant la base avec un type de
mutation unique, plus 1 badge ultime pour les complétionnistes.

**Les 4 badges Master :**

| Badge | Trigger | Reward |
|---|---|---|
| 🎖️ **GALAXY MASTER** | 10 BRs Galaxy mutés simultanément dans la base | ×1.10 income permanent + skin chemin galaxy |
| 🎖️ **TOXIC MASTER** | 10 BRs Toxic mutés simultanément | ×1.10 income permanent + skin chemin toxic |
| 🎖️ **RAINBOW MASTER** | 10 BRs Rainbow mutés simultanément | ×1.15 income permanent + skin chemin rainbow |
| 🎖️ **VOID MASTER** | 10 BRs Void mutés simultanément | ×1.20 income permanent + skin chemin void |

**Le badge ultime :**

| Badge | Trigger | Reward |
|---|---|---|
| 🏆 **BRAINROT GOD** | Posséder les 4 badges Master | Aura permanente + skin "Mutation God" exclusif + trophée flottant au-dessus de la tête |

**Mécanique de tracking :**
```
DataStore : playerData.mutationMaster = {
    galaxy = false,
    toxic = false,
    rainbow = false,
    void = false,
    god = false
}

Vérification toutes les 30s :
→ Compter BRs actifs dans la base par type de mutation
→ Si compteur >= 10 et badge non débloqué :
   → Octroi badge automatique (BadgeService:AwardBadge)
   → Notification serveur "🎖️ Player3 a débloqué GALAXY MASTER!"
   → Webhook Discord
   → Update DataStore
   → Si tous les 4 → octroi BRAINROT GOD
```

**Anti-grief :** les BRs **dans la base** (slots) sont **immunisés au steal PVP**.
Seuls les BRs en carry peuvent être volés.

**Notification serveur :**
```
"🎖️ Player3 a débloqué GALAXY MASTER! (+10% income)"
"🏆 Player3 est devenu un BRAINROT GOD!"
```

**Statut :** 💡 À implémenter
**Complexité :** 🟡 Moyenne — DataStore tracking + détection + octroi badge + skins
**Effort dev :** 12-15h
**Impact rétention :** ⭐⭐⭐⭐⭐
**Impact game pass sales :** ⭐⭐⭐⭐ (joueurs voudront boost drops)
**Viral TikTok :** ⭐⭐⭐⭐ (premier BRAINROT GOD = clip)
**Cible :** Update Semaine 2 (premier gros update post-launch)

---

## Roadmap synthétique

```
DAY 1 (LANCEMENT)
→ Publish BrainRotFarm tel quel
→ Post Discord + premiers TikTok
→ Suivi Analytics

UPDATE SEMAINE 1 (J+7)
→ Champignon progression visuel (#1)

UPDATE SEMAINE 2 (J+14) ⭐ GROS UPDATE
→ Mutation Master Badges + BRAINROT GOD (#4)

UPDATE SEMAINE 3 (J+21)
→ Trône du Roi BR (#2)

UPDATE SEMAINE 4-5 (J+28 à J+35)
→ FlowerPot Plante Carnivore (#3)
```

---

## Critères de succès par update

| Update | KPI à atteindre |
|---|---|
| **Semaine 1** | Maintenir retention >10 min, like ratio >70% |
| **Semaine 2** | Boost retention à >15 min, +30% Game Pass sales |
| **Semaine 3** | Top farmer competitif visible (10+ joueurs en lutte leaderboard) |
| **Semaine 4-5** | TikTok viral si plante carnivore filmée par 3+ créateurs |

---

## Notes

- Toutes ces évolutions sont **conditionnées au succès du lancement**.
- Si BrainRotFarm <500 visites/semaine après J+14 → STOP les updates,
  pivot ou abandon (cf STRATEGY.md règle d'abandon).
- Si BrainRotFarm >5k visites/mois → ces updates sont prioritaires
  pour scaler ce qui marche.