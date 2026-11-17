--[[
    Highlight.lua - Pro Syntax Highlighter
    Rich colors • Fast • Clean
]]

local cloneref = cloneref or function(...) return ... end
local TextService = cloneref(game:GetService("TextService"))
local RunService = cloneref(game:GetService("RunService"))

local Highlight = {}

-- ============================================================
-- State
-- ============================================================
local parentFrame, scrollingFrame, textFrame, lineNumbersFrame
local tableContents = {}
local line, largestX = 0, 0
local lineSpace, font, textSize = 15, Enum.Font.Code, 13
local offLimits = {}

-- ============================================================
-- Colors — One Dark Pro + Catppuccin inspired
-- ============================================================
local C = {
    bg              = Color3.fromRGB(18, 18, 24),
    lineNum         = Color3.fromRGB(68, 72, 88),

    -- Keywords
    kw              = Color3.fromRGB(198, 120, 221),  -- purple
    kwControl       = Color3.fromRGB(224, 108, 117),  -- red (return/break)
    kwCondition     = Color3.fromRGB(229, 192, 123),  -- gold (then/else)
    kwLoop          = Color3.fromRGB(86, 182, 194),   -- cyan (for/while)
    kwLocal         = Color3.fromRGB(198, 120, 221),
    kwFunction      = Color3.fromRGB(97, 175, 239),

    -- Functions
    funcDef         = Color3.fromRGB(97, 175, 239),   -- blue
    funcCall        = Color3.fromRGB(97, 175, 239),
    method          = Color3.fromRGB(86, 182, 194),   -- cyan methods

    -- Strings
    str             = Color3.fromRGB(152, 195, 121),  -- green
    strEscape       = Color3.fromRGB(209, 154, 102),  -- orange
    strInterp       = Color3.fromRGB(229, 192, 123),  -- gold

    -- Numbers
    num             = Color3.fromRGB(209, 154, 102),
    numHex          = Color3.fromRGB(224, 175, 104),
    numFloat        = Color3.fromRGB(209, 154, 102),

    -- Comments
    comment         = Color3.fromRGB(92, 99, 112),
    commentDoc      = Color3.fromRGB(110, 125, 150),
    commentTodo     = Color3.fromRGB(229, 192, 123),
    commentWarn     = Color3.fromRGB(224, 108, 117),

    -- Operators
    op              = Color3.fromRGB(86, 182, 194),
    opAssign        = Color3.fromRGB(198, 120, 221),
    opCompare       = Color3.fromRGB(86, 182, 194),
    opLogic         = Color3.fromRGB(198, 120, 221),
    opArith         = Color3.fromRGB(171, 178, 191),

    -- Literals
    bool            = Color3.fromRGB(209, 154, 102),
    nil_            = Color3.fromRGB(190, 80, 70),
    self_           = Color3.fromRGB(224, 108, 117),

    -- Types / Builtins
    builtin         = Color3.fromRGB(229, 192, 123),  -- gold
    type_           = Color3.fromRGB(86, 182, 194),
    constant        = Color3.fromRGB(209, 154, 102),

    -- Roblox specific
    rbxService      = Color3.fromRGB(97, 175, 239),
    rbxEnum         = Color3.fromRGB(198, 120, 221),
    rbxInstance     = Color3.fromRGB(86, 182, 194),
    rbxEvent        = Color3.fromRGB(224, 108, 117),
    rbxProp         = Color3.fromRGB(171, 178, 191),

    -- Variables
    var             = Color3.fromRGB(171, 178, 191),
    varLocal        = Color3.fromRGB(171, 178, 191),
    varGlobal       = Color3.fromRGB(224, 175, 104),
    varArg          = Color3.fromRGB(152, 195, 121),

    -- Punctuation
    paren           = Color3.fromRGB(171, 178, 191),
    bracket         = Color3.fromRGB(171, 178, 191),
    brace           = Color3.fromRGB(171, 178, 191),
    comma           = Color3.fromRGB(140, 145, 160),
    dot             = Color3.fromRGB(140, 145, 160),
    colon           = Color3.fromRGB(140, 145, 160),
    semicolon       = Color3.fromRGB(140, 145, 160),

    -- Special
    annotation      = Color3.fromRGB(198, 120, 221),
    label           = Color3.fromRGB(229, 192, 123),
    attribute       = Color3.fromRGB(86, 182, 194),

    default         = Color3.fromRGB(171, 178, 191),
}

-- ============================================================
-- Helpers
-- ============================================================
local function gfind(str, pattern)
    return coroutine.wrap(function()
        local start = 0
        while true do
            local s, e = str:find(pattern, start)
            if s and e ~= #str then
                start = e + 1
                coroutine.yield(s, e)
            else
                return
            end
        end
    end)
end

local function isOff(i)
    for _, v in next, offLimits do
        if i >= v[1] and i <= v[2] then return true end
    end
    return false
end

local function esc(s)
    local m = {["<"]="&lt;",[">"]="&gt;",['"']="&quot;",["'"]="&apos;",["&"]="&amp;"}
    local r = ""
    for i = 1, #s do
        local c = s:sub(i,i)
        r = r .. (m[c] or c)
    end
    return r
end

local function setColor(from, to, color)
    for i = from, to do
        if tableContents[i] then
            tableContents[i].Color = color
        end
    end
end

local function markOff(from, to)
    table.insert(offLimits, {from, to})
end

-- ============================================================
-- Pattern highlight
-- ============================================================
local function hl(patterns, color, capture)
    local str = Highlight:getRaw()
    local step = 1
    for _, pat in next, patterns do
        for s, e in gfind(str, pat) do
            step += 1
            if step % 800 == 0 then RunService.Heartbeat:Wait() end
            if not isOff(s) and not isOff(e) then
                local a, b = s, e
                if capture then
                    a = s + 1
                    b = e - 1
                end
                setColor(a, b, color)
            end
        end
    end
end

-- ============================================================
-- Comments
-- ============================================================
local function renderComments()
    local str = Highlight:getRaw()
    local step = 1

    -- single line
    for s, e in gfind(str, "%-%-[^\n]*") do
        step += 1
        if step % 800 == 0 then RunService.Heartbeat:Wait() end
        if not isOff(s) then
            local txt = str:sub(s, e)
            local col = C.comment
            if txt:match("[Tt][Oo][Dd][Oo]") or txt:match("[Ff][Ii][Xx][Mm][Ee]") then
                col = C.commentTodo
            elseif txt:match("[Ww][Aa][Rr][Nn]") or txt:match("[Hh][Aa][Cc][Kk]") then
                col = C.commentWarn
            elseif txt:match("%-%-%-") or txt:match("@param") or txt:match("@return") then
                col = C.commentDoc
            end
            setColor(s, e, col)
            markOff(s, e)
        end
    end

    -- block
    for s, e in gfind(str, "%-%-%[%[.-%]%]") do
        step += 1
        if step % 800 == 0 then RunService.Heartbeat:Wait() end
        if not isOff(s) then
            setColor(s, e, C.comment)
            markOff(s, e)
        end
    end
end

-- ============================================================
-- Strings
-- ============================================================
local function renderStrings()
    local inStr, start, ch = false, 0, ""
    for i, c in next, tableContents do
        if not inStr and (c.Char == '"' or c.Char == "'") and not isOff(i) then
            inStr, start, ch = true, i, c.Char
            c.Color = C.str
        elseif inStr and c.Char == ch and not isOff(i) then
            inStr = false
            c.Color = C.str
            markOff(start, i)
        elseif inStr then
            c.Color = C.str
            if c.Char == "\\" and tableContents[i+1] then
                tableContents[i+1].Color = C.strEscape
            end
        end
    end

    -- long strings [[ ]]
    local str = Highlight:getRaw()
    for s, e in gfind(str, "%[%[.-%]%]") do
        if not isOff(s) then
            setColor(s, e, C.str)
            markOff(s, e)
        end
    end
end

-- ============================================================
-- Main render
-- ============================================================
function render()
    offLimits = {}
    textFrame:ClearAllChildren()
    lineNumbersFrame:ClearAllChildren()

    local raw = Highlight:getRaw()

    -- ========== KEYWORDS ==========
    local kwMap = {
        -- control
        ["return"] = C.kwControl, ["break"] = C.kwControl,
        ["continue"] = C.kwControl, ["goto"] = C.kwControl,
        -- condition
        ["if"] = C.kwCondition, ["then"] = C.kwCondition,
        ["else"] = C.kwCondition, ["elseif"] = C.kwCondition,
        ["until"] = C.kwCondition,
        -- loop
        ["for"] = C.kwLoop, ["while"] = C.kwLoop,
        ["repeat"] = C.kwLoop, ["do"] = C.kwLoop,
        -- structure
        ["function"] = C.kwFunction, ["local"] = C.kwLocal,
        ["end"] = C.kw, ["and"] = C.opLogic, ["or"] = C.opLogic,
        ["not"] = C.opLogic, ["in"] = C.kw,
    }

    for word, col in next, kwMap do
        for s, e in gfind(raw, "[^%w_](" .. word .. ")[^%w_]") do
            if not isOff(s) and not isOff(e) then
                setColor(s+1, e-1, col)
            end
        end
        -- start of line
        for s, e in gfind(raw, "^(" .. word .. ")[^%w_]") do
            if not isOff(s) then setColor(s, e-1, col) end
        end
    end

    -- ========== SELF ==========
    hl({"[^%w_](self)[^%w_]", "^(self)[^%w_]"}, C.self_, true)

    -- ========== BOOLEANS / NIL ==========
    hl({"[^%w_](true)[^%w_]", "^(true)[^%w_]",
        "[^%w_](false)[^%w_]", "^(false)[^%w_]"}, C.bool, true)
    hl({"[^%w_](nil)[^%w_]", "^(nil)[^%w_]"}, C.nil_, true)

    -- ========== BUILTINS ==========
    local builtins = {
        "print","warn","error","assert","type","typeof","tostring","tonumber",
        "pairs","ipairs","next","select","unpack","rawget","rawset","rawequal",
        "setmetatable","getmetatable","newproxy","pcall","xpcall","ypcall",
        "spawn","delay","wait","tick","time","typeof","require","loadstring",
        "getfenv","setfenv","getinfo","traceback","collectgarbage",
        "Instance","Vector3","Vector2","CFrame","Color3","UDim2","UDim",
        "Ray","Region3","BrickColor","TweenInfo","NumberRange","NumberSequence",
        "ColorSequence","Rect","Enum","game","workspace","script","shared",
        "plugin","_G","_VERSION"
    }
    for _, b in next, builtins do
        for s, e in gfind(raw, "[^%w_](" .. b .. ")[^%w_]") do
            if not isOff(s) then setColor(s+1, e-1, C.builtin) end
        end
    end

    -- ========== ROBLOX SERVICES ==========
    local services = {
        "Players","RunService","UserInputService","TweenService","HttpService",
        "ReplicatedStorage","ServerStorage","ServerScriptService","StarterGui",
        "StarterPlayer","Lighting","SoundService","MarketplaceService",
        "TeleportService","DataStoreService","MessagingService","PathfindingService",
        "CollectionService","ContextActionService","GuiService","TextService",
        "ContentProvider","InsertService","Chat","Teams","BadgeService"
    }
    for _, s in next, services do
        for a, b in gfind(raw, "[^%w_](" .. s .. ")[^%w_]") do
            if not isOff(a) then setColor(a+1, b-1, C.rbxService) end
        end
    end

    -- ========== ENUMS ==========
    hl({"Enum%.[%w_]+%.[%w_]+", "Enum%.[%w_]+"}, C.rbxEnum)

    -- ========== FUNCTIONS calls ==========
    hl({
        "[^%w_]([%a_][%w_]*)%s*%(",
        "^([%a_][%w_]*)%s*%(",
    }, C.funcCall, true)

    -- Methods  :name(
    hl({":([%a_][%w_]*)%s*%("}, C.method, true)

    -- ========== NUMBERS ==========
    hl({
        "[^%w_](0x[%da-fA-F]+)",
        "[^%w_](%d+%.%d+[eE]?[+-]?%d*)",
        "[^%w_](%.%d+[eE]?[+-]?%d*)",
        "[^%w_](%d+[eE][+-]?%d*)",
        "[^%w_](%d+)",
        "^(0x[%da-fA-F]+)",
        "^(%d+%.%d+[eE]?[+-]?%d*)",
        "^(%d+)",
    }, C.num, true)

    -- ========== OPERATORS ==========
    -- assign
    hl({"[=]","%+=","%-=","%*=","%/=","%%="}, C.opAssign)
    -- compare
    hl({"==","~=","<=",">=","<",">"}, C.opCompare)
    -- arithmetic
    hl({"%+","%-","%*","/","%%","%^","%.%."}, C.opArith)
    -- other
    hl({"%.%.%.","#","%.%.",}, C.op)

    -- ========== PUNCTUATION ==========
    for i, c in next, tableContents do
        if not isOff(i) then
            local ch = c.Char
            if ch == "(" or ch == ")" then c.Color = C.paren
            elseif ch == "[" or ch == "]" then c.Color = C.bracket
            elseif ch == "{" or ch == "}" then c.Color = C.brace
            elseif ch == "," then c.Color = C.comma
            elseif ch == "." then c.Color = C.dot
            elseif ch == ":" then c.Color = C.colon
            elseif ch == ";" then c.Color = C.semicolon
            end
        end
    end

    -- ========== COMMENTS & STRINGS (last so they override) ==========
    renderComments()
    renderStrings()

    -- ========== DRAW ==========
    local lastCol, lineStr, rawStr = nil, "", ""
    largestX, line = 0, 1

    for i = 1, #tableContents + 1 do
        local c = tableContents[i]

        if i == #tableContents + 1 or (c and c.Char == "\n") then
            lineStr ..= (lastCol and "</font>" or "")

            local x = TextService:GetTextSize(rawStr, textSize, font, Vector2.new(math.huge, math.huge)).X + 55
            if x > largestX then largestX = x end

            local lbl = Instance.new("TextLabel")
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextYAlignment = Enum.TextYAlignment.Top
            lbl.Position = UDim2.new(0, 0, 0, line * lineSpace - lineSpace/2)
            lbl.Size = UDim2.new(0, x, 0, textSize)
            lbl.RichText = true
            lbl.Font = font
            lbl.TextSize = textSize
            lbl.BackgroundTransparency = 1
            lbl.Text = lineStr
            lbl.Parent = textFrame

            if i ~= #tableContents + 1 then
                local num = Instance.new("TextLabel")
                num.Text = tostring(line)
                num.Font = font
                num.TextSize = textSize
                num.Size = UDim2.new(1, 0, 0, lineSpace)
                num.TextXAlignment = Enum.TextXAlignment.Right
                num.TextColor3 = C.lineNum
                num.Position = UDim2.new(0, 0, 0, line * lineSpace - lineSpace/2)
                num.BackgroundTransparency = 1
                num.Parent = lineNumbersFrame
            end

            lineStr, rawStr, lastCol = "", "", nil
            line += 1
            if line % 6 == 0 then RunService.Heartbeat:Wait() end
        elseif c then
            if c.Char == " " then
                lineStr ..= " "
                rawStr ..= " "
            elseif c.Char == "\t" then
                lineStr ..= "    "
                rawStr ..= "\t"
            else
                if c.Color == lastCol then
                    lineStr ..= esc(c.Char)
                else
                    lineStr ..= string.format(
                        '%s<font color="rgb(%d,%d,%d)">%s',
                        lastCol and "</font>" or "",
                        math.floor(c.Color.R*255),
                        math.floor(c.Color.G*255),
                        math.floor(c.Color.B*255),
                        esc(c.Char)
                    )
                    lastCol = c.Color
                end
                rawStr ..= c.Char
            end
        end
    end

    updateZIndex()
    updateCanvasSize()
end

-- ============================================================
-- UI helpers
-- ============================================================
function updateCanvasSize()
    scrollingFrame.CanvasSize = UDim2.new(0, largestX + 20, 0, line * lineSpace + 20)
end

function onFrameSizeChange()
    scrollingFrame.Size = UDim2.new(0, parentFrame.AbsoluteSize.X, 0, parentFrame.AbsoluteSize.Y)
end

function updateZIndex()
    for _, v in next, parentFrame:GetDescendants() do
        if v:IsA("GuiObject") then v.ZIndex = parentFrame.ZIndex end
    end
end

-- ============================================================
-- Public API
-- ============================================================
function Highlight:init(frame)
    if typeof(frame) ~= "Instance" or not frame:IsA("Frame") then
        error("Highlight:init expects a Frame")
    end
    frame:ClearAllChildren()
    parentFrame = frame

    scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Size = UDim2.new(1,0,1,0)
    scrollingFrame.BackgroundColor3 = C.bg
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.ScrollBarThickness = 4
    scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(55,60,75)
    scrollingFrame.Parent = parentFrame

    textFrame = Instance.new("Frame")
    textFrame.Size = UDim2.new(1, -42, 1, 0)
    textFrame.Position = UDim2.new(0, 42, 0, 0)
    textFrame.BackgroundTransparency = 1
    textFrame.Parent = scrollingFrame

    lineNumbersFrame = Instance.new("Frame")
    lineNumbersFrame.Size = UDim2.new(0, 34, 1, 0)
    lineNumbersFrame.BackgroundTransparency = 1
    lineNumbersFrame.Parent = scrollingFrame

    render()
    parentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(onFrameSizeChange)
    parentFrame:GetPropertyChangedSignal("ZIndex"):Connect(updateZIndex)
end

function Highlight:setRaw(raw)
    raw = (raw or "") .. "\n"
    tableContents = {}
    for i = 1, #raw do
        tableContents[i] = { Char = raw:sub(i,i), Color = C.default }
        if i % 1200 == 0 then RunService.Heartbeat:Wait() end
    end
    render()
end

function Highlight:getRaw()
    local r = ""
    for _, c in next, tableContents do r ..= c.Char end
    return r
end

function Highlight:getString()
    return Highlight:getRaw()
end

function Highlight:getTable() return tableContents end
function Highlight:getSize() return #tableContents end

function Highlight:getLine(n)
    local cur, res = 0, ""
    for _, v in next, tableContents do
        if v.Char == "\n" then cur += 1 end
        if cur == n and v.Char ~= "\n" then res ..= v.Char end
        if cur > n then break end
    end
    return res
end

function Highlight:setLine(n, text)
    local cur, startP, endP = 0, 0, 0
    for i, v in next, tableContents do
        if v.Char == "\n" then
            cur += 1
            if cur == n then startP = i + 1
            elseif cur == n + 1 then endP = i break end
        end
    end
    if startP > 0 and endP > 0 then
        local s = Highlight:getRaw()
        Highlight:setRaw(s:sub(1, startP-1) .. text .. "\n" .. s:sub(endP))
    end
end

function Highlight:insertLine(n, text)
    local cur, pos = 0, 0
    for i, v in next, tableContents do
        if v.Char == "\n" then
            cur += 1
            if cur == n then pos = i break end
        end
    end
    if pos > 0 then
        local s = Highlight:getRaw()
        Highlight:setRaw(s:sub(1, pos) .. text .. "\n" .. s:sub(pos+1))
    end
end

-- Constructor
local ctor = {}
function ctor.new(...)
    local o = setmetatable({}, {__index = Highlight})
    o:init(...)
    return o
end

return ctor
