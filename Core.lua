local ADDON, ns = ...

local defaults = {
	style = true,
	editTop = false,
	hideButtons = true,
	classColors = true,
	levels = true,
	shorten = true,
	timestamp = "%H:%M ",
	urls = true,
	copyButton = true,
	sticky = true,
	arrows = true,
	history = 100,
	tabCycle = true,
	whisperSound = true,
	whisperMode = "inline",
	highlight = true,
	highlightName = true,
	highlightSound = true,
	keywords = {},
	spam = true,
	spamWindow = 10,
	hover = true,
	altInvite = true,
	fade = true,
	fadeTime = 120,
	lines = 500,
	copyLines = 300,
	keep = false,
	keepLines = 60,
	minimal = false,
	channelColors = {},
}

ACore.New(ADDON, ns, { db = "AChatDB", defaults = defaults, profile = true, shared = { "saved" } })

ns.levels = {}

function ns.Short(name)
	if type(name) ~= "string" then return nil end
	return name:match("^([^%-]+)") or name
end

function ns.Frames()
	local out = {}
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		local f = _G["ChatFrame" .. i]
		if f then out[#out + 1] = f end
	end
	return out
end

function ns.IsCombatLog(frame)
	if IsCombatLog then
		local ok, v = pcall(IsCombatLog, frame)
		if ok and v then return true end
	end
	return frame == ChatFrame2 and COMBATLOG ~= nil
end

function ns.Sound(kit, fallback)
	if not PlaySound then return end
	local id = SOUNDKIT and SOUNDKIT[kit] or fallback
	if id then pcall(PlaySound, id, "Master") end
end

ACore.Register({
	name = "AChat",
	title = "AChat",
	slash = "/achat",
	desc = "chat tweaks",
	options = function() return ns.Options() end,
	toggle = function() ns.OpenOptions() end,
})

SLASH_ACHAT1 = "/achat"
SlashCmdList["ACHAT"] = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, rest = msg:match("^(%S+)%s*(.*)$")
	cmd = cmd and cmd:lower()
	if cmd == "copy" then
		ns.ShowCopy(SELECTED_CHAT_FRAME or ChatFrame1)
	elseif cmd == "add" and rest ~= "" then
		ns.AddKeyword(rest)
	elseif cmd == "remove" and rest ~= "" then
		ns.RemoveKeyword(rest)
	elseif cmd == "keywords" then
		ns.Print(#ns.db.keywords > 0 and table.concat(ns.db.keywords, ", ") or "no keywords")
	elseif cmd == "color" or cmd == "colour" then
		local name, hex = rest:match("^(.-)%s+(%S+)$")
		if not name or name == "" or not ns.SetChannelColor(name, hex) then
			ns.Print("usage: /achat color <channel name> <rrggbb or off>")
		end
	else
		ns.OpenOptions()
	end
end

function ns.AddKeyword(word)
	word = word:lower():gsub("^%s+", ""):gsub("%s+$", "")
	if word == "" then return end
	for _, w in ipairs(ns.db.keywords) do
		if w == word then return end
	end
	table.insert(ns.db.keywords, word)
	ns:Fire("KEYWORDS")
end

function ns.RemoveKeyword(word)
	word = word:lower():gsub("^%s+", ""):gsub("%s+$", "")
	for i, w in ipairs(ns.db.keywords) do
		if w == word then
			table.remove(ns.db.keywords, i)
			break
		end
	end
	ns:Fire("KEYWORDS")
end

function ns.SetKeywords(text)
	local list = {}
	for word in (text or ""):gmatch("[^,]+") do
		word = word:lower():gsub("^%s+", ""):gsub("%s+$", "")
		if word ~= "" then list[#list + 1] = word end
	end
	ns.db.keywords = list
	ns:Fire("KEYWORDS")
end

local function tellTarget(msg)
	local ok, player = pcall(UnitIsPlayer, "target")
	if not ok or ns.IsSecret(player) or not player then
		ns.Print("no player targeted")
		return
	end
	local name = GetUnitName and GetUnitName("target", true) or UnitName("target")
	if ns.IsSecret(name) or type(name) ~= "string" then return end
	name = name:gsub("%s", "")
	if msg and msg ~= "" then
		if C_ChatInfo and C_ChatInfo.SendChatMessage then
			C_ChatInfo.SendChatMessage(msg, "WHISPER", nil, name)
		elseif SendChatMessage then
			SendChatMessage(msg, "WHISPER", nil, name)
		end
	elseif ChatFrameUtil and ChatFrameUtil.SendTell then
		ChatFrameUtil.SendTell(name)
	elseif ChatFrame_SendTell then
		ChatFrame_SendTell(name)
	end
end

SLASH_ACHATTT1 = "/tt"
SlashCmdList["ACHATTT"] = tellTarget

if not SlashCmdList["CLEAR"] then
	SLASH_ACHATCLEAR1 = "/clear"
	SlashCmdList["ACHATCLEAR"] = function()
		local f = SELECTED_CHAT_FRAME or ChatFrame1
		if f and f.Clear then f:Clear() end
	end
end
