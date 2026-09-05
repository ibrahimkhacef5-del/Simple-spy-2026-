codebox = Highlight.new(CodeBox)

-- ============================================================
-- إضافة اسم ملون بتأثير RGB متحرك مع رابط قابل للضغط
-- ============================================================
logthread(spawn(function()
    local suc, err = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/ibrahimkhacef5-del/Simple-spy-2026-/refs/heads/main/Name.txt")
    
    -- النص الأساسي
    local text = (suc and err) or "Welcome to Simple Spy!"
    
    -- ============================================================
    -- إنشاء تأثير RGB متحرك على الاسم
    -- ============================================================
    local function generateRainbowText(name)
        local chars = {}
        local colorStep = 0
        local step = 0.05 -- سرعة تغير الألوان
        
        for i = 1, #name do
            local char = name:sub(i, i)
            -- حساب اللون بناءً على position
            local hue = (i / #name + colorStep) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            table.insert(chars, string.format(
                '<font color="rgb(%d, %d, %d)">%s</font>',
                color.R * 255,
                color.G * 255,
                color.B * 255,
                char
            ))
        end
        
        return table.concat(chars)
    end
    
    -- ============================================================
    -- إنشاء رابط قابل للضغط (Hyperlink)
    -- ============================================================
    local function createClickableLink(text, url)
        return string.format(
            '<a href="%s">%s</a>',
            url,
            text
        )
    end
    
    -- ============================================================
    -- تجميع النص النهائي مع RGB وروابط
    -- ============================================================
    local finalText = [[
-- ========================================
-- ]] .. generateRainbowText("✦ Simple Spy V12 ✦") .. [[
-- ========================================
    
]] .. text .. [[

-- ========================================
-- ]] .. createClickableLink("📱 Instagram: @uzcawe", "https://www.instagram.com/uzcawe") .. [[
-- ]] .. createClickableLink("📢 Discord: Join Server", "https://discord.gg/AWS6ez9") .. [[
-- ]] .. createClickableLink("📂 GitHub: Source Code", "https://github.com/ibrahimkhacef5-del/Simple-spy-2026-") .. [[
-- ========================================

-- 🎨 Simple Spy with RGB Colors & Clickable Links
-- 🔗 Click on links above to open in browser
]]
    
    codebox:setRaw(finalText)
end))

getgenv().SimpleSpy = SimpleSpy
getgenv().getNil = function(name, class)
    for _, v in next, getnilinstances() do
        if v.ClassName == class and v.Name == name then
            return v
        end
    end
end
