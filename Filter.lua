local _, ns = ...

local EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
	"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_BN_WHISPER",
	"CHAT_MSG_BN_WHISPER_INFORM",
}

local SPAM = { CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_CHANNEL = true, CHAT_MSG_EMOTE = true }
local OWN = { CHAT_MSG_WHISPER_INFORM = true, CHAT_MSG_BN_WHISPER_INFORM = true }

local function trimUrl(word)
	local tail = ""
	while true do
		local last = word:sub(-1)
		if last == "." or last == "," or last == "!" or last == "?" or last == ")" or last == ";" or last == ":" or last == "'" or last == '"' then
			tail = last .. tail
			word = word:sub(1, -2)
		else
			break
		end
	end
	return word, tail
end

function ns.Urls(msg)
	if not msg:find("%.") then return msg end
	return (msg:gsub("%S+", function(word)
		if word:find("|", 1, true) then return nil end
		local lower = word:lower()
		if not (lower:find("^https?://.") or lower:find("^www%.[%w%-]+%.%a") or lower:find("^[%w%-]+%.[%w%-%.]*%a%a/%S")) then
			if not lower:find("^[%w%-%.]+%.com$") and not lower:find("^[%w%-%.]+%.gg$") and not lower:find("^[%w%-%.]+%.net$") and not lower:find("^[%w%-%.]+%.org$") then
				return nil
			end
		end
		local url, tail = trimUrl(word)
		if #url < 5 then return nil end
		return "|cff66b3ff|Haddon:achat:" .. url .. "|h[" .. url .. "]|h|r" .. tail
	end))
end

local patterns
local function build()
	patterns = {}
	local words = {}
	for _, w in ipairs(ns.db.keywords) do words[#words + 1] = w end
	if ns.db.highlightName and ns.playerName then words[#words + 1] = ns.playerName:lower() end
	for _, w in ipairs(words) do
		local p = w:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%a", function(c)
			return "[" .. c:lower() .. c:upper() .. "]"
		end)
		patterns[#patterns + 1] = { plain = w, pattern = p }
	end
end

function ns.Highlight(msg)
	if not patterns then build() end
	if #patterns == 0 then return msg, false end
	local lower = msg:lower()
	local hit = false
	for _, p in ipairs(patterns) do
		if lower:find(p.plain, 1, true) then
			hit = true
			if not msg:find("|", 1, true) then
				msg = msg:gsub(p.pattern, "|cffffd100%0|r")
			end
		end
	end
	return msg, hit
end

local recent = {}
local function isSpam(event, msg, sender)
	if not SPAM[event] then return false end
	if ns.playerName and ns.Short(sender) == ns.playerName then return false end
	local now = GetTime and GetTime() or 0
	local key = sender .. "\001" .. msg:lower():gsub("%s+", " ")
	local last = recent[key]
	recent[key] = now
	recent.n = (recent.n or 0) + 1
	if recent.n > 400 then
		local keep = {}
		for k, t in pairs(recent) do
			if k ~= "n" and now - t < (ns.db.spamWindow or 10) then keep[k] = t end
		end
		recent = keep
		recent.n = 0
	end
	return last ~= nil and now - last < (ns.db.spamWindow or 10)
end

local lines = {}
local lineCount = 0

local function filter(_, event, msg, sender, ...)
	local db = ns.db
	if not db or ns.IsSecret(msg) or ns.IsSecret(sender) then return false end
	if type(msg) ~= "string" then return false end
	if type(sender) ~= "string" then sender = "" end
	local lineID = select(9, ...)
	if ns.IsSecret(lineID) then lineID = nil end
	local cached = lineID and lines[lineID]
	if not cached then
		cached = { msg = msg }
		if db.spam and lineID and isSpam(event, msg, sender) then
			cached.drop = true
		else
			if db.urls then cached.msg = ns.Urls(cached.msg) end
			if db.highlight and not OWN[event] and ns.Short(sender) ~= ns.playerName then
				local out, hit = ns.Highlight(cached.msg)
				cached.msg = out
				if hit and db.highlightSound and lineID then ns.Sound("RAID_WARNING", 8959) end
			end
			if db.whisperSound and lineID and (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER") then
				ns.Sound("TELL_MESSAGE", 3081)
			end
		end
		if lineID then
			lines[lineID] = cached
			lineCount = lineCount + 1
			if lineCount > 300 then
				lines = { [lineID] = cached }
				lineCount = 1
			end
		end
	end
	if cached.drop then return true end
	if cached.msg ~= msg then return false, cached.msg, sender, ... end
	return false
end

ns.Filter = filter

ns:Listen("LOGIN", function()
	local name = UnitName("player")
	if type(name) == "string" and not ns.IsSecret(name) then ns.playerName = name end
	patterns = nil
	local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
	if not add then return end
	for _, event in ipairs(EVENTS) do pcall(add, event, filter) end
end)
ns:Listen("KEYWORDS", function() patterns = nil end)
ns:Listen("OPTIONS", function() patterns = nil end)
