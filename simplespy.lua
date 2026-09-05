--[[
    highlight.lua - Syntax Highlighter بسيط ومطور
    - تلوين ذكي للكود
    - دعم جميع أنواع الـ Lua
    - أداء محسن
]]

local cloneref = cloneref or function(...) return ... end
local TextService = cloneref(game:GetService("TextService"))
local RunService = cloneref(game:GetService("RunService"))

--- @class Highlight
local Highlight = {}

-- ============================================================
-- المتغيرات الأساسية
-- ============================================================

local parentFrame
local scrollingFrame
local textFrame
local lineNumbersFrame
local tableContents = {}
local line = 0
local largestX = 0
local lineSpace = 15
local font = Enum.Font.Ubuntu
local textSize = 14
local offLimits = {}

-- ============================================================
-- الألوان (واضحة وجميلة)
-- ============================================================

local Colors = {
    background = Color3.fromRGB(40, 44, 52),
    lineNumber = Color3.fromRGB(148, 148, 148),
    default = Color3.fromRGB(224, 108, 117),
    keyword = Color3.fromRGB(187, 85, 255),      -- بنفسجي
    function_ = Color3.fromRGB(97, 175, 239),    -- أزرق
    string = Color3.fromRGB(152, 195, 121),      -- أخضر
    number = Color3.fromRGB(209, 154, 102),      -- برتقالي
    comment = Color3.fromRGB(148, 148, 148),     -- رمادي
    object = Color3.fromRGB(229, 192, 123),      -- ذهبي
    operator = Color3.fromRGB(200, 200, 200),    -- أبيض رمادي
    boolean = Color3.fromRGB(209, 154, 102),     -- برتقالي
    variable = Color3.fromRGB(220, 220, 255),    -- أبيض مائل للأزرق
}

-- ============================================================
-- دوال مساعدة
-- ============================================================

function gfind(str, pattern)
    return coroutine.wrap(function()
        local start = 0
        while true do
            local findStart, findEnd = str:find(pattern, start)
            if findStart and findEnd ~= #str then
                start = findEnd + 1
                coroutine.yield(findStart, findEnd)
            else
                return
            end
        end
    end)
end

function isOffLimits(index)
    for _, v in next, offLimits do
        if index >= v[1] and index <= v[2] then
            return true
        end
    end
    return false
end

function autoEscape(s)
    local result = ""
    for i = 1, #s do
        local char = s:sub(i, i)
        if char == "<" then
            result = result .. "&lt;"
        elseif char == ">" then
            result = result .. "&gt;"
        elseif char == '"' then
            result = result .. "&quot;"
        elseif char == "'" then
            result = result .. "&apos;"
        elseif char == "&" then
            result = result .. "&amp;"
        else
            result = result .. char
        end
    end
    return result
end

-- ============================================================
-- دوال التلوين الرئيسية
-- ============================================================

function highlightPattern(patternArray, color)
    local str = Highlight:getRaw()
    local step = 1
    
    for _, pattern in next, patternArray do
        for findStart, findEnd in gfind(str, pattern) do
            if step % 1000 == 0 then
                RunService.Heartbeat:Wait()
            end
            step = step + 1
            
            if not isOffLimits(findStart) and not isOffLimits(findEnd) then
                for i = findStart, findEnd do
                    if tableContents[i] then
                        tableContents[i].Color = color
                    end
                end
            end
        end
    end
end

function renderComments()
    local str = Highlight:getRaw()
    local step = 1
    
    -- تلوين التعليقات العادية
    for commentStart, commentEnd in gfind(str, "%-%-[^\n]+") do
        if step % 1000 == 0 then
            RunService.Heartbeat:Wait()
        end
        step = step + 1
        
        if not isOffLimits(commentStart) then
            for i = commentStart, commentEnd do
                table.insert(offLimits, {commentStart, commentEnd})
                if tableContents[i] then
                    tableContents[i].Color = Colors.comment
                end
            end
        end
    end
    
    -- تلوين التعليقات الطويلة
    for commentStart, commentEnd in gfind(str, "%-%-%[%[[^%]%]]+%]?%]?") do
        if step % 1000 == 0 then
            RunService.Heartbeat:Wait()
        end
        step = step + 1
        
        if not isOffLimits(commentStart) then
            for i = commentStart, commentEnd do
                table.insert(offLimits, {commentStart, commentEnd})
                if tableContents[i] then
                    tableContents[i].Color = Colors.comment
                end
            end
        end
    end
end

function renderStrings()
    local inString = false
    local stringStart = 0
    local stringChar = ""
    
    for i, char in next, tableContents do
        if not inString and (char.Char == '"' or char.Char == "'") and not isOffLimits(i) then
            inString = true
            stringStart = i
            stringChar = char.Char
            char.Color = Colors.string
        elseif inString and char.Char == stringChar and not isOffLimits(i) then
            inString = false
            char.Color = Colors.string
            table.insert(offLimits, {stringStart, i})
        elseif inString then
            char.Color = Colors.string
        end
    end
end

-- ============================================================
-- الدالة الرئيسية للتلوين
-- ============================================================

function render()
    offLimits = {}
    textFrame:ClearAllChildren()
    lineNumbersFrame:ClearAllChildren()
    
    -- ============================================================
    -- التلوين حسب النوع
    -- ============================================================
    
    -- 1. الكلمات المفتاحية (if, for, while, etc.)
    local keywords = {
        "function", "local", "if", "then", "else", "elseif", "end",
        "for", "while", "do", "repeat", "until",
        "return", "break", "continue", "goto",
        "and", "or", "not"
    }
    
    for _, keyword in next, keywords do
        local pattern = "[^%w_](" .. keyword .. ")[^%w_]"
        for findStart, findEnd in gfind(Highlight:getRaw(), pattern) do
            if not isOffLimits(findStart) and not isOffLimits(findEnd) then
                local start = findStart + 1
                local endPos = findEnd - 1
                for i = start, endPos do
                    if tableContents[i] then
                        tableContents[i].Color = Colors.keyword
                    end
                end
            end
        end
    end
    
    -- 2. الدوال
    local functions = {
        "[^%w_]([%a_][%a%d_]*)%s*%(",
        "^([%a_][%a%d_]*)%s*%(",
        "[:%.%(%[%p]([%a_][%a%d_]*)%s*%("
    }
    highlightPattern(functions, Colors.function_)
    
    -- 3. الأرقام
    local numbers = {
        "[^%w_](%d+[eE]?%d*)",
        "[^%w_](%.%d+[eE]?%d*)",
        "[^%w_](%d+%.%d+[eE]?%d*)",
        "^(%d+[eE]?%d*)",
        "^(%.%d+[eE]?%d*)",
        "^(%d+%.%d+[eE]?%d*)"
    }
    highlightPattern(numbers, Colors.number)
    
    -- 4. القيم المنطقية (true, false, nil)
    local booleans = {
        "[^%w_](true)", "^(true)",
        "[^%w_](false)", "^(false)",
        "[^%w_](nil)", "^(nil)"
    }
    highlightPattern(booleans, Colors.boolean)
    
    -- 5. الكائنات (object:method)
    local objects = {
        "[^%w_:]([%a_][%a%d_]*):",
        "^([%a_][%a%d_]*):"
    }
    highlightPattern(objects, Colors.object)
    
    -- 6. المعاملات
    local operators = {
        "[^_%s%w=>~<%-%+%*]", ">", "~", "<", "%-", "%+", "=", "%*"
    }
    highlightPattern(operators, Colors.operator)
    
    -- 7. التعليقات
    renderComments()
    
    -- 8. النصوص
    renderStrings()
    
    -- ============================================================
    -- عرض النص الملون
    -- ============================================================
    
    local lastColor
    local lineStr = ""
    local rawStr = ""
    largestX = 0
    line = 1
    
    for i = 1, #tableContents + 1 do
        local char = tableContents[i]
        
        if i == #tableContents + 1 or (char and char.Char == "\n") then
            lineStr = lineStr .. (lastColor and "</font>" or "")
            
            local x = TextService:GetTextSize(rawStr, textSize, font, Vector2.new(math.huge, math.huge)).X + 60
            if x > largestX then
                largestX = x
            end
            
            local lineText = Instance.new("TextLabel")
            lineText.TextXAlignment = Enum.TextXAlignment.Left
            lineText.TextYAlignment = Enum.TextYAlignment.Top
            lineText.Position = UDim2.new(0, 0, 0, line * lineSpace - lineSpace / 2)
            lineText.Size = UDim2.new(0, x, 0, textSize)
            lineText.RichText = true
            lineText.Font = font
            lineText.TextSize = textSize
            lineText.BackgroundTransparency = 1
            lineText.Text = lineStr
            lineText.Parent = textFrame
            
            if i ~= #tableContents + 1 then
                local lineNumber = Instance.new("TextLabel")
                lineNumber.Text = tostring(line)
                lineNumber.Font = font
                lineNumber.TextSize = textSize
                lineNumber.Size = UDim2.new(1, 0, 0, lineSpace)
                lineNumber.TextXAlignment = Enum.TextXAlignment.Right
                lineNumber.TextColor3 = Colors.lineNumber
                lineNumber.Position = UDim2.new(0, 0, 0, line * lineSpace - lineSpace / 2)
                lineNumber.BackgroundTransparency = 1
                lineNumber.Parent = lineNumbersFrame
            end
            
            lineStr = ""
            rawStr = ""
            lastColor = nil
            line = line + 1
            
            if line % 5 == 0 then
                RunService.Heartbeat:Wait()
            end
        elseif char then
            if char.Char == " " then
                lineStr = lineStr .. char.Char
                rawStr = rawStr .. char.Char
            elseif char.Char == "\t" then
                lineStr = lineStr .. string.rep(" ", 4)
                rawStr = rawStr .. char.Char
            else
                if char.Color == lastColor then
                    lineStr = lineStr .. autoEscape(char.Char)
                else
                    lineStr = lineStr .. string.format(
                        '%s<font color="rgb(%d,%d,%d)">',
                        lastColor and "</font>" or "",
                        char.Color.R * 255,
                        char.Color.G * 255,
                        char.Color.B * 255
                    )
                    lineStr = lineStr .. autoEscape(char.Char)
                    lastColor = char.Color
                end
                rawStr = rawStr .. char.Char
            end
        end
    end
    
    updateZIndex()
    updateCanvasSize()
end

-- ============================================================
-- دوال التحكم في الواجهة
-- ============================================================

function updateCanvasSize()
    scrollingFrame.CanvasSize = UDim2.new(0, largestX + 20, 0, line * lineSpace + 20)
end

function onFrameSizeChange()
    local newSize = parentFrame.AbsoluteSize
    scrollingFrame.Size = UDim2.new(0, newSize.X, 0, newSize.Y)
end

function updateZIndex()
    for _, v in next, parentFrame:GetDescendants() do
        if v:IsA("GuiObject") then
            v.ZIndex = parentFrame.ZIndex
        end
    end
end

-- ============================================================
-- الدوال العامة (API)
-- ============================================================

function Highlight:init(frame)
    if typeof(frame) == "Instance" and frame:IsA("Frame") then
        frame:ClearAllChildren()
        
        parentFrame = frame
        scrollingFrame = Instance.new("ScrollingFrame")
        textFrame = Instance.new("Frame")
        lineNumbersFrame = Instance.new("Frame")
        
        scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
        scrollingFrame.BackgroundColor3 = Colors.background
        scrollingFrame.BorderSizePixel = 0
        scrollingFrame.ScrollBarThickness = 4
        
        textFrame.Size = UDim2.new(1, -45, 1, 0)
        textFrame.Position = UDim2.new(0, 45, 0, 0)
        textFrame.BackgroundTransparency = 1
        
        lineNumbersFrame.Size = UDim2.new(0, 30, 1, 0)
        lineNumbersFrame.BackgroundTransparency = 1
        
        textFrame.Parent = scrollingFrame
        lineNumbersFrame.Parent = scrollingFrame
        scrollingFrame.Parent = parentFrame
        
        render()
        
        parentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(onFrameSizeChange)
        parentFrame:GetPropertyChangedSignal("ZIndex"):Connect(updateZIndex)
    else
        error("Initialization error: argument " .. typeof(frame) .. " is not a Frame Instance")
    end
end

function Highlight:setRaw(raw)
    raw = raw .. "\n"
    tableContents = {}
    for i = 1, #raw do
        table.insert(tableContents, {
            Char = raw:sub(i, i),
            Color = Colors.default,
        })
        if i % 1000 == 0 then
            RunService.Heartbeat:Wait()
        end
    end
    render()
end

function Highlight:getRaw()
    local result = ""
    for _, char in next, tableContents do
        result = result .. char.Char
    end
    return result
end

function Highlight:getString()
    local result = ""
    for _, char in next, tableContents do
        result = result .. char.Char:sub(1, 1)
    end
    return result
end

function Highlight:getTable()
    return tableContents
end

function Highlight:getSize()
    return #tableContents
end

function Highlight:getLine(lineNum)
    local currentLine = 0
    local result = ""
    for _, v in next, tableContents do
        if v.Char == "\n" then
            currentLine = currentLine + 1
        end
        if currentLine == lineNum and v.Char ~= "\n" then
            result = result .. v.Char
        end
        if currentLine > lineNum then
            break
        end
    end
    return result
end

function Highlight:setLine(lineNum, text)
    local currentLine = 0
    local startPos = 0
    local endPos = 0
    
    for i, v in next, tableContents do
        if v.Char == "\n" then
            currentLine = currentLine + 1
            if currentLine == lineNum then
                startPos = i + 1
            elseif currentLine == lineNum + 1 then
                endPos = i
                break
            end
        end
    end
    
    if startPos > 0 and endPos > 0 then
        local str = Highlight:getRaw()
        str = str:sub(1, startPos - 1) .. text .. "\n" .. str:sub(endPos, -1)
        Highlight:setRaw(str)
    end
end

function Highlight:insertLine(lineNum, text)
    local currentLine = 0
    local insertPos = 0
    
    for i, v in next, tableContents do
        if v.Char == "\n" then
            currentLine = currentLine + 1
            if currentLine == lineNum then
                insertPos = i
                break
            end
        end
    end
    
    if insertPos > 0 then
        local str = Highlight:getRaw()
        str = str:sub(1, insertPos) .. text .. "\n" .. str:sub(insertPos + 1, -1)
        Highlight:setRaw(str)
    end
end

-- ============================================================
-- Constructor
-- ============================================================

local constructor = {}

function constructor.new(...)
    local class = Highlight
    local new = {}
    class.__index = class
    setmetatable(new, class)
    new:init(...)
    return new
end

return constructor
