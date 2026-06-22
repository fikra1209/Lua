--[[
    Summon Heroes Automation Bot — Premium Edition
    Developed by Antigravity AI

    Features:
    - Self-Healing Library Loader (multi CDN mirror fallback)
    - Draggable Floating "SH" Toggle Button
    - Auto Wave Ready        (toggle mandiri)
    - Auto Collect Chests    (toggle mandiri)
    - Auto Putar Ulang Tahap (toggle mandiri)
    - Auto Tahap Selanjutnya (toggle mandiri)
    - Auto Kembali ke Lobi   (toggle mandiri)
    - Auto Summon / Auto Sell / Auto Fuse
    - Anti-AFK + Auto Rejoin
    - Lobby Persistence: CharacterAdded + TeleportService + Watchdog rebind
    - SaveManager + InterfaceManager Fluent integration
]]

-- GUI will now show up in the lobby, but automation features will remain off by default.
local ws = game:GetService("Workspace")

if game.GameId ~= 9802644580 then
    return
end

-- ─── Initialization ──────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local VirtualUser       = game:GetService("VirtualUser")

local player = Players.LocalPlayer
while not player do
    task.wait(0.1)
    player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui", 30)
if not playerGui then return end


local function debugPrint(msg)
    local text = "[Summon Heroes Bot] " .. tostring(msg)
    print(text); warn(text)
    pcall(function() if rconsoleprint then rconsoleprint(text.."\n") end end)
end

debugPrint("Initializing script...")

-- Automatic workspace diagnostics disabled to prevent loading crash

-- ─── Self-Healing HttpGet Library Loader ─────────────────────────────────────
local function httpGet(url)
    local requestFunc = (syn and syn.request) or (http and http.request) or request or http_request
    if requestFunc then
        local ok, res = pcall(function()
            return requestFunc({ Url=url, Method="GET", Timeout=5, timeout=5 })
        end)
        if ok and res then
            if type(res)=="table" and res.StatusCode==200 and res.Body then return res.Body end
            if type(res)=="string" then return res end
        end
    end
    local ok2, r2 = pcall(game.HttpGet, game, url)
    return ok2 and r2 or nil
end

local function safeHttpGet(url)
    local ok, res = pcall(httpGet, url)
    if ok and res and res~="" and not res:find("404") and not res:find("<html") and not res:find("<!DOCTYPE") then
        return res
    end
    return nil
end

local function loadLibrary(fileName, urls)
    local localOk, localContent = pcall(function()
        if readfile then return readfile(fileName) end
    end)
    if localOk and localContent and localContent~="" then
        local fn, err = loadstring(localContent)
        if fn then
            debugPrint("Loaded "..fileName.." from local cache.")
            return localContent, fn
        else
            debugPrint("Cache corrupted: "..tostring(err)..". Re-downloading...")
            pcall(function() if delfile then delfile(fileName) elseif writefile then writefile(fileName,"") end end)
        end
    end
    for _, url in ipairs(urls) do
        debugPrint("Downloading "..fileName.." from: "..url)
        local content = safeHttpGet(url)
        if content and content~="" then
            local fn, err = loadstring(content)
            if fn then
                pcall(function() if writefile then writefile(fileName,content); debugPrint("Cached "..fileName) end end)
                return content, fn
            else
                debugPrint("Invalid Lua from "..url..": "..tostring(err))
            end
        end
    end
    return nil, nil
end

local Fluent_URLs = {
    "https://mirror.ghproxy.com/https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
    "https://ghproxy.net/https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
    "https://ghfast.top/https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
}

local fluentRaw, fluentCompiled = loadLibrary("SH_Fluent.lua", Fluent_URLs)
if not fluentRaw or not fluentCompiled then
    debugPrint("CRITICAL: Failed to load Fluent!"); return
end

local loadOk, Fluent = pcall(fluentCompiled)
if not loadOk or not Fluent then
    debugPrint("CRITICAL: Fluent exec failed: "..tostring(Fluent)); return
end

-- ─── InterfaceManager (Inlined) ──────────────────────────────────────────────
local InterfaceManager = {} do
    InterfaceManager.Folder   = "FluentSettings"
    InterfaceManager.Settings = { Theme="Dark", Acrylic=true, Transparency=true, MenuKeybind="Insert" }
    function InterfaceManager:SetFolder(f)    self.Folder=f; self:BuildFolderTree() end
    function InterfaceManager:SetLibrary(lib) self.Library=lib end
    function InterfaceManager:BuildFolderTree()
        for _,p in ipairs({self.Folder, self.Folder.."/settings"}) do
            if not isfolder(p) then makefolder(p) end
        end
    end
    function InterfaceManager:SaveSettings()
        writefile(self.Folder.."/options.json", HttpService:JSONEncode(self.Settings))
    end
    function InterfaceManager:LoadSettings()
        local p = self.Folder.."/options.json"
        if isfile(p) then
            local ok,d = pcall(HttpService.JSONDecode, HttpService, readfile(p))
            if ok then for k,v in next,d do self.Settings[k]=v end end
        end
    end
    function InterfaceManager:BuildInterfaceSection(tab)
        assert(self.Library, "Must set InterfaceManager.Library")
        local L = self.Library; local S = self.Settings
        self:LoadSettings()
        local sec = tab:AddSection("Interface")
        local themeDD = sec:AddDropdown("InterfaceTheme",{
            Title="Theme", Values=L.Themes, Default=S.Theme,
            Callback=function(v) L:SetTheme(v); S.Theme=v; self:SaveSettings() end
        }); themeDD:SetValue(S.Theme)
        if L.UseAcrylic then
            sec:AddToggle("AcrylicToggle",{Title="Acrylic",Default=S.Acrylic,
                Callback=function(v) L:ToggleAcrylic(v); S.Acrylic=v; self:SaveSettings() end})
        end
        sec:AddToggle("TransparentToggle",{Title="Transparency",Default=S.Transparency,
            Callback=function(v) L:ToggleAcrylic(v); L:ToggleTransparency(v); S.Transparency=v; self:SaveSettings() end})
        local kb = sec:AddKeybind("MenuKeybind",{Title="Minimize Bind",Default=S.MenuKeybind})
        kb:OnChanged(function() S.MenuKeybind=kb.Value; self:SaveSettings() end)
        L.MinimizeKeybind = kb
    end
end

-- ─── SaveManager (Inlined) ───────────────────────────────────────────────────
local SaveManager = {} do
    SaveManager.Folder = "FluentSettings"
    SaveManager.Ignore = {}
    SaveManager.Parser = {
        Toggle   = {Save=function(_,obj) return {type="Toggle",  value=obj.Value} end, Load=function(_,d,o) if d.value~=nil then o:SetValue(d.value) end end},
        Slider   = {Save=function(_,obj) return {type="Slider",  value=obj.Value} end, Load=function(_,d,o) if d.value~=nil then o:SetValue(d.value) end end},
        Dropdown = {Save=function(_,obj) return {type="Dropdown",value=obj.Value} end, Load=function(_,d,o) if d.value~=nil then o:SetValue(d.value) end end},
        Keybind  = {Save=function(_,obj) return {type="Keybind", value=obj.Value} end, Load=function(_,d,o) if d.value~=nil then o:SetValue(d.value) end end},
        Input    = {Save=function(_,obj) return {type="Input",   value=obj.Value} end, Load=function(_,d,o) if d.value~=nil then o:SetValue(d.value) end end},
    }
    function SaveManager:SetLibrary(lib)    self.Library=lib end
    function SaveManager:IgnoreThemeSettings() self.IgnoreTheme=true end
    function SaveManager:SetFolder(f)
        self.Folder=f
        if not isfolder(f) then makefolder(f) end
        if not isfolder(f.."/configs") then makefolder(f.."/configs") end
    end
    function SaveManager:Save(name)
        local L=self.Library; assert(L,"Must set Library")
        local data={}
        for idx,opt in next,L.Options do
            if not self.Ignore[idx] and self.Parser[opt.Type] then
                local ok,saved=pcall(self.Parser[opt.Type].Save,self,opt)
                if ok then data[idx]=saved end
            end
        end
        writefile(self.Folder.."/configs/"..name..".json", HttpService:JSONEncode(data))
    end
    function SaveManager:Load(name)
        local L=self.Library; assert(L,"Must set Library")
        local p=self.Folder.."/configs/"..name..".json"
        if not isfile(p) then return end
        local ok,data=pcall(HttpService.JSONDecode,HttpService,readfile(p))
        if not ok then return end
        for idx,entry in next,data do
            local opt=L.Options[idx]
            if opt and self.Parser[entry.type] then pcall(self.Parser[entry.type].Load,self,entry,opt) end
        end
    end
    function SaveManager:LoadAutoloadConfig()
        local p=self.Folder.."/configs/autoload.txt"
        if isfile(p) then
            local name=readfile(p):gsub("[\r\n]","")
            if name~="" then self:Load(name) end
        end
    end
    function SaveManager:BuildConfigSection(tab)
        local sec=tab:AddSection("Configuration")
        local ci=sec:AddInput("SaveConfigName",{Title="Config Name",Default="default"})
        sec:AddButton({Title="Save Config",Callback=function()
            if ci.Value~="" then self:Save(ci.Value); Fluent:Notify({Title="Saved!",Content="'"..ci.Value.."' saved.",Duration=3}) end
        end})
        sec:AddButton({Title="Load Config",Callback=function()
            if ci.Value~="" then self:Load(ci.Value); Fluent:Notify({Title="Loaded!",Content="'"..ci.Value.."' loaded.",Duration=3}) end
        end})
        sec:AddButton({Title="Set Autoload",Callback=function()
            if ci.Value~="" then
                writefile(self.Folder.."/configs/autoload.txt",ci.Value)
                Fluent:Notify({Title="Autoload Set!",Content="'"..ci.Value.."' akan auto-load saat execute.",Duration=3})
            end
        end})
    end
end

-- ─── Create Window ───────────────────────────────────────────────────────────
local Window = Fluent:CreateWindow({
    Title="Summon Heroes", SubTitle="VICO",
    TabWidth=160, Size=UDim2.fromOffset(580,480),
    Acrylic=true, Theme="Dark",
    MinimizeKey=Enum.KeyCode.Insert
})

-- ─── Floating SH Toggle Button ───────────────────────────────────────────────
pcall(function()
    local cg = game:GetService("CoreGui")
    local old = cg:FindFirstChild("SummonHeroesToggleGui")
    if old then old:Destroy() end
    local gui = Instance.new("ScreenGui"); gui.Name="SummonHeroesToggleGui"
    gui.ResetOnSpawn=false; gui.Parent=cg
    local btn = Instance.new("TextButton"); btn.Parent=gui
    btn.Size=UDim2.new(0,50,0,50); btn.Position=UDim2.new(0.02,0,0.2,0)
    btn.BackgroundColor3=Color3.fromRGB(20,20,25); btn.BorderSizePixel=0
    btn.Text="SH"; btn.TextColor3=Color3.fromRGB(0,180,255)
    btn.Font=Enum.Font.GothamBold; btn.TextSize=16
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0.5,0)
    local s=Instance.new("UIStroke",btn); s.Color=Color3.fromRGB(0,180,255); s.Thickness=2
    btn.MouseButton1Click:Connect(function() pcall(function() Window:Minimize() end) end)
    local UIS=game:GetService("UserInputService")
    local dragging,dragInput,dragStart,startPos
    btn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=i.Position; startPos=btn.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    btn.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then dragInput=i end
    end)
    UIS.InputChanged:Connect(function(i)
        if i==dragInput and dragging then
            local d=i.Position-dragStart
            btn.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end)

-- ─── Tabs ────────────────────────────────────────────────────────────────────
local Tabs = {
    Main      = Window:AddTab({ Title="Automation",    Icon="play" }),
    Summon    = Window:AddTab({ Title="Summon & Shop", Icon="shopping-cart" }),
    Inventory = Window:AddTab({ Title="Inventory",     Icon="archive" }),
    Settings  = Window:AddTab({ Title="Settings",      Icon="settings" }),
}

local function GetOption(key, fallback)
    local opt = Fluent.Options[key]
    if opt then return opt.Value end
    return fallback
end

-- ─── Remotes ─────────────────────────────────────────────────────────────────
local ReadyRemote, VoteRemote, SummonRemote, FuseRemote, SellRemote

local function isValid(r)
    if not r then return false end
    return pcall(function() return r.Name end)
end

local function bindRemotes()
    local ok, err = pcall(function()
        local R = ReplicatedStorage:WaitForChild("Remotes", 15)
        if not R then debugPrint("[Remotes] CRITICAL: Remotes folder tidak ada!"); return end
        ReadyRemote  = R:FindFirstChild("Waves_Ready")  or R:WaitForChild("Waves_Ready",  5)
        VoteRemote   = R:FindFirstChild("Vote")         or R:WaitForChild("Vote",         5)
        SummonRemote = R:FindFirstChild("BuyPack")      or R:WaitForChild("BuyPack",      5)
        FuseRemote   = R:FindFirstChild("PurchaseFuse") or R:WaitForChild("PurchaseFuse", 5)
        SellRemote   = R:FindFirstChild("SellItems")    or R:WaitForChild("SellItems",    5)
        debugPrint("[Remotes] Waves_Ready:"  ..(isValid(ReadyRemote)  and "OK" or "MISS"))
        debugPrint("[Remotes] Vote:"         ..(isValid(VoteRemote)   and "OK" or "MISS"))
        debugPrint("[Remotes] BuyPack:"      ..(isValid(SummonRemote) and "OK" or "MISS"))
        debugPrint("[Remotes] PurchaseFuse:" ..(isValid(FuseRemote)   and "OK" or "MISS"))
        debugPrint("[Remotes] SellItems:"    ..(isValid(SellRemote)   and "OK" or "MISS"))
    end)
    if not ok then debugPrint("[Remotes] bindRemotes error: "..tostring(err)) end
end

bindRemotes()

local function isInBattle()
    return game.PlaceId ~= 117381420723145 and workspace:FindFirstChild("Map") ~= nil
end

-- ─── Lobby Persistence ───────────────────────────────────────────────────────
player.CharacterAdded:Connect(function()
    task.wait(2)
    bindRemotes()
    debugPrint("[Persistence] CharacterAdded: remotes re-bound")
end)

pcall(function()
    TeleportService.LocalPlayerArrivedFromTeleport:Connect(function()
        task.wait(3)
        bindRemotes()
        debugPrint("[Persistence] ArrivedFromTeleport: remotes re-bound")
    end)
end)

task.spawn(function()
    while task.wait(5) do
        if not isValid(ReadyRemote) or not isValid(VoteRemote) or not isValid(SummonRemote) then
            debugPrint("[Watchdog] Remote invalid, rebinding...")
            bindRemotes()
        end
    end
end)

-- ─── Utility Functions ───────────────────────────────────────────────────────
local function GetUnitsFolder()
    local profile   = playerGui:FindFirstChild("Profile")
    local inventory = profile and profile:FindFirstChild("Inventory")
    return inventory and inventory:FindFirstChild("Units")
end

local rarityTable = {
    Rare      = {"AcademyWitch","Archer","Bandit","BearTamer","Deckhand","FireMage","IceMage","Ninja","Swordsman","StreetRat"},
    Epic      = {"Captain","CyberDJ","DemonHunter","Diver","Dragoon","DualWielder","Mermaid","Necromancer","Outlaw","SlimeSummoner","Spellblade","Vampire","WindSamurai","Specter","Thief","Construct"},
    Legendary = {"AbyssLord","LaserCyborg","DemonKnight","Jester","KitsuneMage","Sniper","Framerate","Technomancer","TankCommander","Ranger","Sage"},
    Mythic    = {"Divine","Reaper","Seraph","Emperor","B-4RB.E.T.","Matriarch","Rend"},
}

local function GetUnitRarity(unitName)
    local clean = unitName:gsub("%s",""):gsub("[^%w%-]","")
    for rarity, units in pairs(rarityTable) do
        for _, name in ipairs(units) do
            if name:lower()==clean:lower() then return rarity end
        end
    end
    return "Common"
end

-- Filter untuk mengenali tombol interaksi peti (dengan pencarian induk secara rekursif)
local function isChestPrompt(prompt)
    local objText = tostring(prompt.ObjectText or ""):lower()
    local actText = tostring(prompt.ActionText or ""):lower()
    local name = tostring(prompt.Name):lower()
    
    if string.find(objText, "peti") or string.find(objText, "chest")
        or string.find(actText, "peti") or string.find(actText, "chest")
        or string.find(actText, "buka") or string.find(actText, "open")
        or string.find(name, "chest") or string.find(name, "peti") then
        return true
    end
    
    -- Cek jika ada induk/ancestor yang mengandung nama "chest" atau "peti" (misal BonusChests)
    local current = prompt.Parent
    while current and current ~= workspace do
        local cName = tostring(current.Name):lower()
        if string.find(cName, "chest") or string.find(cName, "peti") then
            return true
        end
        current = current.Parent
    end
    
    return false
end

-- ─── Auto Collect Chests ─────────────────────────────────────────────────────
local chestCooldowns = {}

local function collectChests()
    local now = os.time()
    local prompts = {}
    
    local map = workspace:FindFirstChild("Map")
    local bonusChests = map and map:FindFirstChild("BonusChests")
    if bonusChests then
        for _, desc in ipairs(bonusChests:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                table.insert(prompts, desc)
            end
        end
    end
    
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Chest" or string.find(child.Name:lower(), "chest") then
            for _, desc in ipairs(child:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then
                    table.insert(prompts, desc)
                end
            end
        end
    end
    
    if #prompts == 0 then
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled and isChestPrompt(desc) then
                table.insert(prompts, desc)
            end
        end
    end
    
    for _, desc in ipairs(prompts) do
        if desc.Enabled and isChestPrompt(desc) then
            local lastTry = chestCooldowns[desc] or 0
            if now - lastTry >= 3 then
                chestCooldowns[desc] = now
                pcall(function()
                    local character = player.Character
                    local hrp = character and character:FindFirstChild("HumanoidRootPart")
                    local basePart = nil
                    if desc.Parent and desc.Parent:IsA("BasePart") then
                        basePart = desc.Parent
                    elseif desc.Parent and desc.Parent:IsA("Attachment") and desc.Parent.Parent and desc.Parent.Parent:IsA("BasePart") then
                        basePart = desc.Parent.Parent
                    else
                        basePart = desc:FindFirstAncestorOfClass("BasePart")
                    end
                    
                    if hrp and basePart then
                        character:PivotTo(basePart.CFrame + Vector3.new(0, 1.5, 0))
                        task.wait(0.35)
                        local oldHold = desc.HoldDuration
                        desc.HoldDuration = 0
                        fireproximityprompt(desc)
                        task.wait(0.25)
                        desc.HoldDuration = oldHold
                    else
                        local oldHold = desc.HoldDuration
                        desc.HoldDuration = 0
                        fireproximityprompt(desc)
                        task.wait(0.15)
                        desc.HoldDuration = oldHold
                    end
                    debugPrint("Collected chest: " .. desc:GetFullName())
                end)
            end
        end
    end
end

-- ─── Auto Sell ───────────────────────────────────────────────────────────────
local function sellUnits()
    local uf = GetUnitsFolder(); if not uf then return end
    local toSell = {}
    for _, unit in ipairs(uf:GetChildren()) do
        local n = (unit:FindFirstChild("UnitName") or unit).Value or unit.Name
        local r = GetUnitRarity(n)
        if (r=="Rare" and GetOption("SellRare",false)) or (r=="Epic" and GetOption("SellEpic",false))
        or (r=="Legendary" and GetOption("SellLegendary",false)) then
            table.insert(toSell, unit.Name)
        end
    end
    if #toSell>0 and SellRemote then
        pcall(function() SellRemote:FireServer(toSell); debugPrint("Auto Sold "..#toSell.." units") end)
    end
end

-- ─── Auto Fuse ───────────────────────────────────────────────────────────────
local function fuseUnits()
    local uf = GetUnitsFolder(); if not uf then return end
    local groups = {}
    for _, unit in ipairs(uf:GetChildren()) do
        local n = (unit:FindFirstChild("UnitName") or unit).Value or unit.Name
        local s = (unit:FindFirstChild("Stars") and unit:FindFirstChild("Stars").Value) or 1
        local r = GetUnitRarity(n)
        if (r=="Rare" or r=="Epic") and s<5 then
            local k = n.."_"..s
            if not groups[k] then groups[k]={} end
            table.insert(groups[k], unit.Name)
        end
    end
    for _, list in pairs(groups) do
        if #list>=2 and FuseRemote then
            pcall(function()
                local food={}
                for i=2,math.min(#list,5) do table.insert(food,list[i]) end
                FuseRemote:FireServer(list[1], food)
                debugPrint("Auto Fused "..#food.." units into "..list[1])
            end)
            task.wait(0.5)
        end
    end
end

-- ─── Vote System ─────────────────────────────────────────────────────────────
-- Teks tombol persis dari screenshot:
--   Retry = "Putar Ulang Tahap"
--   Next  = "Mainkan Peta Berikutnya" / "Tahap Selanjutnya"
--   Lobby = "Kembali ke Lobi"
local VOTE_TEXTS = {
    Retry = {"putar ulang tahap", "replay stage"},
    Next  = {"mainkan peta berikutnya", "tahap selanjutnya", "next stage", "next map"},
    Lobby = {"kembali ke lobi", "kembali ke lobby", "return to lobby"},
}

local function cleanText(txt)
    if not txt then return "" end
    local s = tostring(txt)
    s = s:gsub("<[^<>]+>", "") -- Hilangkan tag HTML/XML jika rich text aktif
    s = s:lower()
    s = s:gsub("%s+", " ") -- Satukan semua spasi/newline/tab menjadi spasi tunggal
    s = s:match("^%s*(.-)%s*$") or s -- Trim
    return s
end

-- Periksa apakah objek GUI benar-benar aktif dan terlihat di layar pemain
local function isGuiVisible(obj)
    if not obj then return false end
    
    -- Cek jika ScreenGui induk dinonaktifkan
    local screenGui = obj:FindFirstAncestorOfClass("ScreenGui")
    if screenGui and not screenGui.Enabled then
        return false
    end
    
    -- Cek jika objek itu sendiri atau salah satu induk GuiObject-nya tersembunyi
    local current = obj
    while current and current:IsA("GuiObject") do
        if not current.Visible then
            return false
        end
        current = current.Parent
    end
    
    return true
end

-- Cari TextButton atau TextLabel di semua GUI berdasarkan teks (hanya yang aktif/terlihat)
local function findButtonByTexts(targetTexts)
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, desc in ipairs(gui:GetDescendants()) do
                if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and isGuiVisible(desc) then
                    local txt = cleanText(desc.Text)
                    for _, t in ipairs(targetTexts) do
                        if txt == t or string.find(txt, t, 1, true) then
                            -- Jika TextButton, langsung kembalikan
                            if desc:IsA("TextButton") then
                                return desc
                            end
                            -- Jika TextLabel, cari parent/ancestor yang bertindak sebagai Button
                            local parent = desc.Parent
                            for i = 1, 3 do
                                if parent and (parent:IsA("GuiButton") or parent:IsA("TextButton") or parent:IsA("ImageButton")) and isGuiVisible(parent) then
                                    return parent
                                end
                                if parent then parent = parent.Parent else break end
                            end
                            -- Fallback ke parent terdekat jika tidak ditemukan GuiButton
                            return desc.Parent or desc
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Klik tombol: coba semua metode secara berurutan
local function clickButton(btn)
    -- Metode 1: getconnections (Xeno mendukung)
    local clicked = false
    pcall(function()
        if getconnections then
            for _, evName in ipairs({"Activated","MouseButton1Click","MouseButton1Down"}) do
                local ok, conns = pcall(getconnections, btn[evName])
                if ok and conns and #conns>0 then
                    for _, conn in ipairs(conns) do
                        pcall(function() conn:Fire() end)
                        clicked = true
                    end
                end
            end
        end
    end)
    if clicked then return true end

    -- Metode 2: Fire events langsung (universal)
    pcall(function()
        btn.MouseButton1Down:Fire(0,0); task.wait(0.05)
        btn.MouseButton1Up:Fire(0,0)
        btn.MouseButton1Click:Fire(0,0)
        if btn:IsA("GuiButton") then
            btn.Activated:Fire()
        end
        clicked = true
    end)
    if clicked then return true end

    -- Metode 3: Mouse simulation fisik (Xeno)
    pcall(function()
        local p = btn.AbsolutePosition + btn.AbsoluteSize/2
        if mousemoveabs then mousemoveabs(p.X, p.Y); task.wait(0.05) end
        if mouse1click then mouse1click(); clicked=true
        elseif mouse1press then mouse1press(); task.wait(0.05); mouse1release(); clicked=true end
    end)
    return clicked
end

-- ─── Shop Utility Functions ──────────────────────────────────────────────────
local function getPlayerCurrency()
    local gold = 0
    local gems = 0
    
    -- 1. Try leaderstats
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local gVal = ls:FindFirstChild("Gold") or ls:FindFirstChild("Coins") or ls:FindFirstChild("Cash")
        local gemVal = ls:FindFirstChild("Gems") or ls:FindFirstChild("Diamonds")
        if gVal and gVal:IsA("ValueBase") then gold = gVal.Value end
        if gemVal and gemVal:IsA("ValueBase") then gems = gemVal.Value end
    end
    
    -- 2. Check Player attributes
    pcall(function()
        local goldAttr = player:GetAttribute("Gold") or player:GetAttribute("Coins")
        local gemAttr = player:GetAttribute("Gems") or player:GetAttribute("Diamonds")
        if goldAttr then gold = goldAttr end
        if gemAttr then gems = gemAttr end
    end)
    
    return gold, gems
end

local function getCurrencyType(priceLabel, cardFrame)
    local currency = "Gems"
    for _, child in ipairs(cardFrame:GetDescendants()) do
        if child:IsA("ImageLabel") and child.Visible then
            local img = tostring(child.Image):lower()
            if img:find("coin") or img:find("gold") or img:find("yellow") or img:find("money") then
                return "Gold"
            elseif img:find("gem") or img:find("diamond") or img:find("crystal") or img:find("purple") or img:find("blue") then
                return "Gems"
            end
        end
    end
    if priceLabel then
        local color = priceLabel.TextColor3
        if color.R > 0.7 and color.G > 0.6 and color.B < 0.4 then
            return "Gold"
        end
    end
    return currency
end

local function matchItemType(itemName)
    local name = cleanText(itemName)
    if name:find("pengulangan") or name:find("ciri") or name:find("reroll") then
        return "TraitReroll"
    elseif name:find("tiket") or name:find("pemanggilan") or name:find("ticket") or name:find("summon") then
        return "SummonTicket"
    elseif name:find("fusion") or name:find("kristal") or name:find("crystal") then
        return "FusionCrystal"
    else
        return "GoldConsumable"
    end
end

local function findShopFrame()
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, desc in ipairs(gui:GetDescendants()) do
                if (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox")) and isGuiVisible(desc) then
                    local text = cleanText(desc.Text)
                    if text == "toko item" or text == "item shop" then
                        return desc
                    end
                end
            end
        end
    end
    return nil
end

local function getSortedShopCards(shopScreen)
    local grid = nil
    for _, desc in ipairs(shopScreen:GetDescendants()) do
        if desc:IsA("UIGridLayout") or desc:IsA("UIListLayout") then
            grid = desc
            break
        end
    end
    
    local container = grid and grid.Parent
    if not container then
        for _, desc in ipairs(shopScreen:GetDescendants()) do
            if desc:IsA("ScrollingFrame") then
                container = desc
                break
            end
        end
    end
    
    if not container then
        -- Find parent container of card with a Beli button
        for _, desc in ipairs(shopScreen:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                local txt = cleanText(desc.Text)
                if txt == "beli" or txt == "buy" then
                    local card = desc:IsA("TextButton") and desc.Parent or (desc.Parent and desc.Parent.Parent)
                    if card and card.Parent then
                        container = card.Parent
                        break
                    end
                end
            end
        end
    end
    
    if not container then return {} end
    
    local cards = {}
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("GuiObject") then
            local hasButton = false
            for _, desc in ipairs(child:GetDescendants()) do
                if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                    hasButton = true
                    break
                end
            end
            if hasButton then
                table.insert(cards, child)
            end
        end
    end
    
    table.sort(cards, function(a, b)
        if a.LayoutOrder ~= b.LayoutOrder then
            return a.LayoutOrder < b.LayoutOrder
        end
        if a.AbsolutePosition.Y ~= b.AbsolutePosition.Y then
            return a.AbsolutePosition.Y < b.AbsolutePosition.Y
        end
        return a.AbsolutePosition.X < b.AbsolutePosition.X
    end)
    
    return cards
end

local function autoConfirmPurchase()
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("TextButton") and isGuiVisible(desc) then
                    local txt = cleanText(desc.Text)
                    if txt == "ya" or txt == "setuju" or txt == "yes" or txt == "confirm" or txt == "konfirmasi" or txt == "ok" then
                        local parentName = tostring(desc.Parent.Name):lower()
                        if parentName:find("popup") or parentName:find("dialog") or parentName:find("confirm") or parentName:find("prompt") or parentName:find("frame") then
                            clickButton(desc)
                            debugPrint("[AutoBuy] Auto-confirmed popup button: " .. desc.Text)
                        end
                    end
                end
            end
        end
    end
end

local function getShopPrompt()
    local best = nil
    debugPrint("[ShopPrompt] Scanning workspace for ProximityPrompts...")
    local promptsFound = 0
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            promptsFound = promptsFound + 1
            local name = tostring(desc.Name):lower()
            local obj = tostring(desc.ObjectText or ""):lower()
            local act = tostring(desc.ActionText or ""):lower()
            debugPrint("[ShopPrompt] Found prompt: " .. desc:GetFullName() .. " | Name: " .. name .. " | Obj: " .. obj .. " | Act: " .. act)
            
            -- High priority: exact match
            if name:find("toko item") or name:find("item shop")
                or obj:find("toko item") or obj:find("item shop")
                or act:find("toko item") or act:find("item shop") then
                debugPrint("[ShopPrompt] Best prompt found (exact match): " .. desc:GetFullName())
                return desc
            end
            
            -- Secondary priority: item/shop/toko keywords
            if name:find("item") or obj:find("item") or act:find("item") then
                best = desc
            elseif not best and (name:find("shop") or name:find("toko") or obj:find("shop") or obj:find("toko")) then
                best = desc
            elseif not best and (name:find("beli") or name:find("buy") or obj:find("beli") or obj:find("buy") or act:find("beli") or act:find("buy")) then
                best = desc
            end
        end
    end
    debugPrint("[ShopPrompt] Scan complete. Total prompts found: " .. promptsFound .. " | Selected best: " .. (best and best:GetFullName() or "nil"))
    return best
end

local function closeShopUI(shopFrame)
    for _, child in ipairs(shopFrame:GetDescendants()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            local txt = cleanText(child.Text)
            if txt == "x" or child.Name:lower():find("close") or child.Name:lower():find("tutup") or child.Name == "CloseBtn" or child.Name == "CloseButton" then
                clickButton(child)
                debugPrint("[AutoBuy] Closed Shop UI using button: " .. child.Name)
                return true
            end
        end
    end
    return false
end

local function getShopResetTime(shopFrame)
    for _, desc in ipairs(shopFrame:GetDescendants()) do
        if desc:IsA("TextLabel") and isGuiVisible(desc) then
            local txt = desc.Text:lower()
            if txt:find("diperbarui") or txt:find("refreshed") or txt:find("reset") or txt:find("menit") or txt:find("detik") then
                local m = txt:match("(%d+)m") or txt:match("(%d+)%s*menit") or txt:match("(%d+)%s*min")
                local s = txt:match("(%d+)s") or txt:match("(%d+)%s*detik") or txt:match("(%d+)%s*sec") or txt:match("dalam%s*(%d+)%s*detik")
                local totalSec = 0
                if m then totalSec = totalSec + tonumber(m) * 60 end
                if s then totalSec = totalSec + tonumber(s) end
                if totalSec > 0 then return totalSec end
                local secOnly = txt:match("dalam%s*(%d+)") or txt:match("(%d+)%s*seconds") or txt:match("(%d+)%s*detik")
                if secOnly then return tonumber(secOnly) end
            end
        end
    end
    return nil
end

-- State vote (reset saat layar hilang)
local votedThisRound = false
local lastClickTime  = 0
local voteAttempts   = 0
local voteScreenVisibleSince = 0

local FINISH_TEXTS = {"kemenangan!", "kekalahan!", "victory!", "defeat!"}

local function isMatchFinished()
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, desc in ipairs(gui:GetDescendants()) do
                if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and isGuiVisible(desc) then
                    local txt = cleanText(desc.Text)
                    for _, t in ipairs(FINISH_TEXTS) do
                        if txt == t or string.find(txt, t, 1, true) then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function isVoteScreenVisible()
    return isMatchFinished() and (
        findButtonByTexts(VOTE_TEXTS.Retry) ~= nil
        or findButtonByTexts(VOTE_TEXTS.Next)  ~= nil
    )
end

-- Dipanggil setiap detik dari main loop — retry sampai berhasil
local function tryAutoVote()
    -- Jika sudah pernah klik, tunggu minimal 5 detik sebelum coba lagi (cooldown jika belum ter-teleport)
    if votedThisRound and (os.time() - lastClickTime < 5) then return end

    -- Tentukan pilihan
    local choice = nil
    if     GetOption("AutoRetry",     false) then choice = "Retry"
    elseif GetOption("AutoNextStage", false) then choice = "Next"
    elseif GetOption("AutoLobby",     false) then choice = "Lobby"
    end
    if not choice then return end

    -- Cari dan klik tombol GUI
    local targetTexts = VOTE_TEXTS[choice]
    local btn = findButtonByTexts(targetTexts)
    if btn then
        -- Selalu coba fire VoteRemote ke server (format berbagai kemungkinan) saat tombol sudah muncul
        pcall(function()
            if VoteRemote then
                pcall(function() VoteRemote:FireServer(choice) end)          -- "Retry"
                pcall(function() VoteRemote:FireServer(choice:lower()) end)  -- "retry"
            end
        end)

        local displayName = btn:IsA("TextLabel") and btn.Text or (btn:FindFirstChildOfClass("TextLabel") and btn:FindFirstChildOfClass("TextLabel").Text or btn.Name)
        debugPrint("[Vote] Tombol '"..tostring(displayName).."' ditemukan, mengklik...")
        local ok = clickButton(btn)
        if ok then
            votedThisRound = true
            lastClickTime  = os.time()
            voteAttempts   = 0
            debugPrint("[Vote] Berhasil memicu klik: "..choice)
        else
            voteAttempts = voteAttempts + 1
            debugPrint("[Vote] Klik gagal (attempt "..voteAttempts.."), retry 1 detik lagi")
        end
    else
        voteAttempts = voteAttempts + 1
        debugPrint("[Vote] Menunggu tombol '"..choice.."' muncul (attempt "..voteAttempts..")")
    end
end

-- ─── Anti-AFK ────────────────────────────────────────────────────────────────
player.Idled:Connect(function()
    pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(0,0)) end)
end)

-- checkDisconnection removed (replaced by event connection)

-- ─── GUI: Toggle & Options ────────────────────────────────────────────────────
local function autoSave()
    local name = GetOption("SaveConfigName", "default")
    if name == "" then name = "default" end
    pcall(function()
        SaveManager:Save(name)
    end)
end

-- PENTING: Setiap toggle MANDIRI — tidak perlu aktifkan Master Switch dulu!
-- Bot Active hanya digunakan sebagai kill-switch darurat.
Tabs.Main:AddToggle("BotActive",       { Title="⚡ Bot Active (Master Kill-Switch)", Default=false, Callback = autoSave })
Tabs.Main:AddToggle("AutoReady",       { Title="▶ Auto Wave Ready",                Default=false, Callback = autoSave })
Tabs.Main:AddToggle("AutoCollectChests",{ Title="▶ Auto Collect Bonus Chests",     Default=false, Callback = autoSave })

-- Vote toggles — pilih satu, otomatis matikan yang lain
Tabs.Main:AddToggle("AutoRetry", {
    Title="▶ Auto Putar Ulang Tahap", Default=false,
    Callback=function(v)
        if v then
            pcall(function()
                if Fluent.Options["AutoNextStage"] then Fluent.Options["AutoNextStage"]:SetValue(false) end
                if Fluent.Options["AutoLobby"]     then Fluent.Options["AutoLobby"]:SetValue(false) end
            end)
        end
        autoSave()
    end
})
Tabs.Main:AddToggle("AutoNextStage", {
    Title="▶ Auto Tahap Selanjutnya", Default=false,
    Callback=function(v)
        if v then
            pcall(function()
                if Fluent.Options["AutoRetry"] then Fluent.Options["AutoRetry"]:SetValue(false) end
                if Fluent.Options["AutoLobby"] then Fluent.Options["AutoLobby"]:SetValue(false) end
            end)
        end
        autoSave()
    end
})
Tabs.Main:AddToggle("AutoLobby", {
    Title="▶ Auto Kembali ke Lobi", Default=false,
    Callback=function(v)
        if v then
            pcall(function()
                if Fluent.Options["AutoRetry"]     then Fluent.Options["AutoRetry"]:SetValue(false) end
                if Fluent.Options["AutoNextStage"] then Fluent.Options["AutoNextStage"]:SetValue(false) end
            end)
        end
        autoSave()
    end
})

-- Tab Summon
Tabs.Summon:AddToggle("AutoSummon",    { Title="Auto Summon (Gacha)",            Default=false, Callback = autoSave })
Tabs.Summon:AddDropdown("SummonPack",  { Title="Pack Selection", Values={"Pack1","Pack2","Pack3"}, Default="Pack1", Callback = autoSave })
Tabs.Summon:AddInput("CustomSummonPack",{ Title="Custom Pack Override", Default="", Placeholder="e.g. Common Pack", Callback = autoSave })
Tabs.Summon:AddSlider("SummonAmount",  { Title="Amount per Summon", Min=1, Max=10, Default=1, Rounding=0, Callback = autoSave })
Tabs.Summon:AddSlider("SummonInterval",{ Title="Delay (detik)",     Min=1, Max=10, Default=3, Rounding=0, Callback = autoSave })

local ShopSection = Tabs.Summon:AddSection("Item Shop (Toko Item)")
ShopSection:AddToggle("AutoBuyShopActive", { Title="⚡ Auto Buy Shop Active", Default=false, Callback = autoSave })
ShopSection:AddToggle("AutoOpenShopNPC", { Title="▶ Auto Open & Refresh Shop", Default=false, Callback = autoSave })
ShopSection:AddToggle("AutoBuyTraitReroll", { Title="▶ Buy Trait Reroll (Pengulangan Ciri) [Gems]", Default=false, Callback = autoSave })
ShopSection:AddToggle("AutoBuySummonTicket", { Title="▶ Buy Summon Ticket (Tiket Pemanggilan) [Gems]", Default=false, Callback = autoSave })
ShopSection:AddToggle("AutoBuyFusionGem", { Title="▶ Buy Fusion Crystal [Gems]", Default=false, Callback = autoSave })
ShopSection:AddToggle("AutoBuyFusionGold", { Title="▶ Buy Fusion Crystal [Gold]", Default=false, Callback = autoSave })
ShopSection:AddToggle("AutoBuyGoldConsumables", { Title="▶ Buy All Gold Items (Burger, Candy, Cupcake, dll)", Default=false, Callback = autoSave })

-- Tab Inventory
Tabs.Inventory:AddToggle("SellRare",      { Title="Auto Sell Rare",       Default=false, Callback = autoSave })
Tabs.Inventory:AddToggle("SellEpic",      { Title="Auto Sell Epic",        Default=false, Callback = autoSave })
Tabs.Inventory:AddToggle("SellLegendary", { Title="Auto Sell Legendary",   Default=false, Callback = autoSave })
Tabs.Inventory:AddToggle("AutoFuse",      { Title="Auto Fuse Lower Stars", Default=false, Callback = autoSave })

-- Tab Settings
Tabs.Settings:AddToggle("AutoRejoin", { Title="Auto Rejoin on Disconnect", Default=true, Callback = autoSave })
Tabs.Settings:AddButton({ Title="Unload / Close", Callback=function()
    Fluent:Destroy()
    pcall(function()
        local old = game:GetService("CoreGui"):FindFirstChild("SummonHeroesToggleGui")
        if old then old:Destroy() end
    end)
end})

-- ─── SaveManager & InterfaceManager ──────────────────────────────────────────
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetFolder("SummonHeroes")
SaveManager:BuildConfigSection(Tabs.Settings)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
Window:SelectTab(1)
if isInBattle() then
    SaveManager:LoadAutoloadConfig()
end

Fluent:Notify({
    Title   = "Summon Heroes Bot",
    Content = "Ready! Setiap toggle MANDIRI — aktifkan langsung tanpa perlu Bot Active.\n" ..
              "Tip: Buka Xeno Settings > Auto-Execute untuk tidak perlu execute ulang saat lobby!",
    Duration= 8
})

-- ─── Loop Utama — mulai SETELAH GUI agar Options ter-register ────────────────
task.wait(0.5)

-- Loop 1: Auto Wave Ready + Auto Collect + Auto Vote
task.spawn(function()
    while task.wait(2) do
        -- Auto Wave Ready (MANDIRI)
        if GetOption("AutoReady", false) then
            pcall(function()
                if ReadyRemote then
                    ReadyRemote:FireServer()
                    debugPrint("[AutoReady] Waves_Ready fired")
                end
            end)
        end

        -- Auto Collect Chests (MANDIRI)
        if GetOption("AutoCollectChests", false) then
            collectChests()
        end

        -- Auto Vote (MANDIRI — hanya jika di dalam pertempuran)
        pcall(function()
            if isInBattle() then
                if isVoteScreenVisible() then
                    if voteScreenVisibleSince == 0 then
                        voteScreenVisibleSince = os.time()
                    end
                    -- Tunggu 3 detik setelah layar hasil muncul baru lakukan auto vote
                    if os.time() - voteScreenVisibleSince >= 3 then
                        tryAutoVote()
                    end
                else
                    voteScreenVisibleSince = 0
                    -- Reset state saat layar vote hilang
                    if votedThisRound or voteAttempts > 0 then
                        votedThisRound = false
                        voteAttempts   = 0
                    end
                end
            else
                voteScreenVisibleSince = 0
                if next(chestCooldowns) ~= nil then
                    table.clear(chestCooldowns)
                    debugPrint("[Chests] Reset chest cooldowns list")
                end
            end
        end)
    end
end)

-- Loop 2: Auto Summon
task.spawn(function()
    while true do
        if GetOption("AutoSummon", false) then
            pcall(function()
                if SummonRemote then
                    local custom = GetOption("CustomSummonPack","")
                    local pack   = (custom~="") and custom or GetOption("SummonPack","Pack1")
                    local amt    = tonumber(GetOption("SummonAmount",1)) or 1
                    SummonRemote:FireServer(pack, amt)
                    debugPrint("[AutoSummon] "..pack.." x"..amt)
                end
            end)
            task.wait(tonumber(GetOption("SummonInterval",3)) or 3)
        else
            task.wait(1)
        end
    end
end)

-- Loop 3: Auto Sell & Auto Fuse
task.spawn(function()
    while task.wait(10) do
        if GetOption("SellRare",false) or GetOption("SellEpic",false) or GetOption("SellLegendary",false) then
            sellUnits()
        end
        if GetOption("AutoFuse",false) then fuseUnits() end
    end
end)

-- checkDisconnection using safe, absolute paths without heavy CoreGui recursive crawling
local function checkDisconnection()
    pcall(function()
        local cg = game:GetService("CoreGui")
        local promptGui = cg and cg:FindFirstChild("RobloxPromptGui")
        local overlay = promptGui and promptGui:FindFirstChild("promptOverlay")
        local errorPrompt = overlay and overlay:FindFirstChild("ErrorPrompt")
        if errorPrompt and errorPrompt.Visible then
            debugPrint("[AutoRejoin] Disconnection prompt detected, reconnecting in 5 seconds...")
            task.wait(5)
            TeleportService:Teleport(game.PlaceId, player)
        end
    end)
end

-- Loop 4: Auto Rejoin (Checking error prompt presence)
task.spawn(function()
    while task.wait(15) do
        if GetOption("AutoRejoin", true) then
            checkDisconnection()
        end
    end
end)

-- Loop 5: Auto Buy Item Shop
local lastAutoOpenTime = 0
local openedByBot = false
local originalCFrame = nil
local lastPurchaseAttempt = {}

task.spawn(function()
    while true do
        task.wait(1.5)
        if GetOption("AutoBuyShopActive", false) then
            pcall(function()
                local inLobby = (game.PlaceId == 117381420723145)
                local shopTitleLabel = findShopFrame()
                local isCurrentlyOpen = shopTitleLabel and isGuiVisible(shopTitleLabel)
                
                -- Auto Open Shop if closed, enabled, and in lobby
                if not isCurrentlyOpen and GetOption("AutoOpenShopNPC", false) and inLobby then
                    local now = os.time()
                    if now - lastAutoOpenTime >= 30 then
                        local prompt = getShopPrompt()
                        local char = player.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if prompt and hrp then
                            originalCFrame = hrp.CFrame
                            local part = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt:FindFirstAncestorOfClass("BasePart")
                            if part then
                                -- Teleport to NPC
                                hrp.CFrame = part.CFrame + Vector3.new(0, 1.5, 0)
                                task.wait(0.3)
                                fireproximityprompt(prompt)
                                task.wait(1.0)
                                
                                -- Re-check if open
                                shopTitleLabel = findShopFrame()
                                if shopTitleLabel and isGuiVisible(shopTitleLabel) then
                                    isCurrentlyOpen = true
                                    openedByBot = true
                                    debugPrint("[AutoBuy] Shop opened automatically by bot.")
                                else
                                    -- Teleport back if opening failed
                                    hrp.CFrame = originalCFrame
                                    originalCFrame = nil
                                end
                            end
                        end
                        lastAutoOpenTime = os.time()
                    end
                end
                
                if isCurrentlyOpen then
                    local shopFrame = shopTitleLabel.Parent
                    
                    -- Check if reset timer is less than 5 seconds
                    local resetTime = getShopResetTime(shopFrame)
                    if resetTime and resetTime <= 5 then
                        debugPrint("[AutoBuy] Shop resets in " .. resetTime .. "s, waiting for refresh...")
                        task.wait(resetTime + 1.5)
                        -- Next cycle will scan the fresh items
                        return
                    end
                    
                    local shopScreen = shopTitleLabel:FindFirstAncestorOfClass("ScreenGui") or shopFrame
                    local cards = getSortedShopCards(shopScreen)
                    debugPrint("[AutoBuy] Found " .. #cards .. " item cards in the shop GUI.")
                    
                    for slotIndex, card in ipairs(cards) do
                        -- 1. Check stock
                        local isOutOfStock = false
                        for _, lbl in ipairs(card:GetDescendants()) do
                            if lbl:IsA("TextLabel") then
                                local txt = cleanText(lbl.Text)
                                if txt:find("habis") or txt:find("out of stock") or txt:find("kehabisan") then
                                    isOutOfStock = true
                                    break
                                end
                            end
                        end
                        
                        if not isOutOfStock then
                            -- 2. Match item type
                            local itemType = nil
                            local itemName = ""
                            for _, lbl in ipairs(card:GetDescendants()) do
                                if lbl:IsA("TextLabel") then
                                    local tType = matchItemType(lbl.Text)
                                    if tType then
                                        itemType = tType
                                        itemName = lbl.Text
                                        break
                                    end
                                end
                            end
                            
                            if itemType then
                                -- 3. Get price & currency
                                local price = 0
                                local priceLabel = nil
                                for _, lbl in ipairs(card:GetDescendants()) do
                                    if lbl:IsA("TextLabel") then
                                        local txt = lbl.Text:gsub("%D", "")
                                        local num = tonumber(txt)
                                        if num and num > 0 and num < 100000 then
                                            local cleanTxt = cleanText(lbl.Text)
                                            if not cleanTxt:find("stok") and not cleanTxt:find("tersisa") and not matchItemType(lbl.Text) then
                                                price = num
                                                priceLabel = lbl
                                                break
                                            end
                                        end
                                    end
                                end
                                
                                local currency = "Gems"
                                if priceLabel then
                                    currency = getCurrencyType(priceLabel, card)
                                end
                                
                                debugPrint("[AutoBuy] Slot " .. slotIndex .. ": ItemName=" .. tostring(itemName) .. " | Price=" .. price .. " | Currency=" .. currency .. " | Type=" .. tostring(itemType))
                                
                                -- 4. Get option key
                                local optionKey = nil
                                if itemType == "TraitReroll" then
                                    optionKey = "AutoBuyTraitReroll"
                                elseif itemType == "SummonTicket" then
                                    optionKey = "AutoBuySummonTicket"
                                elseif itemType == "FusionCrystal" then
                                    if currency == "Gems" then
                                        optionKey = "AutoBuyFusionGem"
                                    else
                                        optionKey = "AutoBuyFusionGold"
                                    end
                                elseif itemType == "GoldConsumable" then
                                    if currency == "Gold" then
                                        optionKey = "AutoBuyGoldConsumables"
                                    end
                                end
                                
                                if optionKey and GetOption(optionKey, false) then
                                    local lastAttempt = lastPurchaseAttempt[slotIndex] or 0
                                    if os.time() - lastAttempt >= 10 then
                                        -- 5. Currency Check
                                        local pGold, pGems = getPlayerCurrency()
                                        local hasEnough = true
                                        if currency == "Gold" and pGold > 0 and pGold < price then
                                            hasEnough = false
                                        elseif currency == "Gems" and pGems > 0 and pGems < price then
                                            hasEnough = false
                                        end
                                        
                                        if hasEnough then
                                            -- Find Beli button
                                            local beliBtn = nil
                                            for _, child in ipairs(card:GetDescendants()) do
                                                if child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("GuiButton") then
                                                    local txt = cleanText(child.Text)
                                                    if txt == "beli" or txt == "buy" or child.Name == "Beli" or child.Name == "Buy" then
                                                        beliBtn = child
                                                        break
                                                    end
                                                end
                                            end
                                            
                                            if beliBtn then
                                                lastPurchaseAttempt[slotIndex] = os.time()
                                                -- Fire remote
                                                pcall(function()
                                                    local BuyRemote = ReplicatedStorage:WaitForChild("Remotes", 2):FindFirstChild("BuyItem")
                                                    if BuyRemote then
                                                        BuyRemote:FireServer(slotIndex)
                                                    end
                                                end)
                                                -- Click button
                                                clickButton(beliBtn)
                                                task.wait(0.5)
                                                autoConfirmPurchase()
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Close shop and teleport back if opened by bot
                    if openedByBot then
                        task.wait(1.5)
                        closeShopUI(shopFrame)
                        task.wait(0.5)
                        local char = player.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp and originalCFrame then
                            hrp.CFrame = originalCFrame
                        end
                        openedByBot = false
                        originalCFrame = nil
                        debugPrint("[AutoBuy] Shop closed and player returned to original position.")
                    end
                end
            end)
        end
    end
end)
