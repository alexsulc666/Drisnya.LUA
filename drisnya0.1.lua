script_name("VisualTextWrap")
script_author("Sunless")
script_properties("work-in-pause")

local sampev = require("lib.samp.events")

local COLOR_ROLEPLAY = 0xC2A2DA -- #c2a2da (default)
local COLOR_PERMANENT = 0x8d8dff

local maxLen = 90 -- лимит видимых символов
local enabled = false
local colorRoleplay = COLOR_ROLEPLAY

local function stripColorCodes(str)
    return (str:gsub("{[%xX][%xX][%xX][%xX][%xX][%xX]}", ""))
end

local function getLastColorCode(str)
    local lastCode
    for code in str:gmatch("{[%xX][%xX][%xX][%xX][%xX][%xX]}") do
        lastCode = code
    end
    return lastCode
end

local function getOriginalColor(color, text)
    if text:find("^#8d8dff") or text:find("^{8d8dff}") then
        return COLOR_PERMANENT
    end
    return color
end

local function colorToTag(color)
    return string.format("{%06X}", bit.band(color, 0xFFFFFF))
end

local function isColorTagAt(str, pos)
    return str:sub(pos, pos+6):match("^{[%xX][%xX][%xX][%xX][%xX][%xX]}")
end

local function splitAndShowLongMessage(color, text, maxLenLocal)
    -- Пропуск разбивки для строк, начинающихся с [
    if text:find("^%[") then
        return false
    end

    local originalColor = getOriginalColor(color, text)
    local colorTag = colorToTag(originalColor)
    local lastColor = colorTag
   
    local str = text:gsub("{[aA][2][dD][aA][fF][fF]}", "{C2A2DA}")
    local first = true

    while #stripColorCodes(str) > maxLenLocal do
        
        local visible, cut = 0, 0
        local i = 1
        while i <= #str and visible < maxLenLocal do
            if isColorTagAt(str, i) then
                i = i + 7
            else
                visible = visible + 1
                i = i + 1
            end
            cut = i - 1
        end

        
        if isColorTagAt(str, cut - 5) then
            cut = cut - 6
        elseif isColorTagAt(str, cut - 6) then
            cut = cut - 7
        end

        
        local actualCut = cut
        while actualCut > 0 and str:sub(actualCut, actualCut):match("[%s]") do
            actualCut = actualCut - 1
        end
        if actualCut == 0 then actualCut = cut end

        local part = str:sub(1, actualCut)
        
        if not part:find("^{[%xX][%xX][%xX][%xX][%xX][%xX]}") then
            part = lastColor .. part
        end
        
        if first then
            part = part .. "..."
            first = false
        else
            part = "..." .. part .. "..."
        end
        part = part:gsub("{[aA][2][dD][aA][fF][fF]}", "{C2A2DA}")
        sampAddChatMessage(part, originalColor)
        lastColor = getLastColorCode(part) or lastColor

        str = str:sub(cut + 1)
       
        while true do
            local old = str
            str = str:gsub("^{[%xX][%xX][%xX][%xX][%xX][%xX]}", "")
            str = str:gsub("^%s+", "")
            if old == str then break end
        end
        str = str:gsub("{[aA][2][dD][aA][fF][fF]}", "{C2A2DA}")
    end

    if #stripColorCodes(str) > 0 then
        local part = str
        if not part:find("^{[%xX][%xX][%xX][%xX][%xX][%xX]}") then
            part = lastColor .. part
        end
        if not first then
            part = "..." .. part
        end
        part = part:gsub("{[aA][2][dD][aA][fF][fF]}", "{C2A2DA}")
        sampAddChatMessage(part, originalColor)
    end
    return true
end

function sampev.onServerMessage(color, text)
    if enabled and splitAndShowLongMessage(color, text, maxLen) then
        return false
    end
end

function main()
    while not isSampLoaded() do wait(100) end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("trt", function(param)
        local value = tonumber(param)
        if value and value >= 20 and value <= 1000 then -- лимит увеличен
            maxLen = value
            sampAddChatMessage("{FFFFFF}[ShulcTextWrap]{C2A2DA} New Warp Limit: " .. maxLen, -1)
        else
            sampAddChatMessage("{FFFFFF}[ShulcTextWrap]{C2A2DA} Usage: /trt [20-1000]", -1)
        end
    end)

    sampRegisterChatCommand("trd", function()
        enabled = not enabled
        if enabled then
            sampAddChatMessage("{FFFFFF}[ShulcTextWrap]{C2A2DA} Warp Enabled.", -1)
        else
            sampAddChatMessage("{FFFFFF}[ShulcTextWrap]{C2A2DA} Warp Disabled.", -1)
        end
    end)

    sampRegisterChatCommand("trcrp", function(param)
        if param and tonumber(param) then
            colorRoleplay = tonumber(param)
            sampAddChatMessage(string.format("{FFFFFF}[ShulcTextWrap]{C2A2DA} New color RP: 0x%06X", colorRoleplay), -1)
        else
            sampAddChatMessage("{FFFFFF}[ShulcTextWrap]{C2A2DA} Usage: /trcrp [id color]", -1)
        end
    end)

    while true do wait(0) end
end