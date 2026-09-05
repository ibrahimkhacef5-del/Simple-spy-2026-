--[[
    highlight.lua v2.0 - Syntax Highlighter متطور جداً
    - يدعم أكثر من 16 مليون لون
    - كل نوع له وظيفة تلوين مخصصة
    - تلوين ذكي حسب السياق
]]

local cloneref = cloneref or function(...) return ... end
local TextService = cloneref(game:GetService("TextService"))
local RunService = cloneref(game:GetService("RunService"))

--- @class Highlight
local Highlight = {}

-- ============================================================
-- نظام الألوان المتقدم (16 مليون لون +)
-- ============================================================

local ColorSystem = {
    -- الألوان الأساسية (مع إمكانية التعديل الديناميكي)
    base = {
        background = Color3.fromRGB(28, 30, 38),
        lineNumber = Color3.fromRGB(80, 85, 100),
    },
    
    -- وظائف توليد الألوان الديناميكية
    generators = {
        -- لون يعتمد على قيمة الهاش
        hash = function(str)
            local hash = 0
            for i = 1, #str do
                hash = (hash * 31 + string.byte(str, i)) % 16777216
            end
            return Color3.fromRGB(
                (hash // 65536) % 256,
                (hash // 256) % 256,
                hash % 256
            )
        end,
        
        -- لون متدرج حسب الموضع
        gradient = function(index, total, saturation, brightness)
            saturation = saturation or 1
            brightness = brightness or 1
            local hue = (index / total) % 1
            return Color3.fromHSV(hue, saturation, brightness)
        end,
        
        -- لون عشوائي ولكن ثابت (يعتمد على الاسم)
        stable = function(name)
            local seed = 0
            for i = 1, #name do
                seed = seed + string.byte(name, i)
            end
            local r = (seed * 123) % 256
            local g = (seed * 456) % 256
            local b = (seed * 789) % 256
            return Color3.fromRGB(r, g, b)
        end,
        
        -- لون نيون مع توهج
        neon = function(hue)
            local color = Color3.fromHSV(hue % 1, 1, 1)
            return Color3.new(
                math.min(color.R * 1.5, 1),
                math.min(color.G * 1.5, 1),
                math.min(color.B * 1.5, 1)
            )
        end,
        
        -- لون باستيل (ناعم)
        pastel = function(hue)
            local color = Color3.fromHSV(hue % 1, 0.4, 0.9)
            return color
        end,
        
        -- لون داكن (غامق)
        dark = function(hue)
            local color = Color3.fromHSV(hue % 1, 0.8, 0.3)
            return color
        end,
    },
    
    -- أنماط التلوين المخصصة لكل نوع
    patterns = {
        keywords = {
            type = "hash",
            colors = {},
            function(color)
                return color
            end
        },
        functions = {
            type = "gradient",
            colors = {},
            function(color, index, total)
                return ColorSystem.generators.gradient(index, total, 0.8, 1)
            end
        },
        strings = {
            type = "stable",
            colors = {},
            function(color, text)
                return ColorSystem.generators.stable(text)
            end
        },
        numbers = {
            type = "pastel",
            colors = {},
            function(color, num)
                return ColorSystem.generators.pastel((tonumber(num) or 0) / 100)
            end
        },
        comments = {
            type = "dark",
            colors = {},
            function(color, text)
                local hue = (#text % 10) / 10
                return ColorSystem.generators.dark(hue)
            end
        },
        operators = {
            type = "neon",
            colors = {},
            function(color, op)
                local hues = {
                    ["+"] = 0.05, ["-"] = 0.1, ["*"] = 0.15, ["/"] = 0.2,
                    ["="] = 0.25, ["=="] = 0.3, ["~="] = 0.35,
                    ["<"] = 0.4, [">"] = 0.45, ["<="] = 0.5, [">="] = 0.55,
                    ["and"] = 0.6, ["or"] = 0.65, ["not"] = 0.7,
                    ["."] = 0.75, [":"] = 0.8, [","] = 0.85,
                }
                return ColorSystem.generators.neon(hues[op] or 0.5)
            end
        },
        variables = {
            type = "stable",
            colors = {},
            function(color, name)
                return ColorSystem.generators.stable(name)
            end
        },
        booleans = {
            type = "hash",
            colors = {},
            function(color, bool)
                return bool == "true" and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
            end
        },
        instances = {
            type = "stable",
            colors = {},
            function(color, name)
                return ColorSystem.generators.stable(name .. "Instance")
            end
        },
        tables = {
            type = "gradient",
            colors = {},
            function(color, index, total)
                return ColorSystem.generators.gradient(index, total, 0.6, 0.8)
            end
        },
        special = {
            type = "neon",
            colors = {},
            function(color, text)
                local specials = {
                    ["self"] = 0.9,
                    ["nil"] = 0.95,
                    ["..."] = 0.85,
                    ["_G"] = 0.75,
                }
                return ColorSystem.generators.neon(specials[text] or 0.5)
            end
        }
    }
}

-- ============================================================
-- إعدادات التلوين
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
-- دوال التلوين الذكية
-- ============================================================

local function getColorForKeyword(keyword)
    local keywords = {
        ["function"] = 0.0, ["local"] = 0.05, ["if"] = 0.1, ["then"] = 0.15,
        ["else"] = 0.2, ["elseif"] = 0.25, ["end"] = 0.3, ["for"] = 0.35,
        ["while"] = 0.4, ["do"] = 0.45, ["repeat"] = 0.5, ["until"] = 0.55,
        ["return"] = 0.6, ["break"] = 0.65, ["continue"] = 0.7, ["goto"] = 0.75,
        ["and"] = 0.8, ["or"] = 0.85, ["not"] = 0.9,
    }
    local hue = keywords[keyword] or 0.5
    return ColorSystem.generators.neon(hue)
end

local function getColorForString(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 16777216
    end
    local r = (hash // 65536) % 256
    local g = (hash // 256) % 256
    local b = hash % 256
    -- تجعل الألوان أكثر إشراقاً للنصوص
    return Color3.fromRGB(
        math.min(r + 50, 255),
        math.min(g + 50, 255),
        math.min(b + 50, 255)
    )
end

local function getColorForNumber(num)
    local val = tonumber(num) or 0
    local hue = (math.abs(val) % 1) * 0.8 + 0.1
    return ColorSystem.generators.pastel(hue)
end

local function getColorForOperator(op)
    local hues = {
        ["+"] = 0.0, ["-"] = 0.05, ["*"] = 0.1, ["/"] = 0.15,
        ["="] = 0.2, ["=="] = 0.25, ["~="] = 0.3,
        ["<"] = 0.35, [">"] = 0.4, ["<="] = 0.45, [">="] = 0.5,
        ["and"] = 0.55, ["or"] = 0.6, ["not"] = 0.65,
        ["."] = 0.7, [":"] = 0.75, [","] = 0.8,
        ["("] = 0.85, [")"] = 0.9, ["["] = 0.92, ["]"] = 0.94,
        ["{"] = 0.96, ["}"] = 0.98,
    }
    return ColorSystem.generators.neon(hues[op] or 0.5)
end

-- ============================================================
-- دوال التعرف على الأنماط
-- ============================================================

local patterns = {
    -- الكلمات المفتاحية
    keywords = {
        "function", "local", "if", "then", "else", "elseif", "end",
        "for", "while", "do", "repeat", "until",
        "return", "break", "continue", "goto",
        "and", "or", "not",
    },
    -- الكلمات الخاصة
    special = {"self", "nil", "...", "_G", "_ENV"},
    -- المعاملات
    operators = {"+", "-", "*", "/", "=", "==", "~=", "<", ">", "<=", ">=", ".", ":", ",", "(", ")", "[", "]", "{", "}"},
}

-- ============================================================
-- دوال التلوين الأساسية
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
-- تلوين متقدم لكل نوع
-- ============================================================

function renderAdvanced()
    offLimits = {}
    textFrame:ClearAllChildren()
    lineNumbersFrame:ClearAllChildren()
    
    local str = Highlight:getRaw()
    
    -- تلوين التعليقات أولاً
    for commentStart, commentEnd in gfind(str, "%-%-[^\n]+") do
        if not isOffLimits(commentStart) then
            local color = getColorForString(str:sub(commentStart, commentEnd))
            for i = commentStart, commentEnd do
                if tableContents[i] then
                    tableContents[i].Color = color
                    tableContents[i].Color = Color3.new(
                        color.R * 0.5,
                        color.G * 0.5,
                        color.B * 0.5
                    )
                end
            end
            table.insert(offLimits, {commentStart, commentEnd})
        end
    end
    
    -- تلوين النصوص
    local inString = false
    local stringStart = 0
    local stringChar = ""
    
    for i, char in next, tableContents do
        if not inString and (char.Char == '"' or char.Char == "'") and not isOffLimits(i) then
            inString = true
            stringStart = i
            stringChar = char.Char
            char.Color = getColorForString("string")
        elseif inString and char.Char == stringChar and not isOffLimits(i) then
            inString = false
            char.Color = getColorForString("string")
            table.insert(offLimits, {stringStart, i})
        elseif inString then
            char.Color = getColorForString("string")
        end
    end
    
    -- تلوين الكلمات المفتاحية
    for _, keyword in next, patterns.keywords do
        for findStart, findEnd in gfind(str, "[^%w_](" .. keyword .. ")[^%w_]") do
            if not isOffLimits(findStart) and not isOffLimits(findEnd) then
                local start = findStart + 1
                local endPos = findEnd - 1
                local color = getColorForKeyword(keyword)
                for i = start, endPos do
                    if tableContents[i] then
                        tableContents[i].Color = color
                    end
                end
            end
        end
    end
    
    -- تلوين الكلمات الخاصة
    for _, word in next, patterns.special do
        for findStart, findEnd in gfind(str, "[^%w_](" .. word .. ")[^%w_]") do
            if not isOffLimits(findStart) and not isOffLimits(findEnd) then
                local start = findStart + 1
                local endPos = findEnd - 1
                local color = getColorForKeyword(word)
                for i = start, endPos do
                    if tableContents[i] then
                        tableContents[i].Color = color
                    end
                end
            end
        end
    end
    
    -- تلوين الأرقام
    for findStart, findEnd in gfind(str, "[%d]+%.?[%d]*") do
        if not isOffLimits(findStart) and not isOffLimits(findEnd) then
            local num = str:sub(findStart, findEnd)
            local color = getColorForNumber(num)
            for i = findStart, findEnd do
                if tableContents[i] then
                    tableContents[i].Color = color
                end
            end
        end
    end
    
    -- تلوين المعاملات
    for _, op in next, patterns.operators do
        local pattern = "[^%w_%p](" .. op .. ")[^%w_%p]"
        for findStart, findEnd in gfind(str, pattern) do
            if not isOffLimits(findStart) and not isOffLimits(findEnd) then
                local start = findStart + 1
                local endPos = findEnd - 1
                local color = getColorForOperator(op)
                for i = start, endPos do
                    if tableContents[i] then
                        tableContents[i].Color = color
                    end
                end
            end
        end
    end
    
    -- تلوين الدوال
    for findStart, findEnd in gfind(str, "[%a_][%a%d_]*%s*%(") do
        if not isOffLimits(findStart) and not isOffLimits(findEnd) then
            local funcName = str:sub(findStart, findEnd - 1)
            local color = getColorForKeyword(funcName)
            for i = findStart, findEnd - 1 do
                if tableContents[i] then
                    tableContents[i].Color = color
                end
            end
        end
    end
    
    -- عرض النص الملون
    renderDisplay()
end

-- ============================================================
-- عرض النص الملون
-- ============================================================

function renderDisplay()
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
                lineNumber.TextColor3 = ColorSystem.base.lineNumber
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
        
        scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
        scrollingFrame.BackgroundColor3 = ColorSystem.base.background
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
        
        renderAdvanced()
        
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
            Color = Color3.fromRGB(220, 220, 255),
        })
        if i % 1000 == 0 then
            RunService.Heartbeat:Wait()
        end
    end
    renderAdvanced()
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

return constructor    String = Color3.fromRGB(152, 195, 121),       -- أخضر
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
