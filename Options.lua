local _, ns = ...
local UI = ns.UI

local anchor
local function holder()
	if not anchor then
		anchor = CreateFrame("Frame", nil, UIParent)
		anchor:SetSize(1, 1)
		anchor:SetPoint("LEFT", UIParent, "LEFT", 40, 120)
	end
	return anchor
end

local function changed() ns:Fire("OPTIONS") end

local function pick(key, label, value)
	return {
		text = label, checked = ns.db[key] == value,
		func = function()
			ns.db[key] = value
			changed()
		end,
	}
end

local function sections()
	local db = ns.db
	return {
		{ "AChat", {
			UI.Check(db, "style", "Flat edit box and tabs (reload to undo)", changed),
			UI.Check(db, "editTop", "Edit box above the chat", changed),
			UI.Check(db, "hideButtons", "Hide the chat buttons", changed),
			UI.Check(db, "minimal", "Hide tabs until hovered", changed),
			UI.Check(db, "copyButton", "Copy button on each window", changed),
			UI.Check(db, "classColors", "Class coloured names", changed),
			UI.Check(db, "levels", "Player level before names", changed),
			UI.Check(db, "shorten", "Short channel names", changed),
			UI.Check(db, "urls", "Clickable web links", changed),
			UI.Check(db, "hover", "Tooltips when hovering links", changed),
			UI.Check(db, "altInvite", "Alt-click a name to invite", changed),
			UI.Check(db, "sticky", "Remember the last channel", changed),
			UI.Check(db, "arrows", "Arrow keys without Alt", changed),
			UI.Check(db, "tabCycle", "Tab switches channel", changed),
			UI.Check(db, "spam", "Hide repeated messages", changed),
		} },
		{ "Timestamps", {
			pick("timestamp", "Off", false),
			pick("timestamp", "14:05", "%H:%M "),
			pick("timestamp", "14:05:09", "%H:%M:%S "),
			pick("timestamp", "02:05 PM", "%I:%M %p "),
			pick("timestamp", "[14:05]", "[%H:%M] "),
		} },
		{ "Whispers", {
			UI.Check(db, "whisperSound", "Sound on every whisper", changed),
			pick("whisperMode", "Show in the chat window", "inline"),
			pick("whisperMode", "Open a tab per conversation", "popout"),
			pick("whisperMode", "Both", "popout_and_inline"),
		} },
		{ "Highlights", {
			UI.Check(db, "highlight", "Highlight keywords", changed),
			UI.Check(db, "highlightName", "Highlight my name", changed),
			UI.Check(db, "highlightSound", "Play a sound", changed),
			{ text = "Edit keywords...", func = function()
				UI.Prompt("Keywords, separated by commas", table.concat(db.keywords, ", "), ns.SetKeywords)
			end },
		} },
		{ "Fading and history", {
			UI.Check(db, "fade", "Fade old messages", changed),
			pick("fadeTime", "Fade after 30 seconds", 30),
			pick("fadeTime", "Fade after 2 minutes", 120),
			pick("fadeTime", "Fade after 10 minutes", 600),
			pick("lines", "Keep 500 lines", 500),
			pick("lines", "Keep 1000 lines", 1000),
			pick("lines", "Keep 2500 lines", 2500),
			pick("copyLines", "Copy window: last 300 lines", 300),
			pick("copyLines", "Copy window: last 1000 lines", 1000),
			UI.Check(db, "keep", "Bring chat back after a reload", changed),
		} },
	}
end

function ns.Options()
	local entries = {}
	for _, section in ipairs(sections()) do
		entries[#entries + 1] = { text = section[1], title = true }
		for _, e in ipairs(section[2]) do entries[#entries + 1] = e end
	end
	entries[#entries + 1] = { text = "Copy this chat window", func = function() ns.ShowCopy(SELECTED_CHAT_FRAME or ChatFrame1) end }
	return entries
end

local function subMenu(at, title, entries)
	table.insert(entries, 1, { text = title, title = true })
	entries[#entries + 1] = { text = "< Back", func = function() ns.OpenOptions(at) end }
	UI.Menu(at, entries)
end

function ns.OpenOptions(at)
	at = at or holder()
	local all = sections()
	local entries = { { text = all[1][1], title = true } }
	for _, e in ipairs(all[1][2]) do entries[#entries + 1] = e end
	entries[#entries + 1] = { text = "More", title = true }
	for i = 2, #all do
		local section = all[i]
		entries[#entries + 1] = { text = section[1] .. "...", func = function() subMenu(at, section[1], section[2]) end }
	end
	entries[#entries + 1] = { text = "Copy this chat window", func = function() ns.ShowCopy(SELECTED_CHAT_FRAME or ChatFrame1) end }
	UI.Menu(at, entries)
end
