class_name PrivacyConsent
extends RefCounted

## PrivacyConsent — remembers on THIS device whether the player accepted the
## privacy policy. Uses its own tiny file, so it works even before
## SaveManager / DataManager has loaded and is never touched by cloud sync.

const FILE_PATH: String = "user://privacy_consent.cfg"
const SECTION: String = "consent"

## Bump this when the policy text changes → everyone is asked again.
const POLICY_VERSION: int = 1

static func is_accepted() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(FILE_PATH) != OK:
		return false
	return int(cfg.get_value(SECTION, "accepted_version", 0)) >= POLICY_VERSION

static func accept() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE_PATH)  # keep any other keys if the file already exists
	cfg.set_value(SECTION, "accepted_version", POLICY_VERSION)
	cfg.set_value(SECTION, "accepted_at_unix", int(Time.get_unix_time_from_system()))
	var err: Error = cfg.save(FILE_PATH)
	if err != OK:
		push_error("PrivacyConsent: could not save consent (error %d)" % err)

## Handy for testing: makes the popup show again on next launch.
static func reset() -> void:
	if FileAccess.file_exists(FILE_PATH):
		DirAccess.remove_absolute(FILE_PATH)
