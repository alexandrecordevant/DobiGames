#!/usr/bin/env bash
# setup-dobigames.sh
# DobiGames — Génération d'un nouveau jeu depuis le template
# Usage : ./setup-dobigames.sh NomDuJeu "Nom Affiché"
# Exemple : ./setup-dobigames.sh BrainRotZoo "Brain Rot Zoo"

set -e

DOSSIER="$1"
NOM_AFFICHE="${2:-$1}"

if [ -z "$DOSSIER" ]; then
    echo "❌ Usage : ./setup-dobigames.sh NomDossier [\"Nom Affiché\"]"
    echo "   Exemple : ./setup-dobigames.sh BrainRotZoo \"Brain Rot Zoo\""
    exit 1
fi

if [ -d "games/$DOSSIER" ]; then
    echo "❌ Le dossier games/$DOSSIER existe déjà."
    exit 1
fi

echo "🚀 Création du jeu : $NOM_AFFICHE ($DOSSIER)"

# ── Créer la structure de dossiers ──────────────────────────────
mkdir -p "games/$DOSSIER/src/ReplicatedStorage/Common"
mkdir -p "games/$DOSSIER/src/ReplicatedStorage/Specialized"
mkdir -p "games/$DOSSIER/src/ServerScriptService/Common"
mkdir -p "games/$DOSSIER/src/ServerScriptService/Specialized"
mkdir -p "games/$DOSSIER/src/StarterPlayer/StarterPlayerScripts/Common"

# ── Copier les scripts Common depuis le template ─────────────────
cp -r "_template/src/ReplicatedStorage/Common/."            "games/$DOSSIER/src/ReplicatedStorage/Common/"
cp -r "_template/src/ServerScriptService/Common/."          "games/$DOSSIER/src/ServerScriptService/Common/"
cp -r "_template/src/StarterPlayer/StarterPlayerScripts/Common/." "games/$DOSSIER/src/StarterPlayer/StarterPlayerScripts/Common/"

# ── Copier les stubs Specialized depuis le template ──────────────
cp -r "_template/src/ReplicatedStorage/Specialized/."       "games/$DOSSIER/src/ReplicatedStorage/Specialized/"
cp -r "_template/src/ServerScriptService/Specialized/."     "games/$DOSSIER/src/ServerScriptService/Specialized/"

# ── Générer le default.project.json ─────────────────────────────
sed "s/GAME_NAME_PLACEHOLDER/$NOM_AFFICHE/g" "_template/default.project.json" \
    > "games/$DOSSIER/default.project.json"

echo "✅ Jeu créé : games/$DOSSIER"
echo ""
echo "📋 Prochaines étapes :"
echo "   1. Éditer games/$DOSSIER/src/ReplicatedStorage/Specialized/GameConfig.lua"
echo "      → NomDuJeu, IDs Game Pass, IDs Dev Products, DiscordWebhookURL"
echo "   2. Remplacer les stubs Specialized par les scripts spécifiques au jeu :"
echo "      → SpawnManager.lua, BaseProgressionSystem.lua, AssignationSystem.lua..."
echo "   3. Lancer Rojo dans Studio : rojo serve games/$DOSSIER/default.project.json"
echo "   4. Tester en Studio avant publication"
