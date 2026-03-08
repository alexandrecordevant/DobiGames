# 🎮 DobiGames — BrainRot Idle Engine Factory

## Structure
```
_template/     ← Template source (ne pas modifier directement)
games/         ← Les 8 jeux générés depuis le template
```

## Créer un nouveau jeu
```bash
cp -r _template/ games/NouveauJeu/
# Modifier games/NouveauJeu/src/ReplicatedStorage/Modules/GameConfig.lua
cd games/NouveauJeu && rojo serve
```

## Pipeline
1. `rojo serve` dans le dossier du jeu
2. Studio → Plugins → Rojo → Connect
3. Tester → Publish sous DobiGames group
