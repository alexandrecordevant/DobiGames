# 🚀 EVOLUTIONS — Brainrot Farm Empire
> DobiGames — Fonctionnalités futures planifiées
> Dernière mise à jour : Mai 2026

---

## Légende
- 💡 Idée validée — à implémenter
- 🔨 En cours de développement
- ✅ Terminé
- ⭐ Priorité haute

---

## 1. MUTATION MASTER — Système de badges progressifs ⭐ GROS UPDATE

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
**Cible :** Update Semaine 1 (premier gros update post-launch)

---

## 2. FLOWERPOT — Plante Carnivore

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
**Cible :** Update Semaine 2-3

---

## 3. LUCKI BLOCK — Inspiré du jeu Arnold

**Concept :** Système de blocs surprises interactifs disséminés dans la map.
Quand le joueur clique/touche un Lucki Block, il reçoit une récompense aléatoire.

**Mécanique probable (à confirmer avec source Arnold) :**
```
- Spawn aléatoire toutes X minutes dans des zones définies
- Visuel : bloc coloré pulsant + sparkles
- Interaction : ProximityPrompt "Ouvrir le Lucki Block"
- Récompenses possibles :
  → Coins bonus (×100 à ×10000)
  → BR rare instantané
  → Boost income temporaire
  → Mutation gratuite
  → Multiplicateur Luck temporaire
```

**Anti-camp :** un joueur ne peut ouvrir que X Lucki Blocks par heure.

**Statut :** 💡 À implémenter (copy from Arnold)
**Complexité :** 🟡 Moyenne — spawn system + UI + récompenses
**Impact rétention :** ⭐⭐⭐⭐ (FOMO + récompenses random)
**Cible :** Update Semaine 3-4

---

## 4. LUCK ACHETABLE AVEC TIMER — Inspiré du jeu Arnold

**Concept :** Le joueur peut acheter un boost de "Luck" personnel
avec un timer visible, qui augmente les chances de spawn rare,
mutation, ou drop pendant une durée définie.

**Mécanique probable :**
```
- Bouton "Buy Luck" dans le shop (Robux ou coins)
- 3 paliers possibles :
  → Luck x2 pendant 15 min (50 R$ ou 100k coins)
  → Luck x3 pendant 30 min (149 R$ ou 500k coins)
  → Luck x5 pendant 1h (299 R$ ou 2M coins)

- Timer visible en HUD :
  → "⚡ Luck x3 : 14:32 restant"
  → Pulsation visuelle du HUD pendant actif

- Effet pendant la durée :
  → Spawn rate des rares augmenté
  → Drop chance mutation augmenté
  → ChampCommun trigger pour le joueur uniquement
```

**Différenciation vs Lucky Hour event :**
- Lucky Hour = event serveur automatique (toutes 2h)
- Luck achetable = personnel + à la demande

**Statut :** 💡 À implémenter (copy from Arnold)
**Complexité :** 🟡 Moyenne — Game Pass / Dev Product + timer client + boost logic
**Impact monétisation :** ⭐⭐⭐⭐⭐ (revenus directs Robux)
**Cible :** Update Semaine 3-4

---

## 5. ENRICHISSEMENT AUDIO — Plus de sons partout

**Concept :** Ajouter du feedback sonore dans tout le jeu pour
améliorer l'immersion et le "game feel".

**Zones à enrichir :**

| Zone | Sons à ajouter |
|---|---|
| **Pickup BR** | Son satisfaisant par rareté (différent COMMON vs SECRET) |
| **Deposit BR** | Son "cling" + accumulation coins |
| **Menus** | Clic ouverture/fermeture, hover boutons |
| **Shop achat** | Son d'achat réussi (différent Robux vs coins) |
| **Mutation success** | Son magique par type (Galaxy, Toxic, Rainbow, Void) |
| **Capture rare** | Son "wow" différencié par rareté |
| **Base** | Ambiance discrète (champignons qui poussent, vent doux) |
| **Tracteur** | Son moteur quand on conduit |
| **FuseMachine** | Son de fusion + ding fin |
| **FlowerPot** | Son de croissance + son final récolte |
| **Notification** | Son spécifique pour events, badges, levels |

**Statut :** 💡 À implémenter
**Complexité :** 🟢 Faible — ajout de Sound instances + triggers
**Impact game feel :** ⭐⭐⭐⭐⭐
**Cible :** Update Semaine 1-2 (peut être progressif)

---

## Roadmap synthétique

```
DAY 1 (LANCEMENT)
→ Publish Brainrot Farm Empire
→ Post Discord + premiers TikTok
→ Suivi Analytics

UPDATE SEMAINE 1 ⭐ GROS UPDATE
→ Mutation Master Badges + BRAINROT GOD (#1)
→ Enrichissement audio (partie 1) (#5)

UPDATE SEMAINE 2-3
→ FlowerPot Plante Carnivore (#2)
→ Enrichissement audio (partie 2) (#5)

UPDATE SEMAINE 3-4
→ Lucki Block (#3)
→ Luck achetable avec timer (#4)
```

---

## Critères de succès par update

| Update | KPI à atteindre |
|---|---|
| **Semaine 1** | Maintenir retention >10 min, like ratio >70%, premier BRAINROT GOD débloqué |
| **Semaine 2-3** | Boost retention à >15 min, viral TikTok plante carnivore |
| **Semaine 3-4** | +30% Game Pass sales (Luck achetable), FOMO Lucki Block actif |

---

## Notes

- Toutes ces évolutions sont **conditionnées au succès du lancement**.
- Si Brainrot Farm Empire <500 visites/semaine après J+14 → STOP les updates,
  pivot ou abandon (cf STRATEGY.md règle d'abandon).
- Si Brainrot Farm Empire >5k visites/mois → ces updates sont prioritaires
  pour scaler ce qui marche.
- Les fonctionnalités #3 et #4 (Lucki Block + Luck achetable) sont inspirées
  du jeu d'Arnold. **Copier le concept, pas le code.** Réécrire dans le style
  Brainrot Farm Empire.

---

**Version:** 2.0 — Mai 2026
**Usage:** @EVOLUTIONS.md dans Claude Code pour les prompts d'update