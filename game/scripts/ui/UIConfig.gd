class_name UIConfig
extends RefCounted

## UIConfig — every tweakable UI constant in one place.
## No node logic here. Change values, not screen scripts.

# ── External links (replace before release) ───────────────────────────────
const TERMS_URL:   String = "https://thegamewise.com/terms-and-conditions"
const PRIVACY_URL: String = "https://thegamewise.com/privacy-policy"
const FACEBOOK_URL: String = "https://www.facebook.com/TheGameWise"
const YOUTUBE_URL: String = "https://www.youtube.com/TheGameWise"
const INSTAGRAM_URL: String = "https://www.instagram.com/gamewise_india"
const DISCORD_URL: String = "https://discord.com/invite/gamewise"

# ── Progression layout ────────────────────────────────────────────────────
const LEVELS_PER_WORLD: int = 10
## Metadata key that Gameplay reads to know which level to load.
const SELECTED_LEVEL_KEY: String = "selected_level"

# ── Timings (seconds) ─────────────────────────────────────────────────────
const LOADING_MIN_SECONDS: float = 1.2
const POPUP_IN_SECONDS:    float = 0.22
const POPUP_OUT_SECONDS:   float = 0.12

# ── Audio / haptics hooks (optional — skipped if the file does not exist) ──
const CLICK_SFX_PATH: String = "res://game/assets/audio/ui_click.ogg"

# ── Credits content: [role, names] ────────────────────────────────────────
const CREDITS: Array = [
	["Game Design", "Your Name"],
	["Programming", "Your Name"],
	["Art & Animation", "Your Name"],
	["Music & Sound", "Your Name"],
	["Special Thanks", "Everyone who played"],
]
