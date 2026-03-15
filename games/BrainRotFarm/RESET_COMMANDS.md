# Reset Commands — BrainRotFarm (TEST uniquement)

> Coller dans la **barre de commande Studio** (bas de l'Output, mode `Server`).
> Nécessite `GameConfig.TEST_MODE = true`.

---

## Reset joueur courant (DataStore effacé + kick)

```lua
game.ReplicatedStorage:WaitForChild("DEBUG_Reset"):FireServer("joueur")
```

Le joueur qui lance la commande est kické et revient avec des données vierges.

---

## Reset DataStore seulement (sans kick)

```lua
game.ReplicatedStorage:WaitForChild("DEBUG_Reset"):FireServer("data")
```

Les données sont effacées en DataStore. Le joueur garde sa session en cours.
Au prochain chargement (reconnexion), il repart de zéro.

---

## Reset DataStore d'un userId précis (sans kick)

```lua
game.ReplicatedStorage:WaitForChild("DEBUG_Reset"):FireServer("data", 123456789)
```

Remplacer `123456789` par le **UserId** cible.

---

## Reset tous les joueurs connectés

```lua
game.ReplicatedStorage:WaitForChild("DEBUG_Reset"):FireServer("tous")
```

Efface le DataStore et kicke tous les joueurs connectés (délai 0.5s entre chaque).

---

## Reset visuel de la base (sans toucher au DataStore)

```lua
game.ReplicatedStorage:WaitForChild("DEBUG_Reset"):FireServer("visuel")
```

Remet la base à son état visuel initial sans modifier les données persistées.
Utile pour déboguer `BaseProgressionSystem` indépendamment du DataStore.

---

## Auto-reset à chaque connexion

Dans [TestConfig.lua](src/ReplicatedStorage/Test/TestConfig.lua), mettre :

```lua
TestConfig.AutoResetOnJoin = true
```

Chaque joueur qui se connecte repart automatiquement de zéro (sans kick).
**Désactiver (`false`) pour tester l'étape 14 — sauvegarde et offline income.**

---

## Rappels sécurité

- Ces commandes sont **bloquées en production** (`TEST_MODE = false`).
- `DEBUG_Reset` RemoteEvent est **supprimé** au démarrage si `TEST_MODE = false`.
- Ce fichier et `ResetSystem.lua` ne doivent **jamais être copiés dans `_template/`**.
