-- An older build keyed this mage by first name only; its data moves to the full-name key on login.
WaterboyReimaginedDB = { version = 3, profiles = { default = { classes = {}, players = {} },
  ["Aldren-Forever"] = { classes = {}, players = {}, loadouts = { solo = { marker = true } } } },
  mages = { ["Aldren-Forever"] = { level = 59 } } }
FIRE("ADDON_LOADED", "WaterboyReimagined")
FIRE("PLAYER_LOGIN")
local db = WaterboyReimaginedDB
print("key: " .. NS.CharKey())
print("old profile gone: " .. tostring(db.profiles["Aldren-Forever"] == nil))
print("old mage gone: " .. tostring(db.mages["Aldren-Forever"] == nil))
print("loadout moved: " .. tostring(db.profiles["Aldren Brightwater-Forever"].loadouts.solo.marker))
print("mage moved: " .. tostring(db.mages["Aldren Brightwater-Forever"] ~= nil))
