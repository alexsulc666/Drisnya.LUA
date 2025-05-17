script_name("VisualTextWrap")
script_author("Sunless")
script_properties("work-in-pause")

local sampev = require("lib.samp.events")
local inicfg = require "inicfg"
local config_path = "drisnia.ini"
local config = {settings={maxLen=90, colorRoleplay=0xC2A2DA, colorChat=0xC924FF, breakWords=1, autoEnable=0}}
local enabled = false

-- Пробуем загрузить конфиг
if inicfg.load(nil, config_path) then
    local file = inicfg.load(nil, config_path)
    config.settings.maxLen = tonumber(file.settings.maxLen) or 90
    config.settings.colorRoleplay = tonumber(file.settings.colorRoleplay) or 0xC2A2DA
    config.settings.colorChat = tonumber(file.settings.colorChat) or 0xC924FF
    config.settings.breakWords = tonumber(file.settings.breakWords) or 1
    config.settings.autoEnable = tonumber(file.settings.autoEnable) or 0
end

local maxLen = config.settings.maxLen
local colorRoleplay = config.settings.colorRoleplay
local colorTagRoleplay = string.format("{%06X}", bit.band(colorRoleplay, 0xFFFFFF))
local colorChat = config.settings.colorChat
local colorTagChat = string.format("{%06X}", bit.band(colorChat, 0xFFFFFF))
local breakWords = config.settings.breakWords -- 1 - разрывать слова, 0 - переносить целиком
local autoEnable = config.settings.autoEnable -- 1 - автозапуск, 0 - нет

-- Перманентные цвета
local colorTagPermanent = "{AA4444}" -- для {4444FF} и {6666FF}
local colorTagPurple = "{CCCCCC}"    -- для {9C16FF}
local colorTag8070 = "{AA8070}"      -- для {8070FF}
local colorTag5abb = "{5A5ABB}"      -- для {5ABBFF}
local colorTag8dff = "{8D8DFF}"      -- для {8DFFFF}
local colorTagDEB3 = "{F5DEB3}"      -- для {DEB3FF}
local colorTagAFAF = "{AFAFAF}"      -- для {AFAFFF}
local colorTagFF00 = "{FFFF00}"      -- для {FF00FF}
local colorTagBFFF = "{00BFFF}"      -- для {BFFFFF}
local colorTagA9B8 = "{FFFFFF}"      -- для {A9B8FF}

-- Перманентная замена {1111FF} на #921111
local colorTag1111FF = "{921111}"    -- для {1111FF}

local function saveConfig()
    config.settings.maxLen = maxLen
    config.settings.colorRoleplay = colorRoleplay
    config.settings.colorChat = colorChat
    config.settings.breakWords = breakWords
    config.settings.autoEnable = autoEnable
    inicfg.save(config, config_path)
end

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

local COLOR_PERMANENT = 0x8d8dff
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

local function replaceRoleplayColor(str)
    return str:gsub("{[aA][2][dD][aA][fF][fF]}", colorTagRoleplay)
end

local function replaceChatColor(str)
    return str:gsub("{[cC]9[2][4][fF][fF]}", colorTagChat)
end

local function replacePermanentColors(str)
    str = str:gsub("{[4][4][4][4][fF][fF]}", colorTagPermanent)
    str = str:gsub("{[6][6][6][6][fF][fF]}", colorTagPermanent)
    str = str:gsub("{[9][cC][1][6][fF][fF]}", colorTagPurple)
    str = str:gsub("{[8][0][7][0][fF][fF]}", colorTag8070)
    str = str:gsub("{[5][aA][bB][bB][fF][fF]}", colorTag5abb)
    str = str:gsub("{[8][dD][fF][fF][fF][fF]}", colorTag8dff)
    str = str:gsub("{[dD][eE][bB][3][fF][fF]}", colorTagDEB3)
    str = str:gsub("{[aA][fF][aA][fF][fF][fF]}", colorTagAFAF)
    str = str:gsub("{[fF][fF][0][0][fF][fF]}", colorTagFF00)
    str = str:gsub("{[bB][fF][fF][fF][fF][fF]}", colorTagBFFF)
    str = str:gsub("{[aA][9][bB][8][fF][fF]}", colorTagA9B8)
    str = str:gsub("{[1][1][1][1][fF][fF]}", colorTag1111FF) -- добавлена замена {1111FF} на {921111}
    return str
end

local function replaceAllCustomColors(str)
    str = replaceRoleplayColor(str)
    str = replaceChatColor(str)
    str = replacePermanentColors(str)
    return str
end

local function parseColorParam(param)
    if type(param) == "string" then
        local hex = param:match("^#?([%xX]+)$")
        if hex and #hex == 6 then
            return tonumber(hex, 16)
        end
    end
    return tonumber(param)
end

local function shouldIgnoreWrap(str)
    return str:find("^%[Гос") or str:find("^%[Реклама")
end

local function splitAndShowLongMessage(color, text, maxLenLocal)
    if shouldIgnoreWrap(text) then
        -- Не переносим такие строки, просто выводим как есть
        sampAddChatMessage(replaceAllCustomColors(text), color)
        return true
    end

    local originalColor = getOriginalColor(color, text)
    local colorTag = colorToTag(originalColor)
    local lastColor = colorTag
    local str = replaceAllCustomColors(text)
    local first = true

    if breakWords == 1 then
        -- Стиль: разрывать слова (старое поведение)
        while #stripColorCodes(str) > maxLenLocal do
            local visible = 0
            local cut = 0
            local i = 1
            while i <= #str and visible < maxLenLocal do
                if isColorTagAt(str, i) then
                    i = i + 7
                    cut = i - 1
                else
                    visible = visible + 1
                    i = i + 1
                    cut = i - 1
                end
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
                part = part .. lastColor .. "..."
                first = false
            else
                part = lastColor .. "..." .. part .. lastColor .. "..."
            end
            part = replaceAllCustomColors(part)
            sampAddChatMessage(part, originalColor)
            lastColor = getLastColorCode(part) or lastColor

            str = str:sub(cut + 1)
            while true do
                local old = str
                str = str:gsub("^{[%xX][%xX][%xX][%xX][%xX][%xX]}", "")
                str = str:gsub("^%s+", "")
                if old == str then break end
            end
            str = replaceAllCustomColors(str)
        end
    else
        -- Новый стиль: переносить слова целиком (не разрывать)
        while #stripColorCodes(str) > maxLenLocal do
            local visible = 0
            local cut = 0
            local i = 1
            local lastWordEnd = 0
            local lastWordVisible = 0
            local wordStart = 1
            while i <= #str and visible < maxLenLocal do
                if isColorTagAt(str, i) then
                    i = i + 7
                else
                    local c = str:sub(i, i)
                    if c:match("%s") then
                        lastWordEnd = i
                        lastWordVisible = visible
                        wordStart = i + 1
                    end
                    visible = visible + 1
                    i = i + 1
                end
                cut = i - 1
            end
            local breakPos
            if lastWordEnd > 0 and lastWordVisible > 0 then
                breakPos = lastWordEnd
            else
                breakPos = cut
            end

            if isColorTagAt(str, breakPos - 5) then
                breakPos = breakPos - 6
            elseif isColorTagAt(str, breakPos - 6) then
                breakPos = breakPos - 7
            end

            local actualCut = breakPos
            while actualCut > 0 and str:sub(actualCut, actualCut):match("[%s]") do
                actualCut = actualCut - 1
            end
            if actualCut == 0 then actualCut = breakPos end

            local part = str:sub(1, actualCut)
            if not part:find("^{[%xX][%xX][%xX][%xX][%xX][%xX]}") then
                part = lastColor .. part
            end

            if first then
                part = part .. lastColor .. "..."
                first = false
            else
                part = lastColor .. "..." .. part .. lastColor .. "..."
            end
            part = replaceAllCustomColors(part)
            sampAddChatMessage(part, originalColor)
            lastColor = getLastColorCode(part) or lastColor

            str = str:sub(breakPos + 1)
            while true do
                local old = str
                str = str:gsub("^{[%xX][%xX][%xX][%xX][%xX][%xX]}", "")
                str = str:gsub("^%s+", "")
                if old == str then break end
            end
            str = replaceAllCustomColors(str)
        end
    end

    if #stripColorCodes(str) > 0 then
        local part = str
        if not part:find("^{[%xX][%xX][%xX][%xX][%xX][%xX]}") then
            part = lastColor .. part
        end
        if not first then
            part = lastColor .. "..." .. part
        end
        part = replaceAllCustomColors(part)
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

    if autoEnable == 1 then
        enabled = true
        sampAddChatMessage("{FFFFFF}[SunlessTextWrap] AutoEnable: {88FF88}ON", -1)
    else
        sampAddChatMessage("{FFFFFF}[SunlessTextWrap] AutoEnable: {FF8888}OFF", -1)
    end

    sampRegisterChatCommand("trt", function(param)
        local value = tonumber(param)
        if value and value >= 20 and value <= 1000 then
            maxLen = value
            saveConfig()
            sampAddChatMessage("{FFFFFF}[SunlessTextWrap]" .. colorTagRoleplay .. " New Warp Limit: " .. maxLen, -1)
        else
            sampAddChatMessage("{FFFFFF}[SunlessTextWrap]" .. colorTagRoleplay .. " Usage: /trt [20-1000]", -1)
        end
    end)

    sampRegisterChatCommand("trd", function()
        enabled = not enabled
        if enabled then
            sampAddChatMessage("{FFFFFF}[SunlessTextWrap]" .. colorTagRoleplay .. " Warp Enabled.", -1)
        else
            sampAddChatMessage("{FFFFFF}[SunlessTextWrap]" .. colorTagRoleplay .. " Warp Disabled.", -1)
        end
    end)

    sampRegisterChatCommand("trcrp", function(param)
        local clr = parseColorParam(param)
        if clr then
            colorRoleplay = clr
            colorTagRoleplay = colorToTag(colorRoleplay)
            saveConfig()
            sampAddChatMessage(string.format(
                "{FFFFFF}[SunlessTextWrap]%s New Color RP: %s (#%06X)",
                colorTagRoleplay, colorTagRoleplay, colorRoleplay), -1)
        else
            sampAddChatMessage("{FFFFFF}[SunlessTextWrap]" .. colorTagRoleplay .. " Usage: /trcrp [id color|#hexcolor]", -1)
        end
    end)

    sampRegisterChatCommand("trchat", function(param)
        local clr = parseColorParam(param)
        if clr then
            colorChat = clr
            colorTagChat = colorToTag(colorChat)
            saveConfig()
            sampAddChatMessage(string.format(
                "{FFFFFF}[SunlessTextWrap]%s New Color Chat: %s (#%06X)",
                colorTagChat, colorTagChat, colorChat), -1)
        else
            sampAddChatMessage("{FFFFFF}[SunlessTextWrap]" .. colorTagChat .. " Usage: /trchat [id color|#hexcolor]", -1)
        end
    end)

    sampRegisterChatCommand("trtp", function()
        breakWords = 1 - breakWords
        saveConfig()
        if breakWords == 1 then
            sampAddChatMessage("{FFFFFF}[SunlessTextWrap] Words Warp: {FF8888}brake words", -1)
        else
            sampAddChatMessage("{FFFFFF}[SunlessTextWrap] Words Warp: {88FF88}save words", -1)
        end
    end)

    sampRegisterChatCommand("trauto", function(param)
        if param == "1" or param == "on" or param == "вкл" then
            autoEnable = 1
            enabled = true
            saveConfig()
            sampAddChatMessage("{FFFFFF}[SunlessTextWrap] AutoEnable: {88FF88}ON", -1)
        elseif param == "0" or param == "off" or param == "выкл" then
            autoEnable = 0
            saveConfig()
            sampAddChatMessage("{FFFFFF}[SunlessTextWrap] AutoEnable: {FF8888}OFF", -1)
        else
            sampAddChatMessage("{FFFFFF}[SunlessTextWrap] Usage: /trauto [1|0|on|off|вкл|выкл]", -1)
        end
    end)

    while true do wait(0) end
end