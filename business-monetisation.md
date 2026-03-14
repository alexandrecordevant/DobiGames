Roblox Cash Generation Expert
Profil Utilisateur

Dev expérimenté : web/backend, automatisation IA, MVP rapide
Objectif : 10 000 €/mois en 6 mois via Roblox
Contraintes : temps limité, déléguer max à l'IA, maintenance minimale
Budget initial : < 100€
Approche : volume de jeux + templates réutilisables + Claude pour le code Lua


État du Marché Roblox (Mars 2026)
⚠️ ALERTE SATURATION : Brain Rot Obby
Le marché Brain Rot obby est SATURÉ en mars 2026.

Steal a Brainrot : 47,4 milliards de visites, 23,4M joueurs concurrents (sept 2025)
Des centaines de clones Brain Rot publiés chaque semaine
Compétition féroce sur CTR/icônes/titres = difficile de percer
"Tous les top games Roblox sont maintenant des jeux brainrot" (créateur TikTok, fin 2025)

⚠️ Ne PAS miser uniquement sur Brain Rot obby.
🔥 Genres en croissance (Mars 2026)
GenreExemple pharePourquoi ça marcheComplexité IAIdle/AFK SimulatorGrow a Garden (21B+ visites, lancé mars 2026)Gameplay cozy, sessions courtes, dopamine régulière🟢 FaibleSocial HangoutsBrookhaven RP (69B visites)Expression d'identité, avatar customization, 0 objectif🟡 MoyenneCollection + Base BuildingSteal a Brainrot, Pet Simulator 99Économie de rareté, trading, événements limités🟡 MoyenneSkill-based CompetitiveTower of Hell, RIVALS (FPS)Pas de P2W, mastery pure, leaderboards🟢 Faible
Tendances Roblox 2026 (données récentes)

Sessions courtes : joueurs préfèrent entrer/sortir sans friction (idle games dominent)
Identity expression : avatars, poses, émotes, hangouts sociaux = spikes de découverte
Low-spec optimization : jeux qui tournent bien partout = meilleure rétention
Progression profonde : Blox Fruits prouve que les joueurs s'engagent sur systèmes complexes si récompenses visibles


Stratégie Core Révisée (Mars 2026)
Modèle recommandé : Portfolio Diversifié
Ne PAS faire : 10 obbys Brain Rot identiques (marché saturé)
FAIRE : 3-5 jeux bien différenciés, chacun ciblant un genre différent
Portfolio optimal (6 mois)
Mois 1-2 : 1 Idle/AFK Game (template maître)
  └─ Ex: "Grow a Pet" / "Farm Simulator" / "Collect Crystals"
  └─ Tech: système d'idle earnings, auto-clicker, prestige loops

Mois 2-3 : 1 Social Hangout (si compétences building)
  └─ Ex: "Vibe House" / "Roleplay City"
  └─ Tech: customization poussée, zones photos, émotes

Mois 3-4 : 1 Skill-based Competitive
  └─ Ex: Obby challenge (NON Brain Rot, thème original), Tower climber
  └─ Tech: leaderboards, no-checkpoint mode, speedrun timers

Mois 4-5 : 1 Collection Game (peut être Brain Rot si bien exécuté)
  └─ Ex: "Collect [X]" avec trading et événements
  └─ Tech: rareté, crafting, limited-time drops

Mois 5-6 : Doubler sur le(s) jeu(x) qui performent
  └─ Séquelles, variantes, updates majeures
Objectif par jeu : 1000-5000 Robux/mois → 5 jeux = 5k-25k Robux/mois = 175-875€/mois
Pour atteindre 10k€/mois = ~2,8M Robux/mois → nécessite 1-2 hits majeurs (>50k visites/mois) + plusieurs jeux stables
Pourquoi diversifier ?

Réduction du risque : si Brain Rot s'effondre, tu as d'autres revenus
Apprentissage multi-genre : tu identifies tes forces (obby? idle? social?)
Algo boost : Roblox favorise les créateurs qui innovent vs clone
Test de marché : tu découvres quel genre TU peux le mieux exécuter


4 Principes Impératifs de Game Design

Ces principes s'appliquent à CHAQUE jeu généré, sans exception.
Les vérifier comme une checklist avant tout publish.

1. Compréhension Instantanée

Le concept du jeu se résume en 1 phrase — si tu ne peux pas, le jeu est trop complexe
Exemples valides : "Saute sur des plateformes pour atteindre la fin" / "Fais pousser des plantes pour gagner de l'argent" / "Échappe au Skibidi Toilet géant"
Exemple invalide : "Explore le monde, collecte des objets et bats des ennemis"
Le titre du jeu = cette phrase raccourcie au maximum
En code : premier checkpoint/action visible dès le spawn, chemin évident, zéro tutoriel

2. Dopamine Régulière

Récompense visible toutes les 30-60 secondes :

Obbys : son + particules à chaque checkpoint
Idle games : notification "+1000 coins!" régulière, unlock de nouveau contenu
Collection games : animation satisfaisante à chaque nouveau "brainrot" obtenu


Progression toujours affichée ("Stage 7/30" / "Level 15" / "1,234 coins")
En code : SoundService + ParticleEmitter + GUI notifications

3. Privilégier la Clarté

UI minimaliste : 1-2 éléments HUD max à l'écran
Obstacles/objectifs visuellement distincts (contraste de couleur fort)
Pas de texte superflu, pas d'effets qui cachent le gameplay
En code : GUI épurée, BackgroundTransparency élevée, TextSize lisible mobile

4. Le Social

Leaderboard visible avec les scores/progression des autres joueurs
Badge à débloquer = partage naturel sur profil Roblox
Message/notification quand un ami dépasse ton score
En code : BadgeService + leaderboard global DataStore + notifications in-game


Template de Jeu par Genre
Genre 1 : Idle/AFK Simulator (🔥 TENDANCE 2026)
Pourquoi c'est hot : Grow a Garden a atteint 21B+ visites en quelques mois (lancé mars 2026), record de vitesse pour atteindre 1B de visites (33 jours)
Concept Core

Joueur plante/achète des générateurs passifs (arbres, usines, animaux, cristaux...)
Générateurs produisent de la monnaie au fil du temps (même offline)
Monnaie sert à acheter de meilleurs générateurs
Loop infini : upgrade → earn faster → unlock new tiers → prestige/reset pour bonus

Mécanique technique Lua
lua-- Générateur de base (ModuleScript)
local Generator = {}
Generator.__index = Generator

function Generator.new(type, baseRate, cost)
    local self = setmetatable({}, Generator)
    self.Type = type
    self.BaseRate = baseRate  -- coins par seconde
    self.Cost = cost
    self.Level = 1
    return self
end

function Generator:Upgrade()
    self.Level = self.Level + 1
    self.Cost = self.Cost * 1.5  -- coût croissant
end

function Generator:GetCurrentRate()
    return self.BaseRate * self.Level
end

-- Système d'idle earning (ServerScript)
-- Sauvegarde last login time, calcule earnings offline au retour
Monétisation Idle Games

2x Earnings Game Pass : 149 Robux (super populaire sur idle games)
Auto-Collector : 99 Robux (collecter les coins automatiquement)
Exclusive Generator : 299 Robux (générateur unique 5x plus rentable)
Developer Product "Boost 1hr" : 49 Robux (earnings x3 pendant 1h, répétable)

Checklist Idle Game
[ ] Générateurs ont un feedback visuel satisfaisant (animation quand ils produisent)
[ ] Notification "+X coins!" apparaît régulièrement
[ ] Système de prestige qui donne envie de restart (bonus permanent)
[ ] Leaderboard "Total Coins Earned All-Time"
[ ] Offline earnings fonctionnent (max 24h d'absence)
Timeline de dev Idle Game avec Claude
Jour 1 (3h) : Claude génère le GeneratorSystem.lua + DataStore + GUI
Jour 2 (3h) : Placement visuel des générateurs dans Studio + ajout animations
Jour 3 (2h) : Monétisation (Game Pass handler) + icône/description + publish
Difficulté IA : 🟢 Faible — système très formulaire, parfait pour génération code

Genre 2 : Obby (Skill-based, NON Brain Rot)
Mise à jour 2026 : Le marché Brain Rot obby est saturé. Si tu fais un obby, choisis un thème ORIGINAL.
Thèmes qui marchent encore (mars 2026)

Escape [Lieu Spécifique] : Escape Prison, Escape School, Escape Carnival
Tower Climb : Tower of Hell style, mais avec thème unique (cyberpunk, underwater, space)
Story-based Obby : narration entre chaque niveau (ex: sauver un personnage)
Nostalgia Obby : référence années 2000-2010 (pas Brain Rot = différenciation)

Éviter absolument

❌ "[BRAIN ROT] Obby Skibidi ☠️" — marché saturé, 0 chance de percer
❌ Tout ce qui contient "Skibidi", "Fanum Tax", "Rizz" dans le titre (sauf si tu as une twist unique)

Le reste des principes obby (checkpoints, VFX, monétisation) du skill original reste valide.

Genre 3 : Collection + Trading Game
Pourquoi c'est viable : Steal a Brainrot prouve le modèle (47B+ visites), mais tu peux appliquer à d'autres thèmes
Concept Core

Joueur possède une base avec des "collectibles" qui génèrent de l'argent
Collectibles ont des raretés (Common → Mythical)
Joueurs peuvent voler/trader les collectibles des autres
Système de crafting : combiner X collectibles = nouveau rare

Thèmes alternatifs à Brain Rot

Dragons / Creatures mythologiques
Voitures de luxe / Supercars
Gemmes / Cristaux magiques
Pets futuristes / Robots

Mécanique clé : Rareté + Événements
lua-- Système de rareté (identique à Steal a Brainrot)
local Rarities = {
    Common = {Weight = 60, MoneyPerSecond = 10},
    Uncommon = {Weight = 25, MoneyPerSecond = 50},
    Rare = {Weight = 10, MoneyPerSecond = 200},
    Epic = {Weight = 4, MoneyPerSecond = 1000},
    Legendary = {Weight = 0.9, MoneyPerSecond = 5000},
    Mythical = {Weight = 0.1, MoneyPerSecond = 25000}
}

-- Événement limité (ex: "Halloween Special Brainrot" disponible 3 jours)
-- = FOMO énorme, boost de joueurs massif

Genre 4 : Social Hangout (si compétences building)
Données 2026 : Brookhaven RP = 69B visites, jeu #1 all-time sur Roblox
Pourquoi c'est difficile pour toi : Nécessite du level design / building manuel (pas juste du code)
Si tu veux quand même essayer :

Utilise Toolbox Roblox pour assets gratuits (maisons, meubles, véhicules)
Focus sur customization avatar + poses/émotes
Zones "photo spots" pour selfies = viralité TikTok
Pas d'objectifs, juste un monde libre à explorer

Monétisation Social Hangout :

Game Pass "VIP House" : 199 Robux (maison exclusive)
Game Pass "All Vehicles" : 149 Robux
Developer Product "Furniture Pack" : 99 Robux répétable


Checklist Game Design (avant chaque publish)
[ ] Je comprends quoi faire en 5 secondes en regardant le spawn ?
[ ] Il y a un son/effet satisfaisant à chaque checkpoint ?
[ ] L'UI ne surcharge pas l'écran ?
[ ] Le leaderboard est visible dès le lancement ?

Monétisation Roblox — Playbook
Structure de monétisation recommandée par jeu
Jeu gratuit (TOUJOURS)
├── Game Pass "VIP" — 99 Robux (~1€)
│   └── Vitesse x2, effets cosmétiques, badge exclusif
├── Game Pass "Double XP" — 49 Robux
│   └── XP x2 pour débloquer des skins
├── Developer Product "Skip Level" — 25 Robux
│   └── Passer un niveau difficile (achat répétable)
└── Developer Product "Revive" — 15 Robux
    └── Continuer après une mort (achat répétable)
Taux de conversion réalistes

1000 visites → ~5-15 achats Game Pass (0.5-1.5%)
Revenu moyen par visite active : 0.03–0.08 Robux
Seuil rentable : 10 000 visites/mois par jeu

Taux de change Robux → €

1000 Robux = ~3.50€ (taux DevEx standard)
Pour 10k€/mois = ~2 857 000 Robux/mois
Avec 20 jeux à 10k visites/mois chacun = ~200k visites totales
Réaliste en mois 4-6 avec bonne exécution


Algorithme Roblox — Comment Fonctionner
Facteurs de ranking

CTR (Click-Through Rate) — icône + titre = priorité absolue
Retention — temps moyen en jeu (viser > 8 minutes)
Likes ratio — viser > 70% positifs
Sessions actives — boost au lancement (inviter des amis, alt accounts)
Fréquence de mise à jour — publier une update = boost d'algo

Stratégie de lancement
Jour 1 : Publier le jeu
Jour 2 : 10-20 sessions actives simultanées (amis, groupes Discord Roblox)
Jour 3-7 : Partager sur TikTok/YouTube Shorts avec gameplay Brain Rot
Semaine 2 : Publier une "update" même mineure pour regain d'algo
Icônes et titres qui convertissent

Titre : "[BRAIN ROT] Obby Impossible ☠️ SKIBIDI"
Icône : personnage Brain Rot coloré, fond flashy, chiffre "100 niveaux"
Thumbnail : screenshot gameplay avec overlay texte dramatique


Génération de Code Lua avec Claude
Template de prompt pour générer un obby complet
Tu es expert Roblox Studio et Lua.
Génère un script ServerScript complet pour un obby avec :
- [X] niveaux de difficulté croissante
- Checkpoint system (SpawnLocation par niveau)
- Leaderboard avec temps de completion
- Système de Game Pass VIP (vitesse x2)
- Developer Product "Skip Level" (25 Robux)
- Effets visuels Brain Rot : couleurs néon, sons rigolos
- Anti-exploit basique
Format : Script unique, commentaires en français, prêt à coller dans ServerScriptService
Modules Lua réutilisables à générer une fois
ModuleUtilitéPrioritéGamePassServiceVérifier/donner avantages Game Pass🔴 CritiqueCheckpointManagerSauvegarder progression joueur🔴 CritiqueLeaderboardServiceAfficher scores/temps🟡 ImportantVFXManagerEffets visuels (particules, sons)🟢 Nice-to-haveDataStoreSauvegarder données entre sessions🟡 Important
Anti-patterns à éviter (demander à Claude de les éviter)

Loops infinis côté client
RemoteEvents non sécurisés (exploit risk)
DataStore sans pcall (crash si Roblox down)


Pipeline de Production IA
Workflow complet pour 1 jeu en 3 jours
Jour 1 — Structure (2h)
1. Claude génère le ServerScript principal (obby logic + checkpoints)
2. Claude génère le GamePassHandler
3. Importer dans Roblox Studio, tester en solo
Jour 2 — Design (2h)
1. Toolbox Roblox : importer assets Brain Rot gratuits
2. Claude génère le script de placement automatique des obstacles
3. Ajuster les niveaux visuellement dans Studio
Jour 3 — Lancement (1h)
1. Claude génère description du jeu + tags optimisés
2. Midjourney/DALL-E génère l'icône (prompt fourni ci-dessous)
3. Publier + partager sur Discord Roblox dev
Prompt icône pour IA image
Roblox game icon, Brain Rot style, cartoon character with googly eyes
and distorted face, neon colors, obstacle course in background,
"OBBY" text, high contrast, mobile game icon style, 512x512

Scaling — Portfolio Diversifié (Stratégie 2026)
Mois 1-2 : Template Master + Premier Hit

1 Idle/AFK Game complet, testé, monétisé (template maître)
Tous les scripts modulaires réutilisables
Checklist de lancement validée
Objectif : identifier si l'idle genre fonctionne pour toi

Mois 2-3 : Deuxième Genre

1 Obby skill-based OU 1 Collection Game
Réutiliser les modules communs (DataStore, GamePass, Leaderboard)
Changer : genre, gameplay loop, thème visuel
Objectif : 2 jeux actifs, 2 genres testés

Mois 3-4 : Troisième Genre + Analyse

1 nouveau jeu dans le genre restant
Analyser les KPIs des 3 jeux :

Lequel a le meilleur CTR ?
Lequel a la meilleure retention (temps moyen) ?
Lequel monétise le mieux ?


Objectif : identifier ton "genre gagnant"

Mois 4-5 : Double Down

NE PAS lancer de nouveaux jeux random
Prendre le jeu #1 en performance
Créer 1-2 variantes/séquelles de ce jeu
Publier une grosse update sur le jeu original
Objectif : scaler ce qui marche

Mois 5-6 : Optimisation Revenus

Focus sur les 2-3 meilleurs jeux uniquement
Ajouter :

Merch Roblox (t-shirts du jeu) pour revenus passifs
Premium Payouts optimization
Événements limités (FOMO = boost de ventes)


Abandonner les jeux < 500 visites/semaine après 1 mois
Objectif : maximiser $/visite, pas volume de jeux

Règle d'Or 2026
Mieux vaut 3 jeux différenciés avec 10k visites/mois chacun
que 10 clones identiques avec 2k visites/mois chacun
Pourquoi ?

Algo Roblox pénalise les créateurs "spam" (beaucoup de jeux similaires)
Retention meilleure sur jeux uniques = algo boost
Maintenance : 3 jeux = gérable, 10 jeux = enfer
Apprentissage : tu deviens expert d'un genre vs médiocre sur tout


KPIs à Suivre (par jeu)
MétriqueSeuil OKSeuil BonFréquenceVisites/semaine par jeu> 500> 2000HebdoRetention (temps moyen)> 5 min> 10 minHebdoLike ratio> 60%> 75%HebdoRobux/mois total> 50k> 200kMensuelJeux actifs (>500 vis/sem)> 5> 15Mensuel

Ressources et Liens Utiles

Roblox DevHub : developer.roblox.com (API officielle)
Toolbox assets Brain Rot : chercher "UGC Brain Rot" dans Roblox Studio
Analytics : roblox.com/develop → Mes Expériences → Stats
DevEx (convertir Robux en €) : seuil minimum 50 000 Robux


Templates de Référence
ObbyMaster — Template Obby (généré mars 2026)
Template modulaire validé, 6 fichiers Lua prêts à coller dans Studio.
Cloner un jeu = modifier Config.lua uniquement + remplacer obstacles.
Structure complète
ObbyMaster/
├── ReplicatedStorage/Modules/Config.lua       ← ModuleScript — cerveau du jeu
├── ServerScriptService/Main.server.lua         ← Script — boot + création RemoteEvents
├── ServerScriptService/CheckpointManager.lua   ← ModuleScript — stages + DataStore + badge
├── ServerScriptService/GamePassHandler.lua     ← ModuleScript — VIP + Skip + Revive
├── ServerScriptService/LeaderboardService.lua  ← ModuleScript — top 10 global
└── StarterPlayerScripts/HUDController.client.lua ← LocalScript — HUD + VFX + shop
RemoteEvents créés automatiquement par Main.server.lua
StageUpdate · LeaderboardUpdate · AppliquerVIP · AcheterVIP · AcheterSkip · AcheterRevive · SkipStage · NotifAmi
Règles d'architecture impératives

ProcessReceipt toujours dans GamePassHandler — jamais ailleurs
Tous les DataStore calls enveloppés dans pcall()
Validation Skip Stage côté serveur uniquement
task.wait() partout — jamais wait()
Checkpoints = SpawnLocation nommées Stage_1 à Stage_N dans workspace.Checkpoints

Config.lua — paramètres clés à changer par jeu
luaNomDuJeu, TotalStages,
GamePassVIP.Id, ProduitSkipStage.Id, ProduitRevive.Id,
BadgeCompletionId,
CouleurPrimaire, CouleurSecondaire,   -- thème néon
SonCheckpoint, SonFinObby             -- IDs audio Roblox
Monétisation embarquée
ProduitPrixTypeVIP (vitesse x1.8)99 R$Game PassSkip Stage25 R$Developer Product (répétable)Revive15 R$Developer Product (répétable)
Checklist installation rapide
[ ] ModuleScript Config dans ReplicatedStorage/Modules
[ ] Script Main + 3 ModuleScripts dans ServerScriptService
[ ] LocalScript HUDController dans StarterPlayerScripts
[ ] Folder "Checkpoints" dans Workspace avec Stage_1..Stage_N SpawnLocations
[ ] RespawnTime = 0 dans Workspace properties
[ ] IDs Game Pass/Badge mis à jour dans Config.lua

IdleMaster — Template Idle/AFK Game (🆕 Mars 2026)
Template pour idle/simulator games type Grow a Garden. Code généré par Claude, prêt à l'emploi.
Structure complète
IdleMaster/
├── ReplicatedStorage/
│   ├── Modules/Config.lua              ← Configuration jeu + générateurs
│   └── Modules/GeneratorData.lua       ← Stats de chaque type de générateur
├── ServerScriptService/
│   ├── Main.server.lua                 ← Boot + RemoteEvents
│   ├── GeneratorSystem.lua             ← Système de générateurs + idle earnings
│   ├── GamePassHandler.lua             ← 2x Earnings + Auto-Collector + Boost
│   ├── PrestigeSystem.lua              ← Reset avec bonus permanent
│   └── DataStoreManager.lua            ← Sauvegarde progression + offline time
└── StarterPlayerScripts/
    └── IdleGUI.client.lua              ← GUI coins + shop + notifications
Générateurs types (exemples)
lua-- Dans GeneratorData.lua
local Generators = {
    Tree = {
        BaseRate = 10,          -- coins/seconde
        BaseCost = 100,
        UnlockLevel = 1,
        Model = "rbxassetid://..."  -- ID du modèle dans Toolbox
    },
    Crystal = {
        BaseRate = 50,
        BaseCost = 1000,
        UnlockLevel = 5,
        Model = "rbxassetid://..."
    },
    Factory = {
        BaseRate = 500,
        BaseCost = 25000,
        UnlockLevel = 15,
        Model = "rbxassetid://..."
    }
}
Système d'offline earnings
lua-- Dans GeneratorSystem.lua
function CalculateOfflineEarnings(player)
    local data = DataStore:GetAsync(player.UserId)
    local lastLogin = data.LastLogin or os.time()
    local currentTime = os.time()
    local secondsOffline = currentTime - lastLogin
    
    -- Max 24h d'offline earnings
    secondsOffline = math.min(secondsOffline, 86400)
    
    local totalRate = 0
    for _, gen in pairs(data.Generators) do
        totalRate = totalRate + gen:GetCurrentRate()
    end
    
    return totalRate * secondsOffline
end
Monétisation Idle Game
ProduitPrixTypeImpact2x Earnings149 R$Game PassDouble tous les gains (permanent)Auto-Collector99 R$Game PassCollecte coins auto toutes les 5sExclusive Generator299 R$Game PassGénérateur 5x plus rentable1hr Boost49 R$Dev ProductGains x3 pendant 1h (répétable)
Checklist installation rapide
[ ] Config + GeneratorData dans ReplicatedStorage/Modules
[ ] 5 ModuleScripts dans ServerScriptService
[ ] LocalScript IdleGUI dans StarterPlayerScripts
[ ] Folder "Generators" dans Workspace pour placer les modèles visuels
[ ] IDs Game Pass mis à jour dans Config.lua
[ ] Tester offline earnings : join → wait 5 min → rejoin → vérifier coins
Prompt Claude pour générer IdleMaster
Tu es expert Roblox Studio et Lua.
Génère un système complet d'Idle/AFK Game avec :
- 5 types de générateurs (Tree, Crystal, Factory, Robot, Dragon) avec upgrade system
- Système d'offline earnings (max 24h) sauvegardé dans DataStore
- Système de prestige (reset pour bonus x2 permanent)
- Game Pass "2x Earnings" + "Auto-Collector"
- Developer Product "Boost 1hr" (gains x3, 49 Robux)
- GUI avec compteur de coins, shop de générateurs, notifications "+X coins!"
- Effets visuels : particules quand générateur produit, son satisfaisant
- Anti-exploit : validation serveur pour tous les achats
Format : Scripts séparés par fichier, commentaires en français, prêt à coller dans Studio

Réponses Rapides aux Questions Fréquentes
"Combien de temps avant les premiers Robux ?"
→ 2-4 semaines après publication si lancement actif (Discord, TikTok)
"Faut-il un compte Roblox Premium pour DevEx ?"
→ Oui, Premium obligatoire + 30 000 Robux minimum sur le compte
"Peut-on générer tout le code avec Claude ?"
→ Oui à 80-90%. Le 10-20% restant = ajustements visuels dans Studio
"Combien coûte un Roblox Group ?"
→ 100 Robux (~0.35€). Indispensable pour centraliser les revenus multi-jeux
"Brain Rot c'est encore tendance en 2026 ?"
→ OUI mais marché SATURÉ. Steal a Brainrot domine avec 47B+ visites. Si tu fais du Brain Rot, il faut un twist unique ou une exécution exceptionnelle. Recommandation : explore idle games ou collection games avec thèmes alternatifs.
"Quel genre rapporte le plus ?"
→ Données mars 2026 : Idle/AFK games (Grow a Garden) et collection games (Steal a Brainrot) ont les meilleurs taux de monétisation. Social hangouts (Brookhaven) ont le plus de visites mais monétisation plus difficile.
"Combien de jeux faut-il pour atteindre 10k€/mois ?"
→ Réaliste : 1-2 hits (>50k visites/mois, ~500k-1M Robux/mois chacun) + 3-5 jeux stables (5-10k visites/mois). Total = ~2,8M Robux/mois = 10k€. Miser sur qualité > quantité.
"Les obbys marchent encore ?"
→ OUI si thème original. Tower of Hell reste dans le top 10. Évite les titres "[BRAIN ROT] Obby Impossible ☠️" saturés. Préfère "Escape [Lieu Unique]" ou tower climber avec thème fort.
"Idle games c'est facile à faire ?"
→ Techniquement OUI (code très formulaire = parfait pour IA). Grow a Garden prouve qu'un idle game bien exécuté peut exploser. Claude peut générer 90% du code.