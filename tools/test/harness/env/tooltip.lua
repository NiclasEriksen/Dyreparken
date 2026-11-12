-- GameTooltip: lines, colors, hidden lines and the GameTooltipTextLeftN/RightN font strings.
local H, P = ...

return function(c, env, S)
    local w = c.world
    -- lines[i] = left text; right[i], colors[i], hidden[i] per line. The
    -- GameTooltipTextLeftN / RightN font strings read and write these.
    local tip = { lines = {}, right = {}, colors = {}, hidden = {} }
    function tip:GetName() return "GameTooltip" end
    function tip:NumLines() return #self.lines end
    for i = 1, 40 do
        local function Side(isRight)
            local fs = {}
            function fs:GetText()
                if isRight then return tip.right[i] end
                return tip.lines[i]
            end
            function fs:SetText(x)
                if isRight then tip.right[i] = x else tip.lines[i] = x or "" end
            end
            function fs:SetTextColor(r, g, b) if not isRight then tip.colors[i] = { r, g, b } end end
            function fs:GetTextColor()
                local col = tip.colors[i] or { 1, 1, 1 }
                return col[1], col[2], col[3], 1
            end
            function fs:Show() if isRight then tip.rightShown = tip.rightShown or {}; tip.rightShown[i] = true
                else tip.hidden[i] = nil end end
            function fs:Hide() if isRight then tip.rightShown = tip.rightShown or {}; tip.rightShown[i] = nil
                else tip.hidden[i] = true end end
            function fs:IsShown()
                if isRight then return (tip.rightShown or {})[i] == true end
                return tip.lines[i] ~= nil and not tip.hidden[i]
            end
            return fs
        end
        env["GameTooltipTextLeft" .. i] = Side(false)
        env["GameTooltipTextRight" .. i] = Side(true)
    end
    function tip:AddLine(text, r, g, b)
        self.lines[#self.lines + 1] = text
        if r then self.colors[#self.lines] = { r, g, b } end
    end
    function tip:AddDoubleLine(a, b) self.lines[#self.lines + 1] = a .. " " .. b end
    function tip:SetText(text) self.lines = { text } end
    function tip:ClearLines() self.lines, self.right, self.colors, self.hidden = {}, {}, {}, {} end
    function tip:SetOwner(owner) self.owner = owner; self.lines = {} end
    function tip:IsOwned(owner) return self.owner == owner end
    function tip:Show() self.shown = true end
    function tip:Hide() self.shown = false; self.owner = nil end
    function tip:GetUnit()
        if not self.unit then return nil end
        local u = c.units[self.unit]
        return u and u.name, self.unit
    end
    env.GameTooltip = tip

end
