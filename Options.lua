-- Options panel (Esc > Options > AddOns > Clean Photo Mode)

local ADDON_NAME, ns = ...

local TITLE = "Clean Photo Mode Forever"
-- Shorter name for the entry in Options > AddOns, which has little room.
local CATEGORY_NAME = "Clean Photo Mode"

local OPTIONS = {
	{
		key = "nameplates",
		label = "Nameplates",
		desc = "Every nameplate, including the personal resource display, soft-target nameplates and nameplate addons.",
	},
	{
		key = "unitNames",
		label = "Unit names and titles",
		desc = "The floating names, guild names and titles above players, NPCs, pets, minions and totems.",
	},
	{
		key = "chatBubbles",
		label = "Chat bubbles",
		desc = "Say, yell, party and raid speech bubbles, including the ones already on screen.",
	},
	{
		key = "combatText",
		label = "Floating combat text",
		desc = "Damage, healing and threat numbers that pop up in the world.",
	},
	{
		key = "softTargetIcons",
		label = "Soft-target icons",
		desc = "The interact, enemy and friend icons over units and objects. The interact key keeps working.",
	},
	{
		key = "highlights",
		label = "Ground circles and character highlights",
		desc = "Quest unit circles, the find-yourself highlight, the obstructed-character silhouette and the motion sickness focal circle.",
	},
	{
		key = "outlines",
		label = "Outlines and loot sparkles",
		desc = "Mouseover and target outlines, and the sparkles on lootable objects.",
	},
	{
		key = "worldFrameAddons",
		label = "Other addon frames in the game world",
		desc = "Anything an addon attached to the 3D world instead of the normal UI, such as custom name text or world markers.",
	},
}

local INTRO = "Press your |cffffd200Toggle User Interface|r key (|cffffd200Alt-Z|r by default) and everything checked below disappears along with the UI. Press it again and every setting goes back exactly the way you had it."
local FOOTNOTE = "Settings are only changed while the UI is hidden. If you change one yourself during that time, your choice is kept. A few settings (like the personal resource display) cannot change during combat; they catch up the moment combat ends. Anything left over from a crash or reload is restored on your next login. Slash commands: |cffffd200/cpm|r, |cffffd200/cpm restore|r, |cffffd200/cpm status|r."

function ns.CreateOptionsPanel()
	local db = ns.db
	local panel = CreateFrame("Frame")
	panel.name = CATEGORY_NAME

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(TITLE)

	local version = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
	version:SetText("v" .. (C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"))

	local intro = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	intro:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
	intro:SetJustifyH("LEFT")
	intro:SetText(INTRO)

	local checkboxes = {}
	local anchor = intro
	for i, opt in ipairs(OPTIONS) do
		local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
		-- Below the intro for the first one, then below the previous description
		-- (which is indented 30px), so wrapped descriptions never overlap.
		if i == 1 then
			cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -2, -14)
		else
			cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -30, -4)
		end
		cb.Text:SetFontObject("GameFontNormal")
		cb.Text:SetText(opt.label)
		cb:SetScript("OnClick", function(self)
			local checked = self:GetChecked()
			db.options[opt.key] = checked and true or false
			PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		end)

		local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		desc:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 30, 6)
		desc:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
		desc:SetJustifyH("LEFT")
		desc:SetTextColor(0.75, 0.75, 0.75)
		desc:SetText(opt.desc)

		checkboxes[opt.key] = cb
		anchor = desc
	end

	local footnote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	footnote:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -28, -18)
	footnote:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
	footnote:SetJustifyH("LEFT")
	footnote:SetTextColor(0.75, 0.75, 0.75)
	footnote:SetText(FOOTNOTE)

	local restore = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	restore:SetSize(200, 24)
	restore:SetPoint("TOPLEFT", footnote, "BOTTOMLEFT", 0, -12)
	restore:SetText("Restore hidden settings now")
	restore:SetScript("OnClick", function()
		ns.ForceRestore()
	end)

	local function Refresh()
		for key, cb in pairs(checkboxes) do
			cb:SetChecked(db.options[key])
		end
	end
	panel:SetScript("OnShow", Refresh)
	Refresh()

	-- Called by the Settings panel's "Defaults" button.
	function panel.OnDefault()
		for key, value in pairs(ns.DEFAULTS) do
			db.options[key] = value
		end
		Refresh()
	end

	local category = Settings.RegisterCanvasLayoutCategory(panel, CATEGORY_NAME)
	Settings.RegisterAddOnCategory(category)
	ns.category = category
end

function ns.OpenOptions()
	if InCombatLockdown() then
		ns.Print("the options can't open during combat.")
		return
	end
	if ns.category then
		local id = ns.category.GetID and ns.category:GetID() or ns.category.ID
		Settings.OpenToCategory(id)
	end
end
