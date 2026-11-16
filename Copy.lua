local _, ns = ...
local UI = ns.UI

local window

function ns.Plain(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "?")
	text = text:gsub("||", "|")
	return text
end

function ns.Lines(frame, max)
	local out = {}
	if not frame or not frame.GetNumMessages then return out end
	local n = frame:GetNumMessages() or 0
	local first = math.max(1, n - (max or 300) + 1)
	for i = first, n do
		local ok, text = pcall(frame.GetMessageInfo, frame, i)
		if ok and not ns.IsSecret(text) and type(text) == "string" then
			out[#out + 1] = ns.Plain(text)
		end
	end
	return out
end

local function build()
	ns.db.copyWindow = ns.db.copyWindow or {}
	window = UI.Window("AChatCopy", "Copy chat", 620, 420, ns.db.copyWindow)
	local hint = UI.Text(window.bar, "GameFontDisableSmall", "RIGHT", UI.colors.dim)
	hint:SetPoint("RIGHT", window.close, "LEFT", -10, 0)
	hint:SetText("Ctrl-A selects all, Ctrl-C copies")
	local scroll = CreateFrame("ScrollFrame", nil, window.body)
	scroll:SetPoint("TOPLEFT", 10, -8)
	scroll:SetPoint("BOTTOMRIGHT", -10, 8)
	scroll:EnableMouseWheel(true)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject("GameFontHighlightSmall")
	box:SetWidth(596)
	box:SetMaxLetters(0)
	box:SetScript("OnEscapePressed", function() window:Hide() end)
	scroll:SetScrollChild(box)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange() or 0
		local pos = (self:GetVerticalScroll() or 0) - delta * 40
		if pos < 0 then pos = 0 end
		if pos > range then pos = range end
		self:SetVerticalScroll(pos)
	end)
	scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
	window.scroll = scroll
	window.box = box
end

function ns.ShowCopy(frame)
	if not window then build() end
	local lines = ns.Lines(frame, ns.db.copyLines)
	window.box:SetText(table.concat(lines, "\n"))
	window:Show()
	window.box:SetFocus()
	window.box:HighlightText()
	ns.After(0, function()
		local range = window.scroll:GetVerticalScrollRange() or 0
		if type(range) == "number" then window.scroll:SetVerticalScroll(range) end
	end)
	return #lines
end

function ns.ShowUrl(url)
	UI.Prompt("Ctrl-C to copy the link", url, function() end)
end

local function invite(name)
	if C_PartyInfo and C_PartyInfo.InviteUnit then
		pcall(C_PartyInfo.InviteUnit, name)
	elseif InviteUnit then
		pcall(InviteUnit, name)
	end
end

function ns.OnLink(link, _, button)
	if type(link) ~= "string" or ns.IsSecret(link) or not ns.db then return end
	local url = link:match("^addon:achat:(.+)$")
	if url then
		ns.ShowUrl(url)
		return
	end
	if ns.db.altInvite and button ~= "RightButton" and IsAltKeyDown and IsAltKeyDown() then
		local name = link:match("^player:([^:]+)")
		if name then
			invite(name)
			local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
			if eb and eb.GetText and eb:GetText() == "" and ChatEdit_DeactivateChat then
				pcall(ChatEdit_DeactivateChat, eb)
			end
		end
	end
end

ns:Listen("LOGIN", function()
	if hooksecurefunc and SetItemRef then
		pcall(hooksecurefunc, "SetItemRef", function(link, text, button) ns.OnLink(link, text, button) end)
	end
end)
