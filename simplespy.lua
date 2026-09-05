--[[
    highlight.lua v0.2.0 - Syntax Highlighter متطور
    - تلوين متقدم لكل أنواع الأكواد
    - دعم كامل للـ Lua 5.1 + Luau
    - أداء محسن
]]

local cloneref = cloneref or function(...) return ... end
local TextService = cloneref(game:GetService("TextService"))
local RunService = cloneref(game:GetService("RunService"))

--- @class Highlight
local Highlight = {}

-- ============================================================
-- الألوان الجديدة (أكثر تنوعاً وجمالاً)
-- ============================================================
local Colors = {
    Background = Color3.fromRGB(28, 30, 38),      -- خلفية داكنة
    LineNumber = Color3.fromRGB(80, 85, 100),     -- أرقام الأسطر
    
    -- الكلمات المفتاحية (Keywords)
    Keyword = Color3.fromRGB(197, 134, 192),      -- بنفسجي فاتح (if, for, while)
    KeywordControl = Color3.fromRGB(197, 134, 192), -- بنفسجي (return, break)
    KeywordCondition = Color3.fromRGB(230, 180, 100), -- ذهبي (then, else, elseif)
    
    -- الدوال
    Function = Color3.fromRGB(97, 175, 239),      -- أزرق فاتح
    FunctionCall = Color3.fromRGB(97, 175, 239),  -- أزرق فاتح
    
    -- المتغيرات
    Variable = Color3.fromRGB(220, 220, 255),     -- أبيض مائل للأزرق
    LocalVariable = Color3.fromRGB(200, 200, 230), 
    GlobalVariable = Color3.fromRGB(180, 200, 255),
    
    -- النصوص
    String = Color3.fromRGB(152, 195, 121),       -- أخضر
    StringEscape = Color3.fromRGB(200, 150, 100), -- برتقالي (للهروب)
    
    -- الأرقام
    Number = Color3.fromRGB(209, 154, 102),       -- برتقالي
    NumberHex = Color3.fromRGB(230, 180, 130),    -- ذهبي (للـ Hex)
    
    -- المعاملات
    Operator = Color3.fromRGB(187, 85, 255),      -- بنفسجي
    Assignment = Color3.fromRGB(255, 150, 150),   -- أحمر فاتح (=)
    Comparison = Color3.fromRGB(255, 200, 100),   -- ذهبي (==, ~=, <, >)
    Logic = Color3.fromRGB(200, 150, 255),        -- بنفسجي فاتح (and, or, not)
    
    -- التعليقات
    Comment = Color3.fromRGB(92, 99, 112),        -- رمادي
    CommentDoc = Color3.fromRGB(120, 140, 160),   -- رمادي مائل للأزرق (للتعليقات التوثيقية)
    CommentTodo = Color3.fromRGB(255, 200, 100),  -- ذهبي (لـ TODO, FIXME)
    
    -- الكائنات
    Object = Color3.fromRGB(229, 192, 123),       -- ذهبي
    Table = Color3.fromRGB(180, 160, 220),        -- بنفسجي مائل
    Instance = Color3.fromRGB(100, 200, 255),     -- سماوي (للـ Instances)
    
    -- ثوابت
    Boolean = Color3.fromRGB(209, 154, 102),      -- برتقالي (true/false)
    Nil = Color3.fromRGB(200, 100, 100),          -- أحمر خفيف
    Self = Color3.fromRGB(255, 200, 100),         -- ذهبي (self)
    
    -- آخر
    Parenthesis = Color3.fromRGB(200, 200, 200),  -- أبيض رمادي
    Bracket = Color3.fromRGB(200, 200, 200),
    Brace = Color3.fromRGB(200, 200, 200),
    Comma = Color3.fromRGB(200, 200, 200),
    Semicolon = Color3.fromRGB(200, 200, 200),
    Colon = Color3.fromRGB(200, 200, 200),
    Dot = Color3.fromRGB(200, 200, 200),
    
    -- للـ Luau
    Type = Color3.fromRGB(150, 200, 255),         -- أزرق فاتح (للأنواع)
    Generic = Color3.fromRGB(180, 220, 180),      -- أخضر فاتح
}

-- ============================================================
-- تعريف الأنماط (Patterns) المتقدمة
-- ============================================================

-- الكلمات المفتاحية (Keywords)
local keywords = {
    -- التحكم في التدفق
    "if", "then", "else", "elseif", "end",
    "for", "while", "do", "repeat", "until",
    "break", "return", "continue", "goto",
    -- المتغيرات
    "local", "global",
    -- الدوال
    "function", "coroutine", "yield",
    -- المعاملات المنطقية
    "and", "or", "not",
    -- آخر
    "nil", "true", "false",
    -- للـ Luau
    "type", "typeof", "assert", "error",
    "require", "pcall", "xpcall"
}

-- الكلمات المفتاحية للأوامر الشرطية
local conditionalKeywords = {"then", "else", "elseif", "do", "repeat", "until"}

-- الكلمات المفتاحية للتحكم
local controlKeywords = {"break", "return", "continue", "goto"}

-- أنماط الدوال
local functionPatterns = {
    "[^%w_]([%a_][%a%d_]*)%s*%(",  -- function call
    "^([%a_][%a%d_]*)%s*%(",        -- function call (بداية السطر)
    "[:%.%(%[%p]([%a_][%a%d_]*)%s*%(", -- method call
    "function%s+([%a_][%a%d_]*)%s*%(", -- function definition
    "local%s+function%s+([%a_][%a%d_]*)%s*%(", -- local function
}

-- أنماط المتغيرات المحلية
local localVariablePatterns = {
    "local%s+([%a_][%a%d_]*)",
    "local%s+([%a_][%a%d_]*%s*,%s*[%a_][%a%d_]*)",
}

-- أنماط النصوص
local stringPatterns = {
    {start = '"', finish = '"', multiline = false},
    {start = "'", finish = "'", multiline = false},
    {start = "%[%[", finish = "%]%]", multiline = true},
    {start = "`", finish = "`", multiline = false}, -- للـ Luau
}

-- أنماط التعليقات
local commentPatterns = {
    {pattern = "%-%-%[%[[^%]%]]+%]?%]?", type = "block"},
    {pattern = "%-%-[^\n]+", type = "line"},
    {pattern = "%-%-%s*@[%w_]+", type = "doc"}, -- التعليقات التوثيقية
    {pattern = "%-%-%s*TODO[^%n]*", type = "todo"},
    {pattern = "%-%-%s*FIXME[^%n]*", type = "todo"},
}

-- أنماط الأرقام
local numberPatterns = {
    "0x[%da-fA-F]+",                    -- Hex
    "[%d_]+%.?[%d_]*[eE]?[%d_]*",      -- Decimal
    "%.%d+[eE]?[%d_]*",                 -- Decimal (بداية بنقطة)
    "[%d_]+[eE][%d_]+",                 -- Scientific
}

-- أنماط المعاملات
local operatorPatterns = {
    -- المقارنة
    "==", "~=", "<=", ">=", "<", ">",
    -- الحسابية
    "%+", "%-", "%*", "/", "%%", "%^", "#",
    -- التعيين
    "=",
    -- الربط
    "%.%.%.", -- ...
    -- النطاق
    "%.%.",
    -- الفاصلة والنقطتان
    ":", ";", ",",
    -- الأقواس والأقواس المربعة
    "%(", "%)", "%[", "%]", "{", "}",
    -- آخر
    "%.", "::",
}

-- ============================================================
-- المتغيرات الداخلية
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
-- الدوال المساعدة
-- ============================================================

function isOffLimits(index)
    for _, v in next, offLimits do
        if index >= v[1] and index <= v[2] then
            return true
        end
    end
    return false
end

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
-- دوال التلوين الأساسية
-- ============================================================

-- تلوين التعليقات
function renderComments()
    local str = Highlight:getRaw()
    local step = 1
    
    for _, commentData in next, commentPatterns do
        for commentStart, commentEnd in gfind(str, commentData.pattern) do
            if step % 1000 == 0 then
                RunService.Heartbeat:Wait()
            end
            step = step + 1
            
            if not isOffLimits(commentStart) then
                local color = Colors.Comment
                if commentData.type == "doc" then
                    color = Colors.CommentDoc
                elseif commentData.type == "todo" then
                    color = Colors.CommentTodo
                end
                
                for i = commentStart, commentEnd do
                    if tableContents[i] then
                        tableContents[i].Color = color
                    end
                end
                table.insert(offLimits, {commentStart, commentEnd})
            end
        end
    end
end

-- تلوين النصوص
function renderStrings()
    local stringType = nil
    local stringStart = nil
    local offLimitsIndex = nil
    local skip = false
    
    for i, char in next, tableContents do
        if stringType then
            char.Color = Colors.String
            
            if char.Char == "\\" then
                -- تلوين أحرف الهروب بلون مختلف
                if tableContents[i + 1] then
                    tableContents[i + 1].Color = Colors.StringEscape
                end
            end
            
            local possibleString = ""
            for k = stringStart, i do
                possibleString = possibleString .. tableContents[k].Char
            end
            
            if char.Char:match(stringType.finish) and not (stringType.multiline) then
                skip = true
                stringType = nil
                offLimits[offLimitsIndex][2] = i
            end
        end
        
        if not skip then
            for _, strType in next, stringPatterns do
                if char.Char:match(strType.start) and not isOffLimits(i) then
                    stringType = strType
                    char.Color = Colors.String
                    stringStart = i
                    offLimitsIndex = #offLimits + 1
                    offLimits[offLimitsIndex] = {stringStart, math.huge}
                    
                    -- تلوين أحرف الهروب
                    if char.Char == "\\" and tableContents[i + 1] then
                        tableContents[i + 1].Color = Colors.StringEscape
                    end
                end
            end
        end
        skip = false
    end
end

-- تلوين الأنماط
function highlightPattern(patternArray, color, captureOnly)
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

-- تلوين الكلمات المفتاحية
function renderKeywords()
    local str = Highlight:getRaw()
    local step = 1
    
    for _, keyword in next, keywords do
        local pattern = "[^%w_](%s)" .. keyword .. "([^%w_])"
        for findStart, findEnd in gfind(str, pattern) do
            if step % 1000 == 0 then
                RunService.Heartbeat:Wait()
            end
            step = step + 1
            
            if not isOffLimits(findStart) and not isOffLimits(findEnd) then
                local start = findStart + 1
                local endPos = findEnd - 1
                local color = Colors.Keyword
                
                -- تحديد نوع الكلمة المفتاحية
                for _, cond in next, conditionalKeywords do
                    if keyword == cond then
                        color = Colors.KeywordCondition
                        break
                    end
                end
                for _, control in next, controlKeywords do
                    if keyword == control then
                        color = Colors.KeywordControl
                        break
                    end
                end
                if keyword == "local" then
                    color = Colors.Keyword
                end
                if keyword == "self" then
                    color = Colors.Self
                end
                if keyword == "nil" then
                    color = Colors.Nil
                end
                if keyword == "true" or keyword == "false" then
                    color = Colors.Boolean
                end
                if keyword == "and" or keyword == "or" or keyword == "not" then
                    color = Colors.Logic
                end
                
                for i = start, endPos do
                    if tableContents[i] then
                        tableContents[i].Color = color
                    end
                end
            end
        end
    end
end

-- تلوين المتغيرات المحلية
function renderLocalVariables()
    local str = Highlight:getRaw()
    local step = 1
    
    for _, pattern in next, localVariablePatterns do
        for findStart, findEnd in gfind(str, pattern) do
            if step % 1000 == 0 then
                RunService.Heartbeat:Wait()
            end
            step = step + 1
            
            if not isOffLimits(findStart) and not isOffLimits(findEnd) then
                for i = findStart, findEnd do
                    if tableContents[i] then
                        if tableContents[i].Char:match("[%a_]") then
                            tableContents[i].Color = Colors.LocalVariable
                        end
                    end
                end
            end
        end
    end
end

-- تلوين الأقواس والفواصل
function renderPunctuation()
    local step = 1
    
    for i, char in next, tableContents do
        if step % 1000 == 0 then
            RunService.Heartbeat:Wait()
        end
        step = step + 1
        
        if not isOffLimits(i) then
            local c = char.Char
            if c == "(" or c == ")" then
                char.Color = Colors.Parenthesis
            elseif c == "[" or c == "]" then
                char.Color = Colors.Bracket
            elseif c == "{" or c == "}" then
                char.Color = Colors.Brace
            elseif c == "," then
                char.Color = Colors.Comma
            elseif c == ";" then
                char.Color = Colors.Semicolon
            elseif c == ":" then
                char.Color = Colors.Colon
            elseif c == "." then
                char.Color = Colors.Dot
            end
        end
    end
end

-- تلوين المعاملات
function renderOperators()
    local str = Highlight:getRaw()
    local step = 1
    
    for _, op in next, operatorPatterns do
        local pattern = "[^%w_%p](" .. op .. ")[^%w_%p]"
        for findStart, findEnd in gfind(str, pattern) do
            if step % 1000 == 0 then
                RunService.Heartbeat:Wait()
            end
            step = step + 1
            
            if not isOffLimits(findStart) and not isOffLimits(findEnd) then
                local start = findStart + 1
                local endPos = findEnd - 1
                local color = Colors.Operator
                
                if op == "=" and not isOffLimits(start) then
                    -- التحقق إذا كان = للتعيين أم للمقارنة
                    local prevChar = tableContents[start - 2]
                    local nextChar = tableContents[endPos + 1]
                    if prevChar and (prevChar.Char == ">" or prevChar.Char == "<" or prevChar.Char == "~") then
                        color = Colors.Comparison
                    elseif nextChar and nextChar.Char == "=" then
                        color = Colors.Comparison
                    else
                        color = Colors.Assignment
                    end
                elseif op == "==" or op == "~=" or op == "<=" or op == ">=" or op == "<" or op == ">" then
                    color = Colors.Comparison
                elseif op == "and" or op == "or" or op == "not" then
                    color = Colors.Logic
                end
                
                for i = start, endPos do
                    if tableContents[i] then
                        tableContents[i].Color = color
                    end
                end
            end
        end
    end
end

-- ============================================================
-- الدوال الرئيسية
-- ============================================================

function render()
    offLimits = {}
    textFrame:ClearAllChildren()
    lineNumbersFrame:ClearAllChildren()
    
    -- تلوين التعليقات أولاً
    renderComments()
    
    -- تلوين النصوص
    renderStrings()
    
    -- تلوين الدوال
    highlightPattern(functionPatterns, Colors.Function)
    
    -- تلوين الكلمات المفتاحية
    renderKeywords()
    
    -- تلوين المتغيرات المحلية
    renderLocalVariables()
    
    -- تلوين الأرقام
    highlightPattern(numberPatterns, Colors.Number)
    
    -- تلوين المعاملات
    renderOperators()
    
    -- تلوين علامات الترقيم
    renderPunctuation()
    
    -- تلوين الكائنات (بعد الكلمات المفتاحية)
    highlightPattern({"[^%w_:]([%a_][%a%d_]*):", "^([%a_][%a%d_]*):"}, Colors.Object)
    
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
            
            -- حساب عرض السطر
            local x = TextService:GetTextSize(rawStr, textSize, font, Vector2.new(math.huge, math.huge)).X + 60
            if x > largestX then
                largestX = x
            end
            
            -- إنشاء نص السطر
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
            
            -- إنشاء رقم السطر
            if i ~= #tableContents + 1 then
                local lineNumber = Instance.new("TextLabel")
                lineNumber.Text = tostring(line)
                lineNumber.Font = font
                lineNumber.TextSize = textSize
                lineNumber.Size = UDim2.new(1, 0, 0, lineSpace)
                lineNumber.TextXAlignment = Enum.TextXAlignment.Right
                lineNumber.TextColor3 = Colors.LineNumber
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
                    lineStr = lineStr .. string.format('%s<font color="rgb(%d,%d,%d)">', 
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
    
    updateCanvasSize()
end

-- ============================================================
-- دوال الواجهة
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
-- الدوال العامة
-- ============================================================

function Highlight:init(frame)
    if typeof(frame) == "Instance" and frame:IsA("Frame") then
        frame:ClearAllChildren()
        
        parentFrame = frame
        scrollingFrame = Instance.new("ScrollingFrame")
        textFrame = Instance.new("Frame")
        lineNumbersFrame = Instance.new("Frame")
        
        local parentSize = frame.AbsoluteSize
        scrollingFrame.Size = UDim2.new(0, parentSize.X, 0, parentSize.Y)
        scrollingFrame.BackgroundColor3 = Colors.Background
        scrollingFrame.BorderSizePixel = 0
        scrollingFrame.ScrollBarThickness = 4
        scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
        
        textFrame.Size = UDim2.new(1, -45, 1, 0)
        textFrame.Position = UDim2.new(0, 45, 0, 0)
        textFrame.BackgroundTransparency = 1
        
        lineNumbersFrame.Size = UDim2.new(0, 30, 1, 0)
        lineNumbersFrame.BackgroundTransparency = 1
        lineNumbersFrame.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
        
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
    local line = 1
    
    for i = 1, #raw do
        local char = raw:sub(i, i)
        table.insert(tableContents, {
            Char = char,
            Color = Color3.fromRGB(220, 220, 255), -- اللون الافتراضي
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
