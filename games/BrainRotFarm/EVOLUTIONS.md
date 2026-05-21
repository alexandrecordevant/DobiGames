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

## 6. PLANTE CARNIVORE INTERACTIVE — Nourrir pour muter ⭐

**Concept :** Une graine plantée dans le FlowerPot peut évoluer en **plante carnivore vivante**.
Le joueur peut alors lui **donner un BR** — la plante l'avale et le transforme en un **mutant
d'un nouveau genre**, impossible à obtenir autrement.

**Deux phases :**

**Phase 1 — La graine devient une plante carnivore**
```
Chance lors de la plantation d'une graine MYTHIC/SECRET :
→ MYTHIC seed  : 20% de chance de devenir une plante carnivore
→ SECRET seed  : 50% de chance de devenir une plante carnivore
→ Sinon        : comportement normal (mutant GALAXY/TOXIC/RAINBOW/VOID)

Visuel différencié dès le Stage 1 :
→ Couleur noire + bouche qui se forme progressivement
→ Animation "affamée" à Stage 4 (la plante réclame à manger)
```

**Phase 2 — Nourrir la plante carnivore**
```
ProximityPrompt "Nourrir" apparaît quand la plante est à Stage 4
→ Le joueur doit avoir un BR en carry
→ Il donne le BR : la plante l'avale (animation crunch)
→ Résultat après 5-10 min de digestion :
   BR COMMON/UNCOMMON donné  → mutant CORRUPTED  (×5 income)
   BR RARE/EPIC donné        → mutant ANCIENT    (×12 income)
   BR LEGENDARY donné        → mutant COSMIC     (×25 income)
   BR MYTHIC donné           → mutant DIVINE     (×50 income)
   BR SECRET donné           → mutant ABYSSAL    (×100 income)
```

**Nouveaux genres de mutants (exclusifs plante carnivore) :**

| Mutant | Source | Income mult. | Visuel |
|---|---|---|---|
| 💀 CORRUPTED | BR COMMON/UNCOMMON | ×5 | Noir craquelé, yeux rouges |
| 🏛️ ANCIENT | BR RARE/EPIC | ×12 | Pierre dorée, runes flottantes |
| 🌌 COSMIC | BR LEGENDARY | ×25 | Espace en miniature dans le corps |
| ✨ DIVINE | BR MYTHIC | ×50 | Blanc lumineux, ailes translucides |
| 🕳️ ABYSSAL | BR SECRET | ×100 | Portail noir absolu, distorsion espace |

**Équilibre :**
- La plante carnivore **consomme** le BR donné (sacrifice réel)
- Si le joueur ne nourrit pas la plante dans les 30 min → elle meurt (graine perdue)
- Un seul nourrissage par plante
- Aucun autre moyen d'obtenir ces 5 nouveaux genres → exclusivité forte

**Interaction avec Mutation Master (#1) :**
- 5 nouveaux badges possibles : CORRUPTED MASTER, ANCIENT MASTER...
- Ou un méga-badge "CARNIVORE GOD" pour les 5 genres en base simultanément

**Statut :** 💡 À implémenter
**Complexité :** 🟠 Haute — nouveau système de nourissage + 5 modèles mutants + balancement
**Impact rétention :** ⭐⭐⭐⭐⭐ (nouveaux objectifs, sacrifice stratégique)
**Impact monétisation :** ⭐⭐⭐⭐⭐ (Tracteur + LuckyCharm + SecretSeed = plus de SECRET à sacrifier)
**Viral TikTok :** ⭐⭐⭐⭐⭐ (premier ABYSSAL = clip garanti)
**Cible :** Update Semaine 2-3 (avec Plante Carnivore visuelle)

---

## 7. COSMÉTIQUES — Shop de skins & accessoires

**Concept :** Système de cosmétiques achetables en Robux — purement visuels,
sans impact sur le gameplay. Driver de rétention long terme et de revenus
récurrents indépendants de la progression.

**Catégories possibles :**

| Catégorie | Exemples | Prix estimé |
|---|---|---|
| **Trails** | Traînée derrière le joueur (galaxy, toxic, rainbow, void, fire...) | 49-99 R$ |
| **Auras** | Halo autour du personnage (identité visuelle) | 99-149 R$ |
| **Hat / accessoire** | Chapeau, couronne, casque de tracteur | 49-99 R$ |
| **Base skin** | Couleur/texture des spots de la base | 149 R$ |
| **Chemin skin** | Texture du sol de la ferme | 99 R$ |

**Pourquoi c'est important :**
- Les cosmétiques ne créent pas de pay-to-win → communauté tolérante
- Revenus Robux **après** que le joueur a fini les game passes fonctionnels
- Identité visuelle → viral (joueurs se montrent dans les clips TikTok)
- Grow a Garden a explosé en partie grâce aux watering can skins + auras

**Ce qui existe déjà :**
- Trails visuels déjà implémentés pour le Speed upgrade (`SpeedTrailClient.lua`)
- Aura BRAINROT GOD déjà prévue dans Mutation Master (#1)
- Mutation Master prévoit des "skin chemin" par mutation — mêmes assets réutilisables

**Ce qui manque :**
- Shop UI cosmétiques (onglet dédié ou section dans ShopHUD)
- DataStore : `playerData.cosmetics = { trail = nil, aura = nil, hat = nil }`
- Système d'équipement / preview en temps réel
- Assets 3D / textures (à créer en Studio)

**Statut :** 💡 À implémenter
**Complexité :** 🟡 Moyenne — UI shop + DataStore équipement + assets Studio
**Impact monétisation :** ⭐⭐⭐⭐⭐ (revenus long terme post-launch)
**Impact rétention :** ⭐⭐⭐⭐ (identité joueur, flex social)
**Viral TikTok :** ⭐⭐⭐⭐ (les auras/trails se voient dans les clips)
**Cible :** Update Semaine 4-6

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
→ FlowerPot Plante Carnivore visuelle (#2)
→ Plante Carnivore Interactive — nourrir pour muter (#6)
→ Enrichissement audio (partie 2) (#5)

UPDATE SEMAINE 3-4
→ Lucki Block (#3)
→ Luck achetable avec timer (#4)

UPDATE SEMAINE 4-6
→ Shop Cosmétiques — trails, auras, hats (#7)
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