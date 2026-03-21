# configure_discord.py
# Full configuration of the DobiGames Discord server
# Run AFTER setup_discord.py

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

BASE_URL    = f"https://discord.com/api/v10/guilds/{GUILD_ID}"
CHANNEL_URL = "https://discord.com/api/v10/channels"

# ═══════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════

def get(url):
    r = requests.get(url, headers=headers)
    return r.json()

def patch(url, data):
    r = requests.patch(url, headers=headers, json=data)
    return r.json()

def post(url, data):
    r = requests.post(url, headers=headers, json=data)
    return r.json()

def find_channel(name):
    channels = get(f"{BASE_URL}/channels")
    for ch in channels:
        if isinstance(ch, dict) and ch.get("name") == name:
            return ch.get("id")
    return None

def find_role(name):
    roles = get(f"{BASE_URL}/roles")
    for role in roles:
        if isinstance(role, dict) and role.get("name") == name:
            return role.get("id")
    return None

# ═══════════════════════════════════════════════════════
# 1. VERIFICATION LEVEL
# ═══════════════════════════════════════════════════════

def configure_verification():
    print("\n=== VERIFICATION ===")
    r = patch(BASE_URL, {
        "verification_level": 2,            # MEDIUM
        "explicit_content_filter": 2,       # All members
        "default_message_notifications": 1  # Mentions only
    })
    if r.get("id"):
        print("  [OK] Verification level: Medium")
        print("  [OK] Explicit content filter: Enabled")
        print("  [OK] Notifications: Mentions only")
    else:
        print(f"  [ERR] {r}")

# ═══════════════════════════════════════════════════════
# 2. #rules CHANNEL — Create + post rules
# ═══════════════════════════════════════════════════════

def configure_rules(roblox_link="https://www.roblox.com"):
    print("\n=== RULES ===")

    channel_id = find_channel("rules")
    if not channel_id:
        print("  #rules not found — creating automatically...")
        channels = get(f"{BASE_URL}/channels")
        cat_infos = next(
            (c["id"] for c in channels
             if isinstance(c, dict) and c.get("type") == 4 and "info" in c.get("name", "").lower()),
            None
        )
        r = post(f"{BASE_URL}/channels", {
            "name": "rules",
            "type": 0,
            "parent_id": cat_infos,
            "topic": "DobiGames server rules",
            "position": 0
        })
        channel_id = r.get("id")
        if not channel_id:
            print(f"  [ERR] Could not create #rules: {r}")
            return
        print(f"  [OK] #rules created ({channel_id})")

    content = f"""
🎮 **Welcome to the official DobiGames server!**

Play our Roblox games → {roblox_link}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 **SERVER RULES**

**1.** Respect all members — zero toxicity
**2.** No spam, advertising, or NSFW content
**3.** Use the right channel
**4.** Report bugs in #bugs
**5.** No sharing of cheats or Roblox exploits → instant ban
**6.** Have fun and farm Brain Rots! 🌾

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏆 **ROLES**
🌾 **BrainRotFarmer** — Default member (automatic)
💎 **VIP** — Game Pass owner
👑 **Kong Slayer** — Top player of the week
🔨 **Dev** — DobiGames team

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

By joining this server, you agree to these rules. 🎮
"""

    r = post(f"{CHANNEL_URL}/{channel_id}/messages", {"content": content})
    if r.get("id"):
        print("  [OK] Rules posted in #rules")
    else:
        print(f"  [ERR] {r}")

# ═══════════════════════════════════════════════════════
# 3. PERMANENT INVITE LINK
# ═══════════════════════════════════════════════════════

def create_permanent_invite():
    print("\n=== PERMANENT INVITE ===")

    channel_id = find_channel("general")
    if not channel_id:
        print("  [ERR] #general channel not found")
        return None

    r = post(f"{CHANNEL_URL}/{channel_id}/invites", {
        "max_age": 0,       # Never expires
        "max_uses": 0,      # Unlimited uses
        "unique": True,
        "temporary": False
    })

    if r.get("code"):
        link = f"https://discord.gg/{r['code']}"
        print(f"  [OK] Permanent link created: {link}")
        print(f"       Add to GameConfig.lua: GameConfig.DiscordInvite = \"{link}\"")
        return link
    else:
        print(f"  [ERR] {r}")
        return None

# ═══════════════════════════════════════════════════════
# 4. WELCOME MESSAGE
# ═══════════════════════════════════════════════════════

def configure_welcome(roblox_link="https://www.roblox.com"):
    print("\n=== WELCOME MESSAGE ===")

    channel_id = find_channel("general")
    if not channel_id:
        print("  [ERR] #general channel not found")
        return

    r = patch(BASE_URL, {
        "system_channel_id": channel_id,
        "system_channel_flags": 0
    })

    if r.get("id"):
        print("  [OK] Welcome channel set to #general")
    else:
        print(f"  [ERR] {r}")

    welcome_content = f"""
🎮 **Welcome to DobiGames!**

The Roblox Brain Rot studio where things grow massive 🌾

🕹️ **Play now:** {roblox_link}
📋 **Rules:** Read #rules before playing
🏆 **Events:** Follow #events for Lucky Hours and Admin Abuse

*Farm, collect, and take on Kong!* 🦍
"""
    r2 = post(f"{CHANNEL_URL}/{channel_id}/messages", {"content": welcome_content})
    if r2.get("id"):
        print("  [OK] Welcome message posted in #general")
    else:
        print(f"  [ERR] {r2}")

# ═══════════════════════════════════════════════════════
# 5. AUTO ROLE — BrainRotFarmer
# ═══════════════════════════════════════════════════════

def configure_auto_role():
    print("\n=== AUTO ROLE ===")

    role_id = find_role("🌾 BrainRotFarmer")
    if not role_id:
        print("  [ERR] Role '🌾 BrainRotFarmer' not found")
        print("        Run setup_discord.py first")
        print("        Auto-role also requires a moderation bot")
        print("        Recommended: Carl-bot -> https://carl.gg")
        print("        In Carl-bot: Autoroles -> Add '🌾 BrainRotFarmer'")
        return

    print(f"  [OK] Role found: 🌾 BrainRotFarmer (ID: {role_id})")
    print(f"       Auto-assignment requires Carl-bot or MEE6")
    print(f"       https://carl.gg -> Autoroles -> Add role ID: {role_id}")
    print(f"       Every new member will receive this role automatically")

# ═══════════════════════════════════════════════════════
# 6. SAVE CONFIG
# ═══════════════════════════════════════════════════════

def save_config(invite_link, roblox_link):
    config = {
        "discord_invite": invite_link,
        "roblox_link": roblox_link,
        "guild_id": GUILD_ID,
    }
    with open("discord_config.json", "w") as f:
        json.dump(config, f, indent=2)
    print(f"\n  Config saved to discord_config.json")

    print("\n" + "="*60)
    print("Copy into GameConfig.lua:")
    print("="*60)
    print(f'GameConfig.DiscordInvite = "{invite_link}"')
    print(f'GameConfig.DiscordWebhookURL = "fill from discord_webhooks.json"')
    print("="*60)

# ═══════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════

if __name__ == "__main__":
    # Replace with your real Roblox link after publishing
    ROBLOX_LINK = "https://www.roblox.com/games/YOUR_GAME_ID/BrainRotFarm"

    print("\nConfiguring DobiGames Discord server...")
    print("="*60)

    configure_verification()
    invite_link = create_permanent_invite()
    configure_welcome(ROBLOX_LINK)
    configure_rules(ROBLOX_LINK)
    configure_auto_role()

    if invite_link:
        save_config(invite_link, ROBLOX_LINK)

    print("\n" + "="*60)
    print("Configuration complete!")
    print("="*60)
    print("\nManual steps required:")
    print("  -> Carl-bot: https://carl.gg -> Autoroles -> BrainRotFarmer")
    print("  -> Update ROBLOX_LINK once the game is published")
    print("="*60)
