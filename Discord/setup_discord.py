# setup_discord.py
# Create the full DobiGames Discord server structure

import requests
import json
import os

_config = json.load(open(os.path.join(os.path.dirname(__file__), "..", "discord_config.json")))
BOT_TOKEN  = _config["bot_token"]
GUILD_ID   = "1483517459033227317"

headers = {
    "Authorization": f"Bot {BOT_TOKEN}",
    "Content-Type": "application/json"
}

BASE_URL = f"https://discord.com/api/v10/guilds/{GUILD_ID}"

# ═══════════════════════════════════
# CREATE A CATEGORY
# ═══════════════════════════════════
def create_category(name, position):
    r = requests.post(f"{BASE_URL}/channels", headers=headers, json={
        "name": name,
        "type": 4,  # GUILD_CATEGORY
        "position": position
    })
    data = r.json()
    print(f"Category created: {name} -> {data.get('id')}")
    return data.get("id")

# ═══════════════════════════════════
# CREATE A TEXT CHANNEL
# ═══════════════════════════════════
def create_channel(name, category_id, topic="", position=0):
    r = requests.post(f"{BASE_URL}/channels", headers=headers, json={
        "name": name,
        "type": 0,  # GUILD_TEXT
        "parent_id": category_id,
        "topic": topic,
        "position": position
    })
    data = r.json()
    print(f"  Channel created: #{name} -> {data.get('id')}")
    return data.get("id")

# ═══════════════════════════════════
# CREATE A WEBHOOK
# ═══════════════════════════════════
def create_webhook(channel_id, name):
    r = requests.post(
        f"https://discord.com/api/v10/channels/{channel_id}/webhooks",
        headers=headers,
        json={"name": name}
    )
    data = r.json()
    url = f"https://discord.com/api/webhooks/{data.get('id')}/{data.get('token')}"
    print(f"  Webhook created: {name} -> {url}")
    return url

# ═══════════════════════════════════
# CREATE A ROLE
# ═══════════════════════════════════
def create_role(name, color, mentionable=False):
    r = requests.post(f"{BASE_URL}/roles", headers=headers, json={
        "name": name,
        "color": color,
        "mentionable": mentionable
    })
    data = r.json()
    print(f"Role created: {name} -> {data.get('id')}")
    return data.get("id")

# ═══════════════════════════════════
# BUILD THE FULL STRUCTURE
# ═══════════════════════════════════
def setup_dobigames():
    print("\nBuilding DobiGames server...\n")
    webhooks = {}

    # --- ROLES ---
    print("=== ROLES ===")
    create_role("👑 Admin",          0xFFD700, mentionable=False)
    create_role("🔨 Dev",            0xFF6B35, mentionable=True)
    create_role("🌾 BrainRotFarmer", 0x00CC44, mentionable=True)
    create_role("🦍 Kong Slayer",    0x9B59B6, mentionable=True)
    create_role("💎 VIP",            0x3498DB, mentionable=False)

    # --- INFOS CATEGORY ---
    print("\n=== 📢 INFOS ===")
    cat_infos = create_category("📢 INFOS", 0)
    create_channel("announcements", cat_infos,
        topic="Official DobiGames announcements")
    canal_patch = create_channel("patch-notes", cat_infos,
        topic="Game updates and changelogs")
    create_channel("roadmap", cat_infos,
        topic="Upcoming features and content")

    # --- BRAINROTFARM CATEGORY ---
    print("\n=== 🌾 BRAINROTFARM ===")
    cat_farm = create_category("🌾 BRAINROTFARM", 1)

    canal_general = create_channel("general", cat_farm,
        topic="General BrainRotFarm discussion")
    canal_events  = create_channel("events", cat_farm,
        topic="Automatic events: Lucky Hour, Admin Abuse...")
    canal_records = create_channel("records", cat_farm,
        topic="Server records — BRAINROT GOD, full bases...")
    canal_bugs    = create_channel("bugs", cat_farm,
        topic="Bug reports")

    # BrainRotFarm webhooks
    webhooks["events"]  = create_webhook(canal_events,  "BrainRotFarm Events")
    webhooks["records"] = create_webhook(canal_records, "BrainRotFarm Records")

    # --- COMMUNITY CATEGORY ---
    print("\n=== 🎮 COMMUNITY ===")
    cat_comm = create_category("🎮 COMMUNITY", 2)

    create_channel("suggestions", cat_comm,
        topic="Share your ideas for the games")
    create_channel("screenshots", cat_comm,
        topic="Share your best moments")
    create_channel("giveaways",   cat_comm,
        topic="Robux contests")

    # --- ADMIN CATEGORY (private) ---
    print("\n=== 🔧 ADMIN ===")
    cat_admin = create_category("🔧 ADMIN", 3)

    canal_devlogs = create_channel("dev-logs",        cat_admin,
        topic="Automatic technical logs")
    canal_revenue = create_channel("revenue-tracking", cat_admin,
        topic="Robux revenue tracking")

    # Admin webhooks
    webhooks["dev"]     = create_webhook(canal_devlogs, "DobiGames DevLogs")
    webhooks["revenue"] = create_webhook(canal_revenue, "DobiGames Revenue")

    # --- SUMMARY ---
    print("\n" + "="*60)
    print("Structure created — copy these URLs into GameConfig.lua:")
    print("="*60)
    for name, url in webhooks.items():
        print(f"\nGameConfig.DiscordWebhook_{name.capitalize()} = \"{url}\"")
    print("\n" + "="*60)

    # Save to file
    with open("discord_webhooks.json", "w") as f:
        json.dump(webhooks, f, indent=2)
    print("\nURLs saved to discord_webhooks.json")

# ═══════════════════════════════════
# RUN
# ═══════════════════════════════════
if __name__ == "__main__":
    setup_dobigames()
