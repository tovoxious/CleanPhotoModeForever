-- Clean Photo Mode Forever
--
-- When the UI is hidden (Toggle User Interface, Alt-Z by default) the game
-- hides UIParent, but a lot of things are drawn outside of it: unit names,
-- nameplates, chat bubbles, floating combat text, soft-target icons, ground
-- circles, outlines and any addon frame attached to WorldFrame. This addon
-- turns all of that off while the UI is hidden and restores the exact
-- previous values when the UI comes back.
--
-- Design notes:
--  * Only settings that are currently "on" get changed, and each change is
--    recorded in the saved variables. If the game closes or reloads while the
--    UI is hidden, the next login restores them automatically.
--  * If the player changes one of those settings while the UI is hidden
--    (for example toggling enemy nameplates with V), their new value wins and
--    is not overwritten on restore.
--  * Secure CVars cannot be changed in combat. They are queued and applied
--    as soon as combat ends. Everything else applies instantly, in or out of
--    combat. Frames are hidden with SetAlpha, which is allowed in combat.

local ADDON_NAME, ns = ...

local C_CVar = C_CVar
local C_NamePlate = C_NamePlate
local C_Timer = C_Timer
local InCombatLockdown = InCombatLockdown
local issecretvalue = issecretvalue
local ipairs, pairs, pcall, next = ipairs, pairs, pcall, next

local TICK_SECONDS = 0.25

ns.DEFAULTS = {
	nameplates = true,
	unitNames = true,
	chatBubbles = true,
	combatText = true,
	softTargetIcons = true,
	highlights = true,
	outlines = true,
	worldFrameAddons = true,
}

-- Option key -> list of { cvar, value while the UI is hidden }.
-- CVars that do not exist in the running client are skipped, so older and
-- newer names can live side by side in these lists.
ns.GROUPS = {
	{
		key = "nameplates",
		cvars = {
			{ "nameplateShowEnemies", "0" },
			{ "nameplateShowFriendlyPlayers", "0" },
			{ "nameplateShowFriendlyNpcs", "0" },
			{ "nameplateShowFriends", "0" }, -- pre-Midnight name
			{ "nameplateShowSelf", "0" }, -- personal resource display (secure)
			{ "SoftTargetNameplateEnemy", "0" },
			{ "SoftTargetNameplateFriend", "0" },
			{ "SoftTargetNameplateInteract", "0" },
		},
	},
	{
		key = "unitNames",
		cvars = {
			{ "UnitNameOwn", "0" },
			{ "UnitNameNPC", "0" },
			{ "UnitNameHostleNPC", "0" }, -- Blizzard's spelling
			{ "UnitNameInteractiveNPC", "0" },
			{ "UnitNameFriendlySpecialNPCName", "0" },
			{ "UnitNameNonCombatCreatureName", "0" },
			{ "UnitNameFocused", "0" },
			{ "UnitNamePlayerGuild", "0" },
			{ "UnitNameGuildTitle", "0" },
			{ "UnitNamePlayerPVPTitle", "0" },
			{ "UnitNameFriendlyPlayerName", "0" },
			{ "UnitNameFriendlyPetName", "0" },
			{ "UnitNameFriendlyGuardianName", "0" },
			{ "UnitNameFriendlyTotemName", "0" },
			{ "UnitNameFriendlyMinionName", "0" },
			{ "UnitNameEnemyPlayerName", "0" },
			{ "UnitNameEnemyPetName", "0" },
			{ "UnitNameEnemyGuardianName", "0" },
			{ "UnitNameEnemyTotemName", "0" },
			{ "UnitNameEnemyMinionName", "0" },
			{ "UnitNameForceHideMinus", "1" }, -- "1" means hide
		},
	},
	{
		key = "chatBubbles",
		cvars = {
			{ "chatBubbles", "0" },
			{ "chatBubblesParty", "0" },
			{ "chatBubblesRaid", "0" },
		},
	},
	{
		key = "combatText",
		cvars = {
			{ "floatingCombatTextCombatDamage_v2", "0" },
			{ "floatingCombatTextCombatHealing_v2", "0" },
			{ "floatingCombatTextCombatHealingAbsorbSelf_v2", "0" },
			{ "floatingCombatTextCombatHealingAbsorbTarget_v2", "0" },
			{ "floatingCombatTextCombatLogPeriodicSpells_v2", "0" },
			{ "floatingCombatTextPetMeleeDamage_v2", "0" },
			{ "floatingCombatTextPetSpellDamage_v2", "0" },
			-- pre-Midnight names
			{ "floatingCombatTextCombatDamage", "0" },
			{ "floatingCombatTextCombatHealing", "0" },
			{ "floatingCombatTextCombatLogPeriodicSpells", "0" },
			{ "floatingCombatTextPetMeleeDamage", "0" },
			{ "floatingCombatTextPetSpellDamage", "0" },
			-- player combat text and threat floaters
			{ "enableFloatingCombatText", "0" },
			{ "threatWorldText", "0" },
		},
	},
	{
		key = "softTargetIcons",
		cvars = {
			-- Only the icons. SoftTargetInteract itself is left alone so the
			-- interact key keeps working while the UI is hidden.
			{ "SoftTargetIconInteract", "0" },
			{ "SoftTargetIconGameObject", "0" },
			{ "SoftTargetIconEnemy", "0" },
			{ "SoftTargetIconFriend", "0" },
		},
	},
	{
		key = "highlights",
		cvars = {
			{ "ShowQuestUnitCircles", "0" },
			{ "occludedSilhouettePlayer", "0" },
			{ "findYourselfAnywhere", "0" },
			{ "findYourselfInRaid", "0" },
			{ "findYourselfInBG", "0" },
			{ "motionSicknessFocalCircle", "0" },
		},
	},
	{
		key = "outlines",
		cvars = {
			{ "graphicsOutlineMode", "0" },
			{ "Outline", "0" },
			{ "outlineModeShowLootEffectWhenDisabled", "0" },
			{ "targetHighlightAlwaysShown", "0" },
		},
	},
}

-- WorldFrame children that must stay visible even in photo mode.
local KEEP_VISIBLE = {
	ActionStatus = true, -- "Screen captured" message
	CinematicFrame = true,
	MovieFrame = true,
}

local db -- CleanPhotoModeForeverDB, ready after ADDON_LOADED
local uiHidden = false
local retryAfterCombat = false
local ticker
local faded = {} -- [frame] = alpha before we faded it
local knownPlates = setmetatable({}, { __mode = "k" })

function ns.Print(msg)
	print("|cff8fd3ffClean Photo Mode|r: " .. msg)
end

----------------------------------------------------------------------------
-- CVars
----------------------------------------------------------------------------

-- Returns value, isSecure, isLocked, or nil when the CVar does not exist.
local function ReadCVar(name)
	local ok, value, _, _, _, lockedFromUser, isSecure, isReadOnly = pcall(C_CVar.GetCVarInfo, name)
	if not ok or value == nil then
		return nil
	end
	return value, isSecure, (lockedFromUser or isReadOnly)
end

local function WriteCVar(name, value)
	local ok, success = pcall(C_CVar.SetCVar, name, value)
	return ok and success ~= false
end

local function HideCVar(name, hiddenValue)
	if db.pending[name] then
		return -- already ours
	end
	local current, isSecure, locked = ReadCVar(name)
	if current == nil or locked or current == hiddenValue then
		return -- missing, not changeable, or already off
	end
	if isSecure and InCombatLockdown() then
		retryAfterCombat = true
		return
	end
	if WriteCVar(name, hiddenValue) then
		db.pending[name] = { original = current, hidden = hiddenValue }
	end
end

local function RestoreCVar(name, entry)
	local current, isSecure = ReadCVar(name)
	if current ~= nil and current == entry.hidden then
		if isSecure and InCombatLockdown() then
			retryAfterCombat = true
			return -- keep the entry, try again after combat
		end
		WriteCVar(name, entry.original)
	end
	-- Restored, gone from the client, or changed by the player while the UI
	-- was hidden (their choice wins). Either way we are done with it.
	db.pending[name] = nil
end

local function ApplyHiddenCVars()
	for _, group in ipairs(ns.GROUPS) do
		if db.options[group.key] then
			for _, pair in ipairs(group.cvars) do
				HideCVar(pair[1], pair[2])
			end
		end
	end
end

local function RestoreAllCVars()
	-- Clearing fields of the table being traversed is allowed in Lua.
	for name, entry in pairs(db.pending) do
		RestoreCVar(name, entry)
	end
end

local function CountPending()
	local n = 0
	for _ in pairs(db.pending) do
		n = n + 1
	end
	return n
end

----------------------------------------------------------------------------
-- Frames outside UIParent (nameplates, chat bubbles, addon world frames)
----------------------------------------------------------------------------

local function Fade(frame)
	if not frame or frame:IsForbidden() then
		return
	end
	if faded[frame] == nil then
		local alpha = frame:GetAlpha()
		if issecretvalue and issecretvalue(alpha) then
			alpha = 1
		end
		faded[frame] = alpha
	end
	frame:SetAlpha(0)
end

local function UnfadeAll()
	for frame, alpha in pairs(faded) do
		if not frame:IsForbidden() then
			frame:SetAlpha(alpha)
		end
		faded[frame] = nil
	end
end

-- The engine drives the alpha of the nameplate base frame itself (distance
-- and occlusion fading), so fade its children instead. This covers the
-- Blizzard plate and any nameplate addon that builds on top of it.
local function FadePlate(plate)
	if not plate or plate:IsForbidden() then
		return
	end
	knownPlates[plate] = true
	for _, child in ipairs({ plate:GetChildren() }) do
		Fade(child)
	end
end

local function FadeAllPlates()
	for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
		FadePlate(plate)
	end
end

local function FadeChatBubbles()
	if not (C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles) then
		return
	end
	local ok, bubbles = pcall(C_ChatBubbles.GetAllChatBubbles)
	if ok and bubbles then
		for _, bubble in ipairs(bubbles) do
			Fade(bubble)
		end
	end
end

local function IsNamePlateBase(frame)
	if knownPlates[frame] or frame.UnitFrame or frame.namePlateUnitToken then
		return true
	end
	local name = frame:GetName()
	return name ~= nil and name:find("^NamePlate") ~= nil
end

local function FadeWorldFrameChildren()
	for _, child in ipairs({ WorldFrame:GetChildren() }) do
		if not child:IsForbidden() and not IsNamePlateBase(child) then
			local name = child:GetName()
			if not (name and KEEP_VISIBLE[name]) then
				Fade(child)
			end
		end
	end
end

-- Runs on hide and then on a short ticker, so frames that appear (or that
-- another addon fades back in) while the UI is hidden stay hidden.
local function RefreshFades()
	if not uiHidden then
		return
	end
	local o = db.options
	if o.nameplates then
		FadeAllPlates()
	end
	if o.chatBubbles then
		FadeChatBubbles()
	end
	if o.worldFrameAddons then
		FadeWorldFrameChildren()
	end
end

----------------------------------------------------------------------------
-- Hide / show
----------------------------------------------------------------------------

local function OnUIHidden()
	if not db or uiHidden then
		return
	end
	uiHidden = true
	retryAfterCombat = false
	ApplyHiddenCVars()
	RefreshFades()
	if not ticker then
		ticker = C_Timer.NewTicker(TICK_SECONDS, RefreshFades)
	end
end

local function OnUIShown()
	if not db or not uiHidden then
		return
	end
	uiHidden = false
	retryAfterCombat = false
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	UnfadeAll()
	RestoreAllCVars()
end

-- Any child of UIParent gets OnHide/OnShow when UIParent itself is hidden or
-- shown, which is exactly what Toggle User Interface does.
local watcher = CreateFrame("Frame", nil, UIParent)
watcher:SetScript("OnHide", OnUIHidden)
watcher:SetScript("OnShow", OnUIShown)

-- Settings left behind by a reload, crash or logout while the UI was hidden.
local function RecoverLeftovers()
	if not db or uiHidden or not next(db.pending) then
		return
	end
	local count = CountPending()
	RestoreAllCVars()
	local restored = count - CountPending()
	if restored > 0 then
		ns.Print(("restored %d setting%s left hidden by the last session."):format(restored, restored == 1 and "" or "s"))
	end
end

function ns.ForceRestore()
	UnfadeAll()
	local count = CountPending()
	RestoreAllCVars()
	ns.Print(("restored %d setting%s."):format(count, count == 1 and "" or "s"))
	if next(db.pending) then
		ns.Print("some settings can't change in combat; they will be restored when combat ends.")
	end
end

----------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------

local function InitDB()
	CleanPhotoModeForeverDB = CleanPhotoModeForeverDB or {}
	db = CleanPhotoModeForeverDB
	db.options = db.options or {}
	db.pending = db.pending or {}
	for key, value in pairs(ns.DEFAULTS) do
		if db.options[key] == nil then
			db.options[key] = value
		end
	end
	ns.db = db
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")

events:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... == ADDON_NAME then
			self:UnregisterEvent("ADDON_LOADED")
			InitDB()
			ns.CreateOptionsPanel()
		end
	elseif event == "VARIABLES_LOADED" then
		-- Account CVars are loaded by now, so restoring is safe.
		RecoverLeftovers()
	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = ...
		if isInitialLogin or isReloadingUi then
			C_Timer.After(10, RecoverLeftovers) -- fallback in case VARIABLES_LOADED came early
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if retryAfterCombat then
			retryAfterCombat = false
			if uiHidden then
				ApplyHiddenCVars()
			else
				RestoreAllCVars()
			end
		end
	elseif event == "PLAYER_LOGOUT" then
		-- Put values back before the client saves them, but keep the records:
		-- next login drops each one if the value stuck, or restores it if not.
		if db and uiHidden then
			for name, entry in pairs(db.pending) do
				local _, isSecure = ReadCVar(name)
				if not (isSecure and InCombatLockdown()) then
					WriteCVar(name, entry.original)
				end
			end
		end
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		if uiHidden and db.options.nameplates then
			local plate = C_NamePlate.GetNamePlateForUnit(...)
			FadePlate(plate)
			-- Nameplate addons often build their frames in the same event,
			-- after us. Catch those on the next frame.
			C_Timer.After(0, function()
				if uiHidden then
					FadePlate(plate)
				end
			end)
		end
	end
end)

----------------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------------

SLASH_CLEANPHOTOMODE1 = "/cpm"
SLASH_CLEANPHOTOMODE2 = "/cleanphoto"
SlashCmdList.CLEANPHOTOMODE = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "restore" then
		ns.ForceRestore()
	elseif msg == "status" then
		ns.Print(("%d setting%s currently held by photo mode."):format(CountPending(), CountPending() == 1 and "" or "s"))
	elseif msg == "help" then
		ns.Print("/cpm opens the options. /cpm restore puts back anything still hidden. /cpm status shows what is held.")
	else
		ns.OpenOptions()
	end
end
