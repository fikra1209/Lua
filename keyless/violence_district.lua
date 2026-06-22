--[[
    Violence District Automation Hub — v3.0 Clean
    Developed by Antigravity AI

    Fitur:
    - Auto Skill Check (100% Perfect via Remote Hook)
    - Auto Repair (Deteksi pcprompts + ProgressPromptGui)
    - ESP: Survivors, Killer, Generator, Pallet, Exit Gate
    - Speed / Jump Override
    - Noclip
]]

if game.GameId ~= 6739698191 and game.PlaceId ~= 93978595733734 then return end

-- ─── Services ────────────────────────────────────────────────────────────────
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local HttpService         = game:GetService("HttpService")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService     = game:GetService("UserInputService")

local player = Players.LocalPlayer
while not player do task.wait(0.1); player = Players.LocalPlayer end
local mouse = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui", 30)
if not playerGui then return end

local function log(msg)
    local t = "[VD Bot] " .. tostring(msg)
    print(t); warn(t)
    pcall(function() if rconsoleprint then rconsoleprint(t.."\n") end end)
end
log("Loading Violence District Hub v3.0...")

-- ─── Library Loader ───────────────────────────────────────────────────────────
local function httpGet(url)
    local reqFn = (syn and syn.request) or (http and http.request) or request or http_request
    if reqFn then
        local ok, res = pcall(function() return reqFn({Url=url,Method="GET",Timeout=5,timeout=5}) end)
        if ok and res then
            if type(res)=="table" and res.StatusCode==200 and res.Body then return res.Body end
            if type(res)=="string" then return res end
        end
    end
    local ok2, r2 = pcall(game.HttpGet, game, url)
    return ok2 and r2 or nil
end

local function safeGet(url)
    local ok, res = pcall(httpGet, url)
    if ok and res and res~="" and not res:find("404") and not res:find("<html") then return res end
end

local function loadLib(name, urls)
    local ok, c = pcall(function() if readfile then return readfile(name) end end)
    if ok and c and c~="" then
        local fn = loadstring(c)
        if fn then log("Loaded "..name.." from cache."); return fn end
    end
    for _, u in ipairs(urls) do
        local c2 = safeGet(u)
        if c2 then
            local fn = loadstring(c2)
            if fn then pcall(function() if writefile then writefile(name,c2) end end); return fn end
        end
    end
end

local FLUENT_URLS = {
    "https://mirror.ghproxy.com/https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
    "https://ghproxy.net/https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
    "https://ghfast.top/https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
}

local fluentFn = loadLib("SH_Fluent.lua", FLUENT_URLS)
if not fluentFn then log("CRITICAL: Fluent gagal dimuat!"); return end
local ok, Fluent = pcall(fluentFn)
if not ok or not Fluent then log("CRITICAL: Fluent error: "..tostring(Fluent)); return end

-- ─── InterfaceManager ─────────────────────────────────────────────────────────
local IM = {} do
    IM.Folder   = "ViolenceDistrictSettings"
    IM.Settings = { Theme="Dark", Acrylic=true, Transparency=true, MenuKeybind="Insert" }
    function IM:SetFolder(f) self.Folder=f; if not isfolder(f) then makefolder(f) end end
    function IM:SetLibrary(lib) self.Library=lib end
    function IM:SaveSettings() writefile(self.Folder.."/options.json", HttpService:JSONEncode(self.Settings)) end
    function IM:LoadSettings()
        local p=self.Folder.."/options.json"
        if isfile(p) then
            local ok,d=pcall(HttpService.JSONDecode,HttpService,readfile(p))
            if ok then for k,v in next,d do self.Settings[k]=v end end
        end
    end
    function IM:BuildInterfaceSection(tab)
        local L=self.Library; local S=self.Settings; self:LoadSettings()
        local sec=tab:AddSection("Interface")
        local dd=sec:AddDropdown("InterfaceTheme",{Title="Theme",Values=L.Themes,Default=S.Theme,
            Callback=function(v) L:SetTheme(v); S.Theme=v; self:SaveSettings() end})
        dd:SetValue(S.Theme)
        if L.UseAcrylic then
            sec:AddToggle("AcrylicToggle",{Title="Acrylic",Default=S.Acrylic,
                Callback=function(v) L:ToggleAcrylic(v); S.Acrylic=v; self:SaveSettings() end})
        end
        sec:AddToggle("TransparentToggle",{Title="Transparency",Default=S.Transparency,
            Callback=function(v) L:ToggleTransparency(v); S.Transparency=v; self:SaveSettings() end})
        local kb=sec:AddKeybind("MenuKeybind",{Title="Minimize Key",Default=S.MenuKeybind})
        kb:OnChanged(function() S.MenuKeybind=kb.Value; self:SaveSettings() end)
        L.MinimizeKeybind=kb
    end
end

-- ─── SaveManager ──────────────────────────────────────────────────────────────
local SM = {} do
    SM.Folder="ViolenceDistrictSettings"; SM.Ignore={}
    SM.Parser={
        Toggle  ={Save=function(_,o) return{type="Toggle",  value=o.Value} end, Load=function(_,d,o) if d.value~=nil then o:SetValue(d.value) end end},
        Slider  ={Save=function(_,o) return{type="Slider",  value=o.Value} end, Load=function(_,d,o) if d.value~=nil then o:SetValue(d.value) end end},
        Dropdown={Save=function(_,o) return{type="Dropdown",value=o.Value} end, Load=function(_,d,o) if d.value~=nil then o:SetValue(d.value) end end},
        Keybind ={Save=function(_,o) return{type="Keybind", value=o.Value} end, Load=function(_,d,o) if d.value~=nil then o:SetValue(d.value) end end},
        Input   ={Save=function(_,o) return{type="Input",   value=o.Value} end, Load=function(_,d,o) if d.value~=nil then o:SetValue(d.value) end end},
    }
    function SM:SetLibrary(lib) self.Library=lib end
    function SM:IgnoreThemeSettings() self.IgnoreTheme=true end
    function SM:SetFolder(f)
        self.Folder=f
        if not isfolder(f) then makefolder(f) end
        if not isfolder(f.."/configs") then makefolder(f.."/configs") end
    end
    function SM:Save(name)
        local L=self.Library; local data={}
        for idx,opt in next,L.Options do
            if not self.Ignore[idx] and self.Parser[opt.Type] then
                local ok,s=pcall(self.Parser[opt.Type].Save,self,opt)
                if ok then data[idx]=s end
            end
        end
        writefile(self.Folder.."/configs/"..name..".json", HttpService:JSONEncode(data))
    end
    function SM:Load(name)
        local L=self.Library; local p=self.Folder.."/configs/"..name..".json"
        if not isfile(p) then return end
        local ok,data=pcall(HttpService.JSONDecode,HttpService,readfile(p))
        if not ok then return end
        for idx,entry in next,data do
            local opt=L.Options[idx]
            if opt and self.Parser[entry.type] then pcall(self.Parser[entry.type].Load,self,entry,opt) end
        end
    end
    function SM:LoadAutoloadConfig()
        local p=self.Folder.."/configs/autoload.txt"
        if isfile(p) then local n=readfile(p):gsub("[\r\n]",""); if n~="" then self:Load(n) end end
    end
    function SM:BuildConfigSection(tab)
        local sec=tab:AddSection("Configuration")
        local ci=sec:AddInput("SaveConfigName",{Title="Config Name",Default="default"})
        sec:AddButton({Title="Save Config",Callback=function()
            if ci.Value~="" then self:Save(ci.Value); Fluent:Notify({Title="Saved!",Content=ci.Value.." saved.",Duration=3}) end
        end})
        sec:AddButton({Title="Load Config",Callback=function()
            if ci.Value~="" then self:Load(ci.Value); Fluent:Notify({Title="Loaded!",Content=ci.Value.." loaded.",Duration=3}) end
        end})
        sec:AddButton({Title="Set Autoload",Callback=function()
            if ci.Value~="" then
                writefile(self.Folder.."/configs/autoload.txt",ci.Value)
                Fluent:Notify({Title="Autoload Set!",Content=ci.Value.." autoload set.",Duration=3})
            end
        end})
    end
end

-- ─── Window ───────────────────────────────────────────────────────────────────
local Window = Fluent:CreateWindow({
    Title="Violence District Bot", SubTitle="LuxvS Hub",
    TabWidth=160, Size=UDim2.fromOffset(580,460),
    Acrylic=true, Theme="Dark",
    MinimizeKey=Enum.KeyCode.Insert
})

-- ─── Floating VD Button ───────────────────────────────────────────────────────
pcall(function()
    local cg=game:GetService("CoreGui")
    local old=cg:FindFirstChild("VDToggleGui"); if old then old:Destroy() end
    local gui=Instance.new("ScreenGui"); gui.Name="VDToggleGui"; gui.ResetOnSpawn=false; gui.Parent=cg
    local btn=Instance.new("TextButton"); btn.Parent=gui
    btn.Size=UDim2.new(0,50,0,50); btn.Position=UDim2.new(0.02,0,0.3,0)
    btn.BackgroundColor3=Color3.fromRGB(30,10,10); btn.BorderSizePixel=0
    btn.Text="VD"; btn.TextColor3=Color3.fromRGB(255,50,50)
    btn.Font=Enum.Font.GothamBold; btn.TextSize=16
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0.5,0)
    local s=Instance.new("UIStroke",btn); s.Color=Color3.fromRGB(255,50,50); s.Thickness=2
    btn.MouseButton1Click:Connect(function() pcall(function() Window:Minimize() end) end)
    local UIS=game:GetService("UserInputService")
    local dragging,dragInput,dragStart,startPos
    btn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true; dragStart=i.Position; startPos=btn.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    btn.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement then dragInput=i end
    end)
    UIS.InputChanged:Connect(function(i)
        if i==dragInput and dragging then
            local d=i.Position-dragStart
            btn.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end)

-- ─── Tabs ─────────────────────────────────────────────────────────────────────
local Tabs = {
    Survivor = Window:AddTab({Title="Survivor",  Icon="user"}),
    Killer   = Window:AddTab({Title="Killer",    Icon="skull"}),
    Visuals  = Window:AddTab({Title="ESP",       Icon="eye"}),
    Movement = Window:AddTab({Title="Movement",  Icon="wind"}),
    Settings = Window:AddTab({Title="Settings",  Icon="settings"}),
}

local function GetOpt(key, fb) local o=Fluent.Options[key]; return o and o.Value or fb end

local function autoSave()
    pcall(function()
        local n=GetOpt("SaveConfigName","default"); if n=="" then n="default" end
        SM:Save(n)
    end)
end

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function getChar()   return player.Character end
local function getHum()    local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function getHRP()    local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end

-- ─── Mouse & Movement Hook ───────────────────────────────────────────────────
local speedToggle, speedSlider
local GameIntendedSpeed = 16
local successHook = false
local oldIndex
local oldNewIndex

-- 1. Try hookmetamethod (safer, cleaner)
successHook = pcall(function()
    if not hookmetamethod then error("hookmetamethod not available") end
    
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
        if not checkcaller() then
            if self == mouse then
                if GetOpt("PistolAimbot", false) then
                    if key == "Hit" or key == "hit" then
                        local killerChar = getKillerChar()
                        local hrp = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
                        if hrp then return hrp.CFrame end
                    elseif key == "Target" or key == "target" then
                        local killerChar = getKillerChar()
                        local hrp = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
                        if hrp then return hrp end
                    end
                end
            elseif typeof(self) == "Instance" and self:IsA("Humanoid") then
                if key == "WalkSpeed" then
                    return GetOpt("SpeedToggle", false) and GameIntendedSpeed or oldIndex(self, key)
                end
            end
        end
        return oldIndex(self, key)
    end))
    
    oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
        if not checkcaller() and typeof(self) == "Instance" and self:IsA("Humanoid") then
            if key == "WalkSpeed" then
                GameIntendedSpeed = value
                if GetOpt("SpeedToggle", false) and value > 2 then
                    local customSpd = GetOpt("SpeedSlider", 16)
                    if customSpd ~= 16 then value = customSpd end
                end
            end
        end
        return oldNewIndex(self, key, value)
    end))
end)

-- 2. Fallback to getrawmetatable
if not successHook then
    successHook = pcall(function()
        local mt = getrawmetatable(game)
        oldIndex = mt.__index
        oldNewIndex = mt.__newindex
        
        setreadonly(mt, false)
        mt.__index = newcclosure(function(self, key)
            if not checkcaller() then
                if self == mouse then
                    if GetOpt("PistolAimbot", false) then
                        if key == "Hit" or key == "hit" then
                            local killerChar = getKillerChar()
                            local hrp = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
                            if hrp then return hrp.CFrame end
                        elseif key == "Target" or key == "target" then
                            local killerChar = getKillerChar()
                            local hrp = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
                            if hrp then return hrp end
                        end
                    end
                elseif typeof(self) == "Instance" and self:IsA("Humanoid") then
                    if key == "WalkSpeed" then
                        return GetOpt("SpeedToggle", false) and GameIntendedSpeed or oldIndex(self, key)
                    end
                end
            end
            return oldIndex(self, key)
        end)
        
        mt.__newindex = newcclosure(function(self, key, value)
            if not checkcaller() and typeof(self) == "Instance" and self:IsA("Humanoid") then
                if key == "WalkSpeed" then
                    GameIntendedSpeed = value
                    if GetOpt("SpeedToggle", false) and value > 2 then
                        local customSpd = GetOpt("SpeedSlider", 16)
                        if customSpd ~= 16 then value = customSpd end
                    end
                end
            end
            return oldNewIndex(self, key, value)
        end)
        setreadonly(mt, true)
    end)
end

if successHook then
    log("Mouse & Speed metatable hooks active.")
else
    log("WARNING: Metatable hooks failed.")
end


-- ─── Killer Detection ─────────────────────────────────────────────────────────
local function isKiller(p)
    if not p or p==player then return false end
    local char=p.Character; if not char then return false end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("Light") and (v.Color==Color3.fromRGB(255,0,0) or v.Color==Color3.fromRGB(200,0,0)) then return true end
    end
    if char:FindFirstChild("Weapon") or char:FindFirstChild("Axe") or char:FindFirstChild("Knife") or char:FindFirstChild("Bat") then return true end
    return false
end

local function getKillerChar()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isKiller(p) then
            return p.Character
        end
    end
    return nil
end

local function getNearestPallet()
    local myHrp = getHRP(); if not myHrp then return nil end
    local nearest, minD = nil, math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local name = obj.Name:lower()
            if name:find("pallet") or name:find("plank") then
                local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local d = (myHrp.Position - part.Position).Magnitude
                    if d < minD then
                        minD = d
                        nearest = part
                    end
                end
            end
        end
    end
    return nearest
end

-- ─── ESP System ───────────────────────────────────────────────────────────────
local espData = {}

local function getESPPart(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart end
        -- Cari part apapun di dalam model secara rekursif
        local part = inst:FindFirstChildWhichIsA("BasePart", true)
        if part then return part end
    end
    return inst
end

local function addESP(inst, color, label, espType)
    if espData[inst] then return end
    
    local bp = getESPPart(inst)
    if not bp then return end -- Abaikan jika tidak ada part sama sekali
    
    local hi=Instance.new("Highlight")
    hi.Parent=inst; hi.FillColor=color; hi.OutlineColor=Color3.new(1,1,1)
    hi.FillTransparency=0.6; hi.OutlineTransparency=0.1
    hi.Enabled = false -- Default mati sampai loop update menyalakan

    local bb=Instance.new("BillboardGui")
    bb.Name="VD_ESP"; bb.AlwaysOnTop=true; bb.Size=UDim2.new(0,120,0,28)
    bb.Adornee=bp
    bb.Parent=inst
    bb.Enabled = false -- Default mati

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
    lbl.TextColor3=color; lbl.TextStrokeTransparency=0.2
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11; lbl.Text=label; lbl.Parent=bb

    espData[inst]={hi=hi, bb=bb, lbl=lbl, name=label, type=espType, bp=bp}
end

local function removeESP(inst)
    local d=espData[inst]
    if d then pcall(function() d.hi:Destroy() end); pcall(function() d.bb:Destroy() end); espData[inst]=nil end
end

-- Update label jarak setiap frame
task.spawn(function()
    while task.wait(0.2) do
        pcall(function()
            local hrp = getHRP()
            for inst, d in pairs(espData) do
                if not inst or not inst.Parent then
                    espData[inst] = nil
                elseif hrp then
                    local bp = d.bp
                    if bp and bp.Parent then
                        local pos
                        if bp:IsA("Model") then pos = bp:GetPivot().Position
                        elseif bp:IsA("BasePart") then pos = bp.Position end
                        
                        if pos then
                            local dist = math.round((hrp.Position - pos).Magnitude)
                            local limit = GetOpt("EspDist", 1000)
                            local show = false
                            if dist <= limit then
                                if d.type == "Generator" and GetOpt("EspGen", false) then show = true
                                elseif d.type == "Killer"    and GetOpt("EspKiller", false) then show = true
                                elseif d.type == "Survivor"  and GetOpt("EspSurv", false) then show = true
                                elseif d.type == "Pallet"    and GetOpt("EspPallet", false) then show = true
                                elseif d.type == "Gate"      and GetOpt("EspGate", false) then show = true
                                end
                            end
                            d.hi.Enabled = show
                            d.bb.Enabled = show
                            if show then d.lbl.Text = d.name .. " [" .. dist .. "m]" end
                        end
                    end
                end
            end
        end)
    end
end)

-- ─── ESP Object Detection ─────────────────────────────────────────────────────
local function classifyByName(name)
    local n = name:lower()
    -- Gunakan pola yang spesifik agar tidak salah deteksi bagian bangunan
    if n:find("^cabinet_%d+") or n:find("^generator_%d+") or n == "generator" or n == "mesin" then
        return "Generator", Color3.fromRGB(0, 180, 255), "Generator"
    elseif n:find("pallet") or n:find("plank") then
        return "Pallet", Color3.fromRGB(230, 180, 50), "Pallet"
    elseif n:find("gate") or n:find("exit") or n == "lever" then
        return "Exit Gate", Color3.fromRGB(50, 255, 120), "Gate"
    end
    return nil, nil, nil
end

-- Scan ke seluruh workspace tapi HANYA untuk Model dengan nama yang sangat spesifik
local function scanInterractables()
    local folder = workspace:FindFirstChild("Interractables")
    local target = folder and folder:GetDescendants() or workspace:GetDescendants()
    for _, obj in ipairs(target) do
        if obj:IsA("Model") then
            local label, color, espType = classifyByName(obj.Name)
            if label then
                addESP(obj, color, label, espType)
            end
        end
    end
end

-- Dump lengkap workspace untuk diagnostics
local function dumpWorkspace()
    log("=== WORKSPACE DUMP ===")
    for _, child in ipairs(workspace:GetChildren()) do
        log("[ws] " .. child.Name .. " (" .. child.ClassName .. ")")
        if child:IsA("Folder") or child:IsA("Model") then
            for _, sub in ipairs(child:GetChildren()) do
                log("  [ws] " .. sub.Name .. " (" .. sub.ClassName .. ")")
            end
        end
    end
    log("=== END DUMP ===")
end

local function scanPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local char = p.Character
            local isK = isKiller(p)
            if isK then
                if espData[char] then
                    if espData[char].type ~= "Killer" then
                        espData[char].type = "Killer"
                        espData[char].name = "KILLER"
                        if espData[char].hi then espData[char].hi.FillColor = Color3.fromRGB(255, 0, 0) end
                        if espData[char].lbl then espData[char].lbl.TextColor3 = Color3.fromRGB(255, 0, 0) end
                    end
                else
                    addESP(char, Color3.fromRGB(255, 0, 0), "KILLER", "Killer")
                end
            else
                if espData[char] then
                    if espData[char].type == "Killer" then
                        espData[char].type = "Survivor"
                        espData[char].name = p.DisplayName or p.Name
                        if espData[char].hi then espData[char].hi.FillColor = Color3.fromRGB(220, 220, 220) end
                        if espData[char].lbl then espData[char].lbl.TextColor3 = Color3.fromRGB(220, 220, 220) end
                    end
                else
                    addESP(char, Color3.fromRGB(220, 220, 220), p.DisplayName or p.Name, "Survivor")
                end
            end
        end
    end
end

-- Hook DescendantAdded di workspace/Interractables untuk objek yang spawn saat match mulai
local function hookInterractables()
    local folder = workspace:FindFirstChild("Interractables")
    local container = folder or workspace
    container.DescendantAdded:Connect(function(obj)
        if obj:IsA("Model") then
            task.wait(0.3)
            local label, color, espType = classifyByName(obj.Name)
            if label then
                addESP(obj, color, label, espType)
                log("ESP+: " .. obj.Name .. " => " .. label)
            end
        end
    end)
    scanInterractables()
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        task.wait(1.5)
        if isKiller(p) then addESP(char, Color3.fromRGB(255, 0, 0), "KILLER", "Killer")
        else addESP(char, Color3.fromRGB(220, 220, 220), p.DisplayName or p.Name, "Survivor") end
    end)
end)
Players.PlayerRemoving:Connect(function(p)
    if p.Character then removeESP(p.Character) end
end)

task.spawn(function()
    task.wait(3)
    hookInterractables()
    scanPlayers()
    -- Rescan setiap 2 detik agar tidak ketinggalan objek yang spawn terlambat
    while true do
        task.wait(2)
        pcall(scanPlayers)
    end
end)

-- Expose fungsi scan & dump ke global agar bisa dipanggil dari tombol GUI
_G.VD_ScanNow = function()
    pcall(dumpWorkspace)
    pcall(scanInterractables)
    pcall(scanPlayers)
    log("Manual scan complete.")
end


-- ─── Auto Repair ──────────────────────────────────────────────────────────────
-- Game menggunakan sistem interaksi custom (bukan ProximityPrompt standar).
-- Solusi: tahan tombol E terus-menerus.
task.spawn(function()
    local holding = false
    while true do
        task.wait(0.05)
        if GetOpt("AutoRepair", false) then
            if not holding then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                holding = true
            end
        else
            if holding then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                holding = false
            end
        end
    end
end)




-- ─── Auto Skill Check (UI & Spacebar Simulation) ─────────────────────────────
task.spawn(function()
    local activeGuiConnections = {}

    local function setupSolver(gui)
        if not gui then return end
        if activeGuiConnections[gui] then return end -- Avoid duplicate connections

        local check = gui:WaitForChild("Check", 10)
        if not check then return end
        
        local line = check:WaitForChild("Line", 10)
        local goal = check:WaitForChild("Goal", 10)
        if not line or not goal then return end
        
        local hasPressed = false
        local connection
        
        local function isLineInGoal()
            if not line or not goal then return false end
            local lr = line.Rotation % 360
            local gr = goal.Rotation % 360
            local gs = (gr + 104) % 360
            local ge = (gr + 114) % 360
            if gs > ge then
                return lr >= gs or lr <= ge
            else
                return lr >= gs and lr <= ge
            end
        end
        
        local function checkState()
            if not gui or not gui.Parent or not check or not check.Parent then
                if connection then
                    connection:Disconnect()
                    activeGuiConnections[gui] = nil
                end
                return
            end
            
            if not GetOpt("AutoSkillCheck", false) then 
                hasPressed = false
                return 
            end
            
            if check.Visible then
                if not hasPressed then
                    if isLineInGoal() then
                        hasPressed = true
                        log("Skill check target reached! Simulating spacebar press.")
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                        task.wait(0.01)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                    end
                end
            else
                hasPressed = false
            end
        end
        
        connection = RunService.Heartbeat:Connect(checkState)
        activeGuiConnections[gui] = connection
        
        log("Successfully hooked UI-based SkillCheck solver to " .. gui.Name)
    end

    -- Initial scan of existing GUIs
    for _, child in ipairs(playerGui:GetChildren()) do
        if child.Name == "SkillCheckPromptGui" or child.Name == "SkillCheckPromptGui-con" then
            pcall(setupSolver, child)
        end
    end

    -- Listen for future GUIs added to PlayerGui
    playerGui.ChildAdded:Connect(function(child)
        if child.Name == "SkillCheckPromptGui" or child.Name == "SkillCheckPromptGui-con" then
            task.wait(0.2)
            pcall(setupSolver, child)
        end
    end)
end)

-- ─── Pistol Crosshair ────────────────────────────────────────────────────────
local crosshairGui = nil
local function updateCrosshair(enabled)
    if enabled then
        if crosshairGui then pcall(function() crosshairGui:Destroy() end) end
        
        local success, err = pcall(function()
            local cg = pcall(game.GetService, game, "CoreGui") and game:GetService("CoreGui") or playerGui
            crosshairGui = Instance.new("ScreenGui")
            crosshairGui.Name = "VDCrosshairGui"
            crosshairGui.ResetOnSpawn = false
            crosshairGui.IgnoreGuiInset = true
            crosshairGui.Parent = cg
            
            -- Center Dot
            local centerDot = Instance.new("Frame")
            centerDot.Name = "CenterDot"
            centerDot.Size = UDim2.fromOffset(4, 4)
            centerDot.Position = UDim2.new(0.5, 0, 0.5, 0)
            centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
            centerDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            centerDot.BorderSizePixel = 0
            centerDot.Parent = crosshairGui
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.5, 0)
            corner.Parent = centerDot
            
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.new(0, 0, 0)
            stroke.Thickness = 1
            stroke.Parent = centerDot

            -- 4 crosshair bars around center
            local offsets = {
                Top = {Size = UDim2.fromOffset(2, 6), Pos = UDim2.new(0.5, 0, 0.5, -7)},
                Bottom = {Size = UDim2.fromOffset(2, 6), Pos = UDim2.new(0.5, 0, 0.5, 7)},
                Left = {Size = UDim2.fromOffset(6, 2), Pos = UDim2.new(0.5, -7, 0.5, 0)},
                Right = {Size = UDim2.fromOffset(6, 2), Pos = UDim2.new(0.5, 7, 0.5, 0)}
            }
            
            for name, cfg in pairs(offsets) do
                local line = Instance.new("Frame")
                line.Name = name
                line.Size = cfg.Size
                line.Position = cfg.Pos
                line.AnchorPoint = Vector2.new(0.5, 0.5)
                line.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                line.BorderSizePixel = 0
                line.Parent = crosshairGui
                
                local lineStroke = Instance.new("UIStroke")
                lineStroke.Color = Color3.new(0, 0, 0)
                lineStroke.Thickness = 1
                lineStroke.Parent = line
            end
        end)
        if not success then
            log("Error creating crosshair UI: " .. tostring(err))
        end
    else
        if crosshairGui then
            pcall(function() crosshairGui:Destroy() end)
            crosshairGui = nil
        end
    end
end



-- ─── Killer Auto Attack ───────────────────────────────────────────────────────
task.spawn(function()
    while task.wait(0.3) do
        if GetOpt("AutoAttack",false) and isKiller(player) then
            pcall(function()
                local hrp=getHRP(); if not hrp then return end
                local nearest,minD=nil,math.huge
                for _,p in ipairs(Players:GetPlayers()) do
                    if p~=player and p.Character then
                        local sHrp=p.Character:FindFirstChild("HumanoidRootPart")
                        if sHrp then
                            local d=(hrp.Position-sHrp.Position).Magnitude
                            if d<minD and not isKiller(p) then minD=d; nearest=sHrp end
                        end
                    end
                end
                if nearest and minD<=15 then
                    hrp.CFrame=CFrame.new(hrp.Position, Vector3.new(nearest.Position.X, hrp.Position.Y, nearest.Position.Z))
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
                end
            end)
        end
    end
end)

-- ─── Movement ─────────────────────────────────────────────────────────────────
local function updateSpeed(val)
    autoSave()
    pcall(function()
        local hum = getHum()
        if hum then
            if GetOpt("SpeedToggle", false) then
                hum.WalkSpeed = val
            else
                hum.WalkSpeed = GameIntendedSpeed
            end
        end
    end)
end

RunService.PreSimulation:Connect(function()
    local enabled = GetOpt("SpeedToggle", false)
    if enabled then
        local hum = getHum()
        if hum then
            local spd = GetOpt("SpeedSlider", 16)
            pcall(function()
                if hum.WalkSpeed ~= spd then
                    hum.WalkSpeed = spd
                end
            end)
        end
    end
    -- Infinite Stamina
    pcall(function()
        local c = getChar()
        if not c then return end
        local st = c:FindFirstChild("Stamina") or c:FindFirstChild("Energy")
        if st and st:IsA("ValueBase") then st.Value = 100 end
    end)
end)

local wasNoclip = false
RunService.Stepped:Connect(function()
    local isNoclip = GetOpt("Noclip", false)
    if isNoclip then
        wasNoclip = true
        pcall(function()
            local c = getChar()
            if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end)
    else
        if wasNoclip then
            wasNoclip = false
            pcall(function()
                local c = getChar()
                if not c then return end
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then
                        if p.Name ~= "HumanoidRootPart" then
                            p.CanCollide = true
                        end
                    end
                end
            end)
        end
    end
end)

-- ─── Legit Dash (Gocek Killer) ───────────────────────────────────────────────
local isDashing = false
local function performDash(direction, speed, duration)
    if isDashing then return end
    isDashing = true
    
    local hum = getHum()
    local myHrp = getHRP()
    if hum and myHrp then
        local oldSpeedToggle = GetOpt("SpeedToggle", false)
        local oldSpeedSlider = GetOpt("SpeedSlider", 16)
        
        if speedToggle and speedSlider then
            speedToggle:SetValue(true)
            speedSlider:SetValue(speed)
        else
            hum.WalkSpeed = speed
        end
        
        local startTime = os.clock()
        local conn
        conn = RunService.PreSimulation:Connect(function()
            if os.clock() - startTime > duration then
                conn:Disconnect()
                if speedToggle and speedSlider then
                    speedToggle:SetValue(oldSpeedToggle)
                    speedSlider:SetValue(oldSpeedSlider)
                else
                    if oldSpeedToggle then
                        hum.WalkSpeed = oldSpeedSlider
                    else
                        hum.WalkSpeed = GameIntendedSpeed
                    end
                end
                isDashing = false
            else
                if not (speedToggle and speedSlider) then
                    hum.WalkSpeed = speed
                end
                hum:Move(direction, false)
            end
        end)
    else
        isDashing = false
    end
end

-- ─── Auto Gocek Killer Loop ──────────────────────────────────────────────────
task.spawn(function()
    local lastAutoJukeTime = 0
    while task.wait(0.05) do
        if GetOpt("AutoJuke", false) then
            pcall(function()
                local myHrp = getHRP()
                local killerChar = getKillerChar()
                local kHrp = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
                if myHrp and kHrp then
                    local dist = (myHrp.Position - kHrp.Position).Magnitude
                    -- Jarak 1 meter (sekitar 5.5 studs)
                    if dist <= 5.5 then
                        local now = os.clock()
                        if now - lastAutoJukeTime > 2 then
                            lastAutoJukeTime = now
                            local mode = GetOpt("JukeMode", "Legit Dash")
                            
                            if mode == "Legit Dash" then
                                local hum = getHum()
                                if hum then
                                    local dir = hum.MoveDirection
                                    if dir.Magnitude < 0.1 then
                                        dir = (myHrp.Position - kHrp.Position) * Vector3.new(1, 0, 1)
                                    end
                                    if dir.Magnitude > 0.1 then
                                        performDash(dir.Unit, 45, 0.4)
                                        Fluent:Notify({Title="Auto Gocek!", Content="Lari menghindar dari Killer!", Duration=2})
                                    end
                                end
                            elseif mode == "Behind Killer" then
                                myHrp.CFrame = kHrp.CFrame * CFrame.new(0, 0, 8)
                                Fluent:Notify({Title="Auto Gocek!", Content="Mencoba menghindar ke belakang Killer!", Duration=2})
                            elseif mode == "Nearest Pallet" then
                                local pallet = getNearestPallet()
                                if pallet then
                                    myHrp.CFrame = pallet.CFrame + Vector3.new(0, 3, 0)
                                    Fluent:Notify({Title="Auto Gocek!", Content="Teleport ke Pallet terdekat!", Duration=2})
                                end
                            elseif mode == "Backward Dash" then
                                myHrp.CFrame = myHrp.CFrame * CFrame.new(0, 0, 15)
                                Fluent:Notify({Title="Auto Gocek!", Content="Backward Dash!", Duration=2})
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- ─── Gocek Killer Listener ───────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local bind = GetOpt("JukeKey", Enum.KeyCode.V)
    if typeof(bind) == "string" then
        pcall(function() bind = Enum.KeyCode[bind] end)
    end
    if input.KeyCode == bind then
        pcall(function()
            local mode = GetOpt("JukeMode", "Legit Dash")
            local myHrp = getHRP(); if not myHrp then return end
            
            if mode == "Legit Dash" then
                local hum = getHum()
                if hum then
                    local dir = hum.MoveDirection
                    if dir.Magnitude < 0.1 then
                        local killerChar = getKillerChar()
                        local kHrp = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
                        if kHrp then
                            dir = (myHrp.Position - kHrp.Position) * Vector3.new(1, 0, 1)
                        else
                            dir = -myHrp.CFrame.LookVector
                        end
                    end
                    if dir.Magnitude > 0.1 then
                        performDash(dir.Unit, 45, 0.4)
                        Fluent:Notify({Title="Gocek!", Content="Lari menghindar!", Duration=2})
                    end
                end
            elseif mode == "Behind Killer" then
                local killerChar = getKillerChar()
                local kHrp = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
                if kHrp then
                    myHrp.CFrame = kHrp.CFrame * CFrame.new(0, 0, 8)
                    Fluent:Notify({Title="Gocek!", Content="Teleport di belakang Killer!", Duration=2})
                else
                    Fluent:Notify({Title="Error", Content="Killer tidak ditemukan!", Duration=2})
                end
            elseif mode == "Nearest Pallet" then
                local pallet = getNearestPallet()
                if pallet then
                    myHrp.CFrame = pallet.CFrame + Vector3.new(0, 3, 0)
                    Fluent:Notify({Title="Gocek!", Content="Teleport ke Pallet terdekat!", Duration=2})
                else
                    Fluent:Notify({Title="Error", Content="Pallet tidak ditemukan!", Duration=2})
                end
            elseif mode == "Backward Dash" then
                myHrp.CFrame = myHrp.CFrame * CFrame.new(0, 0, 15)
                Fluent:Notify({Title="Gocek!", Content="Backward Dash!", Duration=2})
            end
        end)
    end
end)

-- ─── GUI Build ────────────────────────────────────────────────────────────────
-- Survivor Tab
local surSec=Tabs.Survivor:AddSection("Automation")
surSec:AddToggle("AutoRepair",     {Title="Auto Repair Generator", Default=false, Callback=autoSave})
surSec:AddToggle("AutoSkillCheck", {Title="Auto Skill Check (Perfect)", Default=false, Callback=autoSave})
surSec:AddToggle("PistolAimbot",   {Title="Pistol Auto Hit (Silent Aim)", Default=false, Callback=autoSave})
surSec:AddToggle("PistolCrosshair", {Title="Pistol Crosshair", Default=false, Callback=function(val)
    autoSave()
    updateCrosshair(val)
end})

local parrySec = Tabs.Survivor:AddSection("Auto Parry (Anti-Killer)")
parrySec:AddToggle("AutoParry", {Title="⚡ Auto Parry", Default=false, Callback=autoSave})
parrySec:AddDropdown("ParryMode", {Title="Parry Mode", Values={"Tool Activate", "Key F", "Both"}, Default="Both", Callback=autoSave})
parrySec:AddSlider("ParryDistance", {Title="Parry Distance (studs)", Min=5, Max=25, Default=12, Rounding=0, Callback=autoSave})

-- Killer Tab
local kilSec=Tabs.Killer:AddSection("Automation")
kilSec:AddToggle("AutoAttack",  {Title="Auto Attack Survivor", Default=false, Callback=autoSave})

-- ESP Tab
local espSec=Tabs.Visuals:AddSection("ESP Objects")
espSec:AddToggle("EspGen",    {Title="Generators",  Default=false, Callback=autoSave})
espSec:AddToggle("EspPallet", {Title="Pallets",     Default=false, Callback=autoSave})
espSec:AddToggle("EspGate",   {Title="Exit Gates",  Default=false, Callback=autoSave})
local espPSec=Tabs.Visuals:AddSection("ESP Players")
espPSec:AddToggle("EspKiller", {Title="Killer",     Default=false, Callback=autoSave})
espPSec:AddToggle("EspSurv",   {Title="Survivors",  Default=false, Callback=autoSave})
Tabs.Visuals:AddSlider("EspDist", {Title="Max Distance (studs)", Min=50, Max=2000, Default=1000, Rounding=0, Callback=autoSave})
local diagSec=Tabs.Visuals:AddSection("Diagnostics")
diagSec:AddButton({Title="Scan Now (Lihat di Console)", Callback=function()
    if _G.VD_ScanNow then _G.VD_ScanNow()
    else log("Scan function not ready yet.") end
end})

-- Movement Tab
local movSec=Tabs.Movement:AddSection("Movement")
speedToggle = movSec:AddToggle("SpeedToggle", {Title="Speed Hack", Default=false, Callback=function(val)
    autoSave()
    updateSpeed(GetOpt("SpeedSlider", 16))
end})
speedSlider = movSec:AddSlider("SpeedSlider", {Title="Walk Speed", Min=16, Max=150, Default=16, Rounding=0, Callback=updateSpeed})
movSec:AddToggle("Noclip",      {Title="Noclip (tembus dinding)", Default=false, Callback=autoSave})

local jukeSec = Tabs.Movement:AddSection("Gocek Killer")
jukeSec:AddDropdown("JukeMode", {Title="Juke Mode", Values={"Legit Dash", "Behind Killer", "Nearest Pallet", "Backward Dash"}, Default="Legit Dash", Callback=autoSave})
jukeSec:AddToggle("AutoJuke", {Title="Auto Gocek (Jarak 1 Meter)", Default=false, Callback=autoSave})
jukeSec:AddKeybind("JukeKey", {Title="Juke Trigger Key", Default="V"})

-- Settings Tab
Tabs.Settings:AddButton({Title="Close / Unload", Callback=function()
    Fluent:Destroy()
    pcall(function() game:GetService("CoreGui"):FindFirstChild("VDToggleGui"):Destroy() end)
    pcall(function() updateCrosshair(false) end)
end})

SM:SetLibrary(Fluent); IM:SetLibrary(Fluent)
SM:IgnoreThemeSettings()
SM:SetFolder("ViolenceDistrict")
SM:BuildConfigSection(Tabs.Settings)
IM:SetFolder("ViolenceDistrictSettings")
IM:BuildInterfaceSection(Tabs.Settings)
Window:SelectTab(1)
-- SM:LoadAutoloadConfig()

task.spawn(function()
    task.wait(1.5)
    updateCrosshair(GetOpt("PistolCrosshair", false))
end)

Fluent:Notify({
    Title="Violence District Hub v3.0",
    Content="Siap! Auto Skill Check & ESP aktif. Masuk match dan aktifkan fitur yang diinginkan.",
    Duration=8
})
log("Violence District Hub v3.0 loaded successfully.")

-- Loop 7: Auto Parry against Killer attacks
task.spawn(function()
    local lastParryTime = 0
    local standardMovementAnimations = {
        ["walk"] = true, ["run"] = true, ["idle"] = true, ["jump"] = true,
        ["fall"] = true, ["strafe"] = true, ["stamina"] = true,
        ["breathe"] = true, ["pant"] = true, ["swim"] = true, ["climb"] = true
    }
    
    local function isAttackAnimation(track)
        local name = tostring(track.Name or (track.Animation and track.Animation.Name) or ""):lower()
        -- Skip standard animations
        for moveName, _ in pairs(standardMovementAnimations) do
            if name:find(moveName) then
                return false
            end
        end
        return true
    end

    while true do
        task.wait(0.05) -- Check 20 times per second for quick reaction
        if GetOpt("AutoParry", false) then
            pcall(function()
                local myChar = getChar()
                local myHrp = getHRP()
                if not myChar or not myHrp then return end
                
                -- Check cooldown to avoid spamming activate calls
                local now = os.clock()
                if now - lastParryTime < 2 then return end
                
                -- Find nearest killer
                local nearestKiller, dist = nil, math.huge
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player and isKiller(p) and p.Character then
                        local kHrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if kHrp then
                            local d = (myHrp.Position - kHrp.Position).Magnitude
                            if d < dist then
                                dist = d
                                nearestKiller = p.Character
                            end
                        end
                    end
                end
                
                local parryDist = GetOpt("ParryDistance", 12)
                if nearestKiller and dist <= parryDist then
                    local humanoid = nearestKiller:FindFirstChildOfClass("Humanoid")
                    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
                    if animator then
                        local attacking = false
                        local activeAnimName = ""
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            if isAttackAnimation(track) then
                                attacking = true
                                activeAnimName = tostring(track.Name or (track.Animation and track.Animation.Name) or "Unknown")
                                break
                            end
                        end
                        
                        if attacking then
                            lastParryTime = now
                            log("Killer attack detected: " .. activeAnimName .. " at dist " .. math.round(dist) .. " studs! Triggering parry.")
                            
                            local mode = GetOpt("ParryMode", "Both")
                            
                            -- 1. Tool Activation Mode
                            if mode == "Tool Activate" or mode == "Both" then
                                local bp = player:FindFirstChild("Backpack")
                                local dagger = myChar:FindFirstChild("Parrying Dagger") or myChar:FindFirstChild("ParryingDagger")
                                if not dagger and bp then
                                    for _, t in ipairs(bp:GetChildren()) do
                                        if t:IsA("Tool") and (t.Name:lower():find("parry") or t.Name:lower():find("dagger") or t.Name:lower():find("tangkis")) then
                                            dagger = t
                                            break
                                        end
                                    end
                                end
                                
                                -- Relaxed search for any tool if no specific parry dagger found
                                if not dagger and bp then
                                    for _, t in ipairs(bp:GetChildren()) do
                                        if t:IsA("Tool") then
                                            dagger = t
                                            break
                                        end
                                    end
                                end
                                
                                if dagger then
                                    if dagger.Parent == bp then
                                        dagger.Parent = myChar
                                        task.wait(0.02)
                                    end
                                    pcall(function() dagger:Activate() end)
                                end
                            end
                            
                            -- 2. Key Press Mode
                            if mode == "Key F" or mode == "Both" then
                                pcall(function()
                                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                                    task.wait(0.05)
                                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                                end)
                            end
                            
                            -- Prevent multiple triggers in the same frame
                            task.wait(0.5)
                        end
                    end
                end
            end)
        end
    end
end)
