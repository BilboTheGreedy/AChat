local _, ns = ...

local SHORT = {
	GUILD = "G", OFFICER = "O", PARTY = "P", PARTY_LEADER = "PL", RAID = "R", RAID_LEADER = "RL",
	RAID_WARNING = "RW", INSTANCE_CHAT = "I", INSTANCE_CHAT_LEADER = "IL", BATTLEGROUND = "BG",
	BATTLEGROUND_LEADER = "BL", SAY = "S", YELL = "Y",
}

local function shortChannel(link, text)
	local kind, rest = link:match("^channel:([^:]+):?(.*)$")
	if not kind then return nil end
	local upper = kind:upper()
	if upper == "CHANNEL" then
		local num = text:match("^(%d+)") or rest:match("^(%d+)")
		if num then return num end
		return nil
	end
	local s = SHORT[upper]
	if not s then return nil end
	local leader = (upper == "PARTY" and text == (CHAT_PARTY_LEADER or PARTY_LEADER or "Party Leader"))
		or (upper == "RAID" and text == (RAID_LEADER or "Raid Leader"))
		or (upper == "INSTANCE_CHAT" and text == (INSTANCE_CHAT_LEADER or "Instance Leader"))
	if leader and #s == 1 then s = s .. "L" end
	return s
end

function ns.Format(text)
	local db = ns.db
	if db.shorten then
		text = text:gsub("(|Hchannel:(.-)|h)%[(.-)%](|h)", function(open, link, label, close)
			local s = shortChannel("channel:" .. link, label)
			if not s then return nil end
			return open .. "[" .. s .. "]" .. close
		end)
	end
	if db.levels then
		text = text:gsub("(|Hplayer:([^:|]+)[^|]*|h%[)", function(open, name)
			local level = ns.levels[ns.Short(name)]
			if not level then return nil end
			return open .. level .. ":"
		end, 1)
	end
	return text
end

local wrapped = {}
local base = {}
local charKey

local function num(v)
	if ns.IsSecret(v) or type(v) ~= "number" then return nil end
	return v
end

function ns.Store(frame, create)
	local name = frame.GetName and frame:GetName()
	if not charKey or type(name) ~= "string" then return nil end
	local saved = ns.db.saved
	if type(saved) ~= "table" then
		if not create then return nil end
		saved = {}
		ns.db.saved = saved
	end
	local mine = saved[charKey]
	if type(mine) ~= "table" then
		if not create then return nil end
		mine = {}
		saved[charKey] = mine
	end
	if type(mine[name]) ~= "table" and create then mine[name] = {} end
	return mine[name]
end

function ns.Keep(frame, text, r, g, b)
	if not base[frame] or #text > 600 then return end
	local list = ns.Store(frame, true)
	if not list then return end
	list[#list + 1] = { text, num(r) or 1, num(g) or 1, num(b) or 1 }
	local max = ns.db.keepLines or 60
	while #list > max do table.remove(list, 1) end
end

function ns.Replay()
	local n = 0
	if not charKey then return n end
	if not ns.db.keep then
		if type(ns.db.saved) == "table" then ns.db.saved[charKey] = nil end
		return n
	end
	for _, f in ipairs(ns.Frames()) do
		local orig = wrapped[f]
		local list = orig and ns.Store(f)
		if list then
			for _, m in ipairs(list) do
				if type(m) == "table" and type(m[1]) == "string" then
					orig(f, m[1], (num(m[2]) or 1) * 0.75, (num(m[3]) or 1) * 0.75, (num(m[4]) or 1) * 0.75)
					n = n + 1
				end
			end
		end
	end
	return n
end

function ns.Wrap(frame)
	if wrapped[frame] or ns.IsCombatLog(frame) then return end
	local orig = frame.AddMessage
	if type(orig) ~= "function" then return end
	wrapped[frame] = orig
	frame.AddMessage = function(self, text, ...)
		local db = ns.db
		if db and not ns.IsSecret(text) and type(text) == "string" then
			if db.shorten or db.levels then
				local ok, out = pcall(ns.Format, text)
				if ok and type(out) == "string" then text = out end
			end
			if db.keep then pcall(ns.Keep, self, text, ...) end
		end
		return orig(self, text, ...)
	end
end

function ns.WrapAll()
	local db = ns.db
	if not db.shorten and not db.levels and not db.keep then return end
	for _, f in ipairs(ns.Frames()) do
		if not ns.IsCombatLog(f) then base[f] = true end
		ns.Wrap(f)
	end
end

local function remember(name, level)
	if ns.IsSecret(name) or ns.IsSecret(level) then return end
	if type(name) ~= "string" or type(level) ~= "number" or level < 1 then return end
	ns.levels[ns.Short(name)] = level
end

local function unit(u)
	if not UnitExists or not UnitExists(u) then return end
	local ok, player = pcall(UnitIsPlayer, u)
	if not ok or ns.IsSecret(player) or not player then return end
	local name = UnitName(u)
	local level = UnitLevel(u)
	remember(name, level)
end

local function group()
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	if type(n) ~= "number" then return end
	local raid = IsInRaid and IsInRaid()
	for i = 1, n do
		unit((raid and "raid" or "party") .. i)
	end
end

local function guild()
	if not GetNumGuildMembers or not GetGuildRosterInfo then return end
	local n = GetNumGuildMembers() or 0
	for i = 1, math.min(n, 1000) do
		local name, _, _, level = GetGuildRosterInfo(i)
		remember(name, level)
	end
end

local function who()
	if not C_FriendList or not C_FriendList.GetNumWhoResults then return end
	for i = 1, C_FriendList.GetNumWhoResults() or 0 do
		local info = C_FriendList.GetWhoInfo(i)
		if info then remember(info.fullName, info.level) end
	end
end

ns:Listen("LOGIN", function()
	unit("player")
	group()
	guild()
	charKey = ACore.CharKey()
	ns.WrapAll()
	ns.Replay()
end)
ns:On("GROUP_ROSTER_UPDATE", function() ns.Debounce("group", 1, group) end)
ns:On("GUILD_ROSTER_UPDATE", function() ns.Debounce("guild", 2, guild) end)
ns:On("WHO_LIST_UPDATE", who)
ns:On("PLAYER_TARGET_CHANGED", function() unit("target") end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() unit("mouseover") end)
ns:On("PLAYER_LEVEL_UP", function(level) remember(UnitName("player"), level) end)
ns:Listen("OPTIONS", function() ns.WrapAll() end)
