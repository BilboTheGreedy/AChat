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
function ns.Wrap(frame)
	if wrapped[frame] or ns.IsCombatLog(frame) then return end
	local orig = frame.AddMessage
	if type(orig) ~= "function" then return end
	wrapped[frame] = orig
	frame.AddMessage = function(self, text, ...)
		local db = ns.db
		if db and (db.shorten or db.levels) and not ns.IsSecret(text) and type(text) == "string" then
			local ok, out = pcall(ns.Format, text)
			if ok and type(out) == "string" then text = out end
		end
		return orig(self, text, ...)
	end
end

function ns.WrapAll()
	if not ns.db.shorten and not ns.db.levels then return end
	for _, f in ipairs(ns.Frames()) do ns.Wrap(f) end
end

local function remember(name, level)
	if type(name) ~= "string" or type(level) ~= "number" then return end
	if ns.IsSecret(name) or ns.IsSecret(level) or level < 1 then return end
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
	ns.WrapAll()
end)
ns:On("GROUP_ROSTER_UPDATE", function() ns.Debounce("group", 1, group) end)
ns:On("GUILD_ROSTER_UPDATE", function() ns.Debounce("guild", 2, guild) end)
ns:On("WHO_LIST_UPDATE", who)
ns:On("PLAYER_TARGET_CHANGED", function() unit("target") end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() unit("mouseover") end)
ns:On("PLAYER_LEVEL_UP", function(level) remember(UnitName("player"), level) end)
ns:Listen("OPTIONS", function() ns.WrapAll() end)
