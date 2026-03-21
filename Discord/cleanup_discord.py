# cleanup_discord.py
# Remove duplicate channels, categories, roles and webhooks on the DobiGames server

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

BASE_URL = f"https://discord.com/api/v10/guilds/{GUILD_ID}"

def get_channels():
    r = requests.get(f"{BASE_URL}/channels", headers=headers)
    return r.json()

def get_roles():
    r = requests.get(f"{BASE_URL}/roles", headers=headers)
    return r.json()

def delete_channel(channel_id, name):
    r = requests.delete(
        f"https://discord.com/api/v10/channels/{channel_id}",
        headers=headers
    )
    if r.status_code == 200:
        print(f"  [OK] Deleted: {name} ({channel_id})")
    else:
        print(f"  [ERR] {name} ({channel_id}): {r.status_code} {r.text}")

def delete_role(role_id, name):
    r = requests.delete(
        f"{BASE_URL}/roles/{role_id}",
        headers=headers
    )
    if r.status_code == 204:
        print(f"  [OK] Role deleted: {name} ({role_id})")
    else:
        print(f"  [ERR] Role {name} ({role_id}): {r.status_code} {r.text}")

def cleanup_channels():
    channels = get_channels()
    if not isinstance(channels, list):
        print(f"Error get_channels: {channels}")
        return

    # Group by name (case-insensitive), keep first, delete duplicates
    seen = {}
    to_delete = []

    for ch in channels:
        key = ch["name"].lower()
        if key not in seen:
            seen[key] = ch
        else:
            to_delete.append(ch)

    print(f"\n=== CHANNELS / CATEGORIES — {len(to_delete)} duplicate(s) to delete ===")
    for ch in to_delete:
        type_str = "Category" if ch["type"] == 4 else "Channel"
        print(f"  -> {type_str}: #{ch['name']} ({ch['id']})")
        delete_channel(ch["id"], ch["name"])

def cleanup_roles():
    roles = get_roles()
    if not isinstance(roles, list):
        print(f"Error get_roles: {roles}")
        return

    # Skip @everyone
    roles = [r for r in roles if r["name"] != "@everyone"]

    seen = {}
    to_delete = []

    for role in roles:
        key = role["name"].lower()
        if key not in seen:
            seen[key] = role
        else:
            to_delete.append(role)

    print(f"\n=== ROLES — {len(to_delete)} duplicate(s) to delete ===")
    for role in to_delete:
        print(f"  -> Role: {role['name']} ({role['id']})")
        delete_role(role["id"], role["name"])

def cleanup_webhooks():
    """Delete duplicate webhooks in each channel."""
    channels = get_channels()
    if not isinstance(channels, list):
        return

    print(f"\n=== WEBHOOKS ===")
    for ch in channels:
        if ch["type"] != 0:  # text channels only
            continue
        r = requests.get(
            f"https://discord.com/api/v10/channels/{ch['id']}/webhooks",
            headers=headers
        )
        if r.status_code != 200:
            continue
        webhooks = r.json()
        if not isinstance(webhooks, list):
            continue

        seen_wh = {}
        for wh in webhooks:
            key = wh["name"].lower()
            if key not in seen_wh:
                seen_wh[key] = wh
            else:
                rd = requests.delete(
                    f"https://discord.com/api/v10/webhooks/{wh['id']}",
                    headers=headers
                )
                if rd.status_code == 204:
                    print(f"  [OK] Webhook deleted: {wh['name']} in #{ch['name']}")
                else:
                    print(f"  [ERR] Webhook {wh['name']}: {rd.status_code}")

if __name__ == "__main__":
    print("Cleaning up duplicate entries on DobiGames Discord...\n")
    cleanup_channels()
    cleanup_roles()
    cleanup_webhooks()
    print("\nDone.")
