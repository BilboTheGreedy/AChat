local _, ns = ...
local UI = ns.UI
local C = UI.colors

local styled = {}
local hooked = {}
local copyButtons = {}

local STICKY = { "SAY", "YELL", "PARTY", "RAID", "GUILD", "OFFICER", "INSTANCE_CHAT", "WHISPER", "BN_WHISPER", "CHANNEL", "EMOTE", "RAID_WARNING" }
local COLORED = {
	"SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "WHISPER", "WHISPER_INFORM", "PARTY", "PARTY_LEADER", "RAID",
	"RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "CHANNEL1", "CHANNEL2", "CHANNEL3",
	"CHANNEL4", "CHANNEL5", "CHANNEL6", "CHANNEL7", "CHANNEL8", "CHANNEL9", "CHANNEL10",
}
local CYCLE = { "SAY", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "OFFICER" }
local HOVER = { item = true, spell = true, enchant = true, quest = true, talent = true, achievement = true, currency = true, unit = true }

local function editBox(frame)
	return frame.editBox or _G[(frame:GetName() or "") .. "EditBox"]
end

local function tabOf(frame)
	return _G[(frame:GetName() or "") .. "Tab"]
end

local function fade(region)
	if region and region.SetAlpha then region:SetAlpha(0) end
end

local function styleEdit(frame)
	local eb = editBox(frame)
	if not eb then return end
	local name = eb:GetName() or ""
	for _, part in ipairs({ "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }) do
		fade(_G[name .. part])
		fade(eb[part])
	end
	if not eb.achatBg then
		eb.achatBg = UI.Fill(eb, { 0.03, 0.03, 0.04, 0.9 })
		eb.achatEdges = UI.Border(eb)
	end
end

local function styleTab(frame)
	local tab = tabOf(frame)
	if not tab then return end
	local name = tab:GetName() or ""
	for _, part in ipairs({ "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight", "HighlightLeft", "HighlightMiddle", "HighlightRight", "SelectedLeft", "SelectedMiddle", "SelectedRight" }) do
		fade(_G[name .. part])
		fade(tab[part])
	end
end

local function placeEdit(frame)
	local eb = editBox(frame)
	if not eb or (InCombatLockdown and InCombatLockdown()) then return end
	if ns.db.editTop then
		eb:ClearAllPoints()
		eb:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -4, 22)
		eb:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 4, 22)
		eb.achatMoved = true
	elseif eb.achatMoved then
		eb:ClearAllPoints()
		eb:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -4, -2)
		eb:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 4, -2)
		eb.achatMoved = nil
	end
end

local function available(kind)
	if kind == "SAY" then return true end
	if kind == "PARTY" then return IsInGroup and IsInGroup() and true or false end
	if kind == "RAID" then return IsInRaid and IsInRaid() and true or false end
	if kind == "INSTANCE_CHAT" then
		return IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and true or false
	end
	if kind == "GUILD" then return IsInGuild and IsInGuild() and true or false end
	if kind == "OFFICER" then
		if C_GuildInfo and C_GuildInfo.CanEditOfficerNote then
			local ok, v = pcall(C_GuildInfo.CanEditOfficerNote)
			return ok and v and true or false
		end
		return false
	end
	return false
end

function ns.NextChannel(current, back)
	local at = 0
	for i, k in ipairs(CYCLE) do
		if k == current then at = i break end
	end
	for step = 1, #CYCLE do
		local i = ((at - 1 + (back and -step or step)) % #CYCLE) + 1
		if available(CYCLE[i]) then return CYCLE[i] end
	end
	return "SAY"
end

local function onTab(eb)
	if not ns.db.tabCycle then return end
	local text = eb:GetText() or ""
	if text ~= "" then return end
	local kind = eb:GetAttribute("chatType")
	if kind == "WHISPER" or kind == "BN_WHISPER" or kind == "CHANNEL" then return end
	local nextKind = ns.NextChannel(kind, IsShiftKeyDown and IsShiftKeyDown())
	eb:SetAttribute("chatType", nextKind)
	if eb.UpdateHeader then
		pcall(eb.UpdateHeader, eb)
	elseif ChatEdit_UpdateHeader then
		pcall(ChatEdit_UpdateHeader, eb)
	end
end

local function onWheel(frame, delta)
	if IsShiftKeyDown and IsShiftKeyDown() then
		if delta > 0 then frame:ScrollToTop() else frame:ScrollToBottom() end
	elseif IsControlKeyDown and IsControlKeyDown() then
		if delta > 0 then frame:PageUp() else frame:PageDown() end
	end
end

local function onLinkEnter(frame, link)
	if not ns.db.hover or type(link) ~= "string" or ns.IsSecret(link) then return end
	local kind = link:match("^(%a+):")
	if not kind or not HOVER[kind] then return end
	GameTooltip:SetOwner(frame, "ANCHOR_CURSOR_RIGHT")
	local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
	if ok then
		GameTooltip:Show()
		frame.achatTip = true
	end
end

local function onLinkLeave(frame)
	if frame.achatTip then
		frame.achatTip = nil
		GameTooltip:Hide()
	end
end

local function copyButton(frame)
	local b = copyButtons[frame]
	if not b then
		b = CreateFrame("Button", nil, frame)
		b:SetSize(18, 18)
		b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
		b:SetFrameLevel((frame:GetFrameLevel() or 1) + 5)
		UI.Fill(b, C.bar)
		UI.Border(b)
		b.label = UI.Text(b, "GameFontHighlightSmall", "CENTER", C.dim)
		b.label:SetPoint("CENTER")
		b.label:SetText("C")
		b:SetAlpha(0.25)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnEnter", function(self)
			self:SetAlpha(1)
			GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
			GameTooltip:AddLine("Copy chat", 1, 0.82, 0)
			GameTooltip:AddLine("Right-click for options", 0.58, 0.6, 0.65)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function(self)
			self:SetAlpha(0.25)
			GameTooltip:Hide()
		end)
		b:SetScript("OnClick", function(self, button)
			if button == "RightButton" then
				ns.OpenOptions(self)
			else
				ns.ShowCopy(frame)
			end
		end)
		copyButtons[frame] = b
	end
	b:SetShown(ns.db.copyButton)
end

local function hook(frame)
	if hooked[frame] then return end
	hooked[frame] = true
	pcall(frame.HookScript, frame, "OnMouseWheel", onWheel)
	pcall(frame.HookScript, frame, "OnHyperlinkEnter", onLinkEnter)
	pcall(frame.HookScript, frame, "OnHyperlinkLeave", onLinkLeave)
	local eb = editBox(frame)
	if eb then pcall(eb.HookScript, eb, "OnTabPressed", onTab) end
end

function ns.Apply(frame)
	local db = ns.db
	if not frame or ns.IsCombatLog(frame) then return end
	hook(frame)
	if db.style and not styled[frame] then
		styled[frame] = true
		pcall(styleEdit, frame)
		pcall(styleTab, frame)
	end
	pcall(placeEdit, frame)
	copyButton(frame)
	local eb = editBox(frame)
	if eb then
		if eb.SetAltArrowKeyMode then eb:SetAltArrowKeyMode(not db.arrows) end
		if eb.SetHistoryLines then pcall(eb.SetHistoryLines, eb, db.history) end
	end
	if frame.SetFading then frame:SetFading(db.fade) end
	if frame.SetTimeVisible then frame:SetTimeVisible(db.fadeTime) end
	if frame.SetMaxLines and frame.GetMaxLines then
		local cur = frame:GetMaxLines()
		if type(cur) == "number" and cur < db.lines then frame:SetMaxLines(db.lines) end
	end
	if db.shorten or db.levels then ns.Wrap(frame) end
end

local BUTTONS = { "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "TextToSpeechButtonFrame" }
local buttonHooked = {}

local function hideButton(b)
	if not b then return end
	if not buttonHooked[b] then
		buttonHooked[b] = true
		pcall(b.HookScript, b, "OnShow", function(self)
			if ns.db.hideButtons then self:Hide() end
		end)
	end
	if ns.db.hideButtons then b:Hide() else b:Show() end
end

local function buttons()
	if InCombatLockdown and InCombatLockdown() then
		ns.pendingButtons = true
		return
	end
	for _, name in ipairs(BUTTONS) do hideButton(_G[name]) end
	for _, f in ipairs(ns.Frames()) do
		hideButton(_G[(f:GetName() or "") .. "ButtonFrame"])
	end
end

local function globals()
	local db = ns.db
	if ChatTypeInfo then
		for _, kind in ipairs(STICKY) do
			local info = ChatTypeInfo[kind]
			if info then info.sticky = db.sticky and 1 or 0 end
		end
		for _, kind in ipairs(COLORED) do
			if ChatTypeInfo[kind] then
				if SetChatColorNameByClass then
					pcall(SetChatColorNameByClass, kind, db.classColors)
				else
					ChatTypeInfo[kind].colorNameByClass = db.classColors
				end
			end
		end
	end
	if SetCVar then
		pcall(SetCVar, "showTimestamps", db.timestamp or "none")
		pcall(SetCVar, "whisperMode", db.whisperMode or "inline")
	end
	CHAT_TIMESTAMP_FORMAT = db.timestamp
end

function ns.ApplyAll()
	globals()
	for _, f in ipairs(ns.Frames()) do ns.Apply(f) end
	buttons()
end

ns:Listen("LOGIN", function()
	ns.ApplyAll()
	if hooksecurefunc and FCF_OpenTemporaryWindow then
		pcall(hooksecurefunc, "FCF_OpenTemporaryWindow", function()
			for _, name in ipairs(CHAT_FRAMES or {}) do
				local f = _G[name]
				if f then ns.Apply(f) end
			end
		end)
	end
end)
ns:Listen("OPTIONS", function() ns.ApplyAll() end)
ns:On("PLAYER_REGEN_ENABLED", function()
	if ns.pendingButtons then
		ns.pendingButtons = nil
		ns.ApplyAll()
	end
end)
