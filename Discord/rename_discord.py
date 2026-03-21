# rename_discord.py
# Fix all French channel names, category names, topics and role names on the server

import requests
import json
import os

_config = json.load(open(os.path.join(os.path.dirname(__file__), "..", "discord_config.json")))
BOT_TOKEN = _config["bot_token"]
GUILD_ID  = "1483517459033227317"

headers = {
    "Authorization": f"Bot {BOT_TOKEN}",
    "Content-Type": "application/json"
}

BASE_URL    = f"https://discord.com/api/v10/guilds/{GUILD_ID}"
CHANNEL_URL = "https://discord.com/api/v10/channels"

# ─── Channel / category name remapping ───────────────────────────────────────
NAME_MAP = {
    "général":          "general",
    "general":          "general",
    "règles":           "rules",
    "regles":           "rules",
    "annonces":         "announcements",
    "communauté":       "community",
    "communaute":       "community",
}

# ─── Channel topic remapping (exact match, case-insensitive) ──────────────────
TOPIC_MAP = {
    "annonces officielles dobigames":               "Official DobiGames announcements",
    "mises à jour des jeux":                        "Game updates and changelogs",
    "ce qui arrive bientôt":                        "Upcoming features and content",
    "discussion générale brainrotfarm":             "General BrainRotFarm discussion",
    "events automatiques lucky hour, admin abuse...": "Automatic events: Lucky Hour, Admin Abuse...",
    "records du serveur — brainrot god, bases remplies...": "Server records — BRAINROT GOD, full bases...",
    "rapports de bugs":                             "Bug reports",
    "proposez vos idées pour les jeux":             "Share your ideas for the games",
    "partagez vos meilleurs moments":               "Share your best moments",
    "concours robux":                               "Robux contests",
    "logs techniques automatiques":                 "Automatic technical logs",
    "suivi revenus robux":                          "Robux revenue tracking",
    "règles du serveur dobigames":                  "DobiGames server rules",
}

# ─── Role name remapping ──────────────────────────────────────────────────────
ROLE_MAP = {
    # No French role names expected, but just in case
}

def patch(url, data):
    r = requests.patch(url, headers=headers, json=data)
    return r.status_code, r.json()

def fix_channels():
    r = requests.get(f"{BASE_URL}/channels", headers=headers)
    channels = r.json()
    if not isinstance(channels, list):
        print(f"[ERR] Could not fetch channels: {channels}")
        return

    print(f"\n=== CHANNELS / CATEGORIES ({len(channels)} total) ===")
    for ch in channels:
        if not isinstance(ch, dict):
            continue

        updates = {}
        ch_name  = ch.get("name", "")
        ch_topic = (ch.get("topic") or "").strip()

        # Fix name
        new_name = NAME_MAP.get(ch_name.lower())
        if new_name and new_name != ch_name:
            updates["name"] = new_name

        # Fix topic (text channels only)
        if ch.get("type") == 0 and ch_topic:
            new_topic = TOPIC_MAP.get(ch_topic.lower())
            if new_topic:
                updates["topic"] = new_topic

        if updates:
            status, result = patch(f"{CHANNEL_URL}/{ch['id']}", updates)
            if status == 200:
                changes = []
                if "name" in updates:
                    changes.append(f"name: '{ch_name}' -> '{updates['name']}'")
                if "topic" in updates:
                    changes.append(f"topic updated")
                print(f"  [OK] #{ch_name}: {', '.join(changes)}")
            else:
                print(f"  [ERR] #{ch_name}: {status} {result}")
        else:
            print(f"  [--] #{ch_name}: already OK")

def fix_roles():
    r = requests.get(f"{BASE_URL}/roles", headers=headers)
    roles = r.json()
    if not isinstance(roles, list):
        print(f"[ERR] Could not fetch roles: {roles}")
        return

    print(f"\n=== ROLES ({len(roles)} total) ===")
    for role in roles:
        if not isinstance(role, dict) or role.get("name") == "@everyone":
            continue

        role_name = role.get("name", "")
        new_name  = ROLE_MAP.get(role_name.lower())

        if new_name and new_name != role_name:
            status, result = patch(f"{BASE_URL}/roles/{role['id']}", {"name": new_name})
            if status == 200:
                print(f"  [OK] Role '{role_name}' -> '{new_name}'")
            else:
                print(f"  [ERR] Role '{role_name}': {status} {result}")
        else:
            print(f"  [--] {role_name}: already OK")

if __name__ == "__main__":
    print("Renaming French references on DobiGames Discord...\n")
    fix_channels()
    fix_roles()
    print("\nDone.")
