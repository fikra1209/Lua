--[[
    Violence District Automation Hub — Premium Edition
    Developed by Antigravity AI

    Features:
    - Self-Healing Library Loader (multi CDN mirror fallback)
    - Draggable Floating "VD" Toggle Button
    - Auto Skill Check (Space key press emulator)
    - Auto Repair Generator (ProximityPrompt automation)
    - Extrasensory Perception (ESP) for Killer, Survivors, Generators, Pallets, and Gates
    - Speed Hack, Infinite Stamina, and Noclip
    - SaveManager + InterfaceManager Fluent integration
]]

if game.GameId ~= 6739698191 and game.PlaceId ~= 93978595733734 then
    return
end

-- ─── Initialization ──────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local RunService        = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService  = game:GetService("UserInputService")

local player = Players.LocalPlayer
while not player do
    task.wait(0.1)
    player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui", 30)
if not playerGui then return end


local function debugPrint(msg)
    local text = "[Violence District Bot] " .. tostring(msg)
    print(text); warn(text)
    pcall(function() if rconsoleprint then rconsoleprint(text.."\n") end end)
end

debugPrint("Initializing script...")

pcall(function()
    task.spawn(function()
        task.wait(3) -- Tunggu game dimuat
        local result = "[Violence District Diagnostics]\n"
        
        -- Pindai workspace children
        result = result .. "--- Workspace Children ---\n"
        for _, child in ipairs(workspace:GetChildren()) do
            result = result .. "Name: " .. child.Name .. " (Class: " .. child.ClassName .. ")\n"
        end
        
        -- Pindai ProximityPrompt
        result = result .. "\n--- Proximity Prompts ---\n"
        local promptCount = 0
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                promptCount = promptCount + 1
                result = result .. "Prompt: " .. desc:GetFullName() 
                    .. " | ObjectText: " .. tostring(desc.ObjectText) 
                    .. " | ActionText: " .. tostring(desc.ActionText) .. "\n"
            end
        end
        result = result .. "Total Prompts found: " .. promptCount .. "\n"
        
        -- Pindai PlayerGui ScreenGuis
        result = result .. "\n--- PlayerGui ScreenGuis ---\n"
        for _, gui in ipairs(playerGui:GetChildren()) do
            result = result .. "Gui: " .. gui.Name .. " (Enabled: " .. tostring(gui.Enabled) .. ")\n"
            -- Cetak child yang mencurigakan (seperti frame atau indicator)
            for _, child in ipairs(gui:GetDescendants()) do
                local cName = child.Name:lower()
                if cName:find("check") or cName:find("minigame") or cName:find("needle") or cName:find("indicator") or cName:find("zone") or cName:find("qte") or cName:find("hit") or cName:find("bar") or cName:find("pointer") then
                    result = result .. "  -> Child: " .. child:GetFullName() .. " (Class: " .. child.ClassName .. ")\n"
                end
            end
        end
        
        writefile("VD_Diagnostics.txt", result)
        debugPrint("Diagnostics saved to VD_Diagnostics.txt")
    end)
end)

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

local fluentRaw, fluentCompiled = loadLibrary("SH_Fluent.lua", Fluent_URLs) -- Menggunakan cache yang sama
if not fluentRaw or not fluentCompiled then
    debugPrint("CRITICAL: Failed to load Fluent!"); return
end

local loadOk, Fluent = pcall(fluentCompiled)
if not loadOk or not Fluent then
    debugPrint("CRITICAL: Fluent exec failed: "..tostring(Fluent)); return
end

-- ─── Interface & Save Manager (Inlined) ──────────────────────────────────────
local InterfaceManager = {} do
    InterfaceManager.Folder   = "ViolenceDistrictSettings"
    InterfaceManager.Settings = { Theme="Dark", Acrylic=true, Transparency=true, MenuKeybind="LeftControl" }
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

local SaveManager = {} do
    SaveManager.Folder = "ViolenceDistrictSettings"
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
    Title="Violence District Bot", SubTitle="LuxvS Hub",
    TabWidth=160, Size=UDim2.fromOffset(580,480),
    Acrylic=true, Theme="Dark",
    MinimizeKey=Enum.KeyCode.LeftControl
})

-- ─── Floating Toggle Button ──────────────────────────────────────────────────
pcall(function()
    local cg = game:GetService("CoreGui")
    local old = cg:FindFirstChild("ViolenceDistrictToggleGui")
    if old then old:Destroy() end
    local gui = Instance.new("ScreenGui"); gui.Name="ViolenceDistrictToggleGui"
    gui.ResetOnSpawn=false; gui.Parent=cg
    local btn = Instance.new("TextButton"); btn.Parent=gui
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
    Survivor  = Window:AddTab({ Title="Survivor",  Icon="user" }),
    Killer    = Window:AddTab({ Title="Killer",    Icon="skull" }),
    Visuals   = Window:AddTab({ Title="ESP Visuals",Icon="eye" }),
    Movement  = Window:AddTab({ Title="Movement",  Icon="wind" }),
    Settings  = Window:AddTab({ Title="Settings",  Icon="settings" }),
}

local function GetOption(key, fallback)
    local opt = Fluent.Options[key]
    if opt then return opt.Value end
    return fallback
end

local function autoSave()
    local name = GetOption("SaveConfigName", "default")
    if name == "" then name = "default" end
    pcall(function() SaveManager:Save(name) end)
end

-- ─── Helper Functions ────────────────────────────────────────────────────────
local function getCharacter()
    return player.Character
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ─── ESP System ──────────────────────────────────────────────────────────────
local espObjects = {}

local function createESP(instance, color, labelText, espType)
    if espObjects[instance] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Parent = instance
    highlight.FillColor = color
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0.1
    
    local bgui = Instance.new("BillboardGui")
    bgui.Name = "ESP_Label"
    bgui.AlwaysOnTop = true
    bgui.Size = UDim2.new(0, 120, 0, 30)
    bgui.Adornee = instance:IsA("Model") and (instance.PrimaryPart or instance:FindFirstChildOfClass("BasePart")) or instance
    bgui.Parent = instance
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.2
    label.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.Text = labelText
    label.Parent = bgui
    
    espObjects[instance] = {
        highlight = highlight,
        bgui = bgui,
        label = label,
        name = labelText,
        type = espType
    }
end

local function removeESP(instance)
    local data = espObjects[instance]
    if data then
        pcall(function() data.highlight:Destroy() end)
        pcall(function() data.bgui:Destroy() end)
        espObjects[instance] = nil
    end
end

-- Pendeteksi Killer pintar via atribut atau Red Stain Light
local function isPlayerKiller(p)
    if not p or p == player then return false end
    local char = p.Character
    if char then
        -- Cek Red Light khas Killer
        for _, light in ipairs(char:GetDescendants()) do
            if light:IsA("Light") and (light.Color == Color3.fromRGB(255,0,0) or light.Color == Color3.fromRGB(200,0,0)) then
                return true
            end
        end
        -- Cek nama model atau senjata
        if char:FindFirstChild("Weapon") or char:FindFirstChild("Axe") or char:FindFirstChild("Knife") then
            return true
        end
    end
    return false
end

-- Loop ESP update posisi/jarak
task.spawn(function()
    while task.wait(0.2) do
        local hrp = getHRP()
        for inst, data in pairs(espObjects) do
            if not inst or not inst.Parent then
                espObjects[inst] = nil
            else
                local targetPart = inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")) or inst
                if targetPart and hrp then
                    local dist = math.round((hrp.Position - targetPart.Position).Magnitude)
                    data.label.Text = data.name .. " [" .. dist .. "m]"
                    
                    -- Filter visibilitas berdasarkan pengaturan tab Visuals
                    local show = false
                    local limit = GetOption("EspDistanceLimit", 500) or 500
                    
                    if dist <= limit then
                        if data.type == "Generator" and GetOption("EspGenerators", false) then show = true
                        elseif data.type == "Killer" and GetOption("EspKiller", false) then show = true
                        elseif data.type == "Survivor" and GetOption("EspSurvivors", false) then show = true
                        elseif data.type == "Pallet" and GetOption("EspPallets", false) then show = true
                        elseif data.type == "Gate" and GetOption("EspGates", false) then show = true
                        end
                    end
                    
                    data.highlight.Enabled = show
                    data.bgui.Enabled = show
                end
            end
        end
    end
end)

-- Scan & daftarkan objek ke ESP secara dinamis
local function scanObjects()
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local objText = tostring(desc.ObjectText):lower()
            local actText = tostring(desc.ActionText):lower()
            local parentName = tostring(desc.Parent and desc.Parent.Name or ""):lower()
            
            -- Deteksi Generator
            if objText:find("generator") or objText:find("mesin") or actText:find("repair") or parentName:find("generator") then
                local model = desc:FindFirstAncestorOfClass("Model") or desc.Parent
                if model then createESP(model, Color3.fromRGB(0, 180, 255), "Generator", "Generator") end
            
            -- Deteksi Pallet
            elseif objText:find("pallet") or parentName:find("pallet") or parentName:find("plank") then
                local model = desc:FindFirstAncestorOfClass("Model") or desc.Parent
                if model then createESP(model, Color3.fromRGB(230, 180, 50), "Pallet", "Pallet") end
            
            -- Deteksi Pintu Keluar
            elseif objText:find("gate") or objText:find("exit") or parentName:find("gate") or parentName:find("door") then
                local model = desc:FindFirstAncestorOfClass("Model") or desc.Parent
                if model then createESP(model, Color3.fromRGB(0, 255, 100), "Exit Gate", "Gate") end
            end
        end
    end
    
    -- Daftarkan Player
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            if isPlayerKiller(p) then
                createESP(p.Character, Color3.fromRGB(255, 50, 50), "KILLER", "Killer")
            else
                createESP(p.Character, Color3.fromRGB(200, 200, 200), p.DisplayName or p.Name, "Survivor")
            end
        end
    end
end

-- Hubungkan Event agar Player baru otomatis terdaftar ESP
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        task.wait(1)
        if isPlayerKiller(p) then
            createESP(char, Color3.fromRGB(255, 50, 50), "KILLER", "Killer")
        else
            createESP(char, Color3.fromRGB(200, 200, 200), p.DisplayName or p.Name, "Survivor")
        end
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    if p.Character then removeESP(p.Character) end
end)

-- Scan berkala untuk objek yang baru spawn
task.spawn(function()
    while true do
        pcall(scanObjects)
        task.wait(5)
    end
end)

-- ─── Survivor Automation ─────────────────────────────────────────────────────
local function getNearestGenerator()
    local nearest = nil
    local minDist = math.huge
    local hrp = getHRP()
    if not hrp then return nil end
    
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local objText = tostring(desc.ObjectText):lower()
            local parentName = tostring(desc.Parent and desc.Parent.Name or ""):lower()
            if objText:find("generator") or objText:find("mesin") or parentName:find("generator") then
                local basePart = desc:FindFirstAncestorOfClass("BasePart") or desc.Parent
                if basePart and basePart:IsA("BasePart") then
                    local dist = (hrp.Position - basePart.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearest = desc
                    end
                end
            end
        end
    end
    return nearest
end

-- Loop Auto Repair
task.spawn(function()
    while task.wait(1) do
        if GetOption("AutoRepair", false) then
            pcall(function()
                local prompt = getNearestGenerator()
                local hrp = getHRP()
                local char = getCharacter()
                if prompt and hrp and char then
                    local basePart = prompt:FindFirstAncestorOfClass("BasePart") or prompt.Parent
                    if basePart then
                        -- Teleport di dekat generator
                        char:PivotTo(basePart.CFrame + Vector3.new(0, 1.5, 0))
                        task.wait(0.2)
                        
                        -- Picu ProximityPrompt perbaikan
                        local oldHold = prompt.HoldDuration
                        prompt.HoldDuration = 0
                        fireproximityprompt(prompt)
                        prompt.HoldDuration = oldHold
                    end
                end
            end)
        end
    end
end)

-- Auto Skill Check (Space key press emulator)
task.spawn(function()
    while task.wait(0.05) do
        if GetOption("AutoSkillCheck", false) then
            pcall(function()
                -- Cari ScreenGui Skill Check secara dinamis
                for _, gui in ipairs(playerGui:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled then
                        -- Mencocokkan nama UI umum
                        local frame = gui:FindFirstChild("SkillCheck", true) 
                            or gui:FindFirstChild("Minigame", true) 
                            or gui:FindFirstChild("CheckFrame", true)
                        
                        if frame and frame.Visible then
                            local needle = frame:FindFirstChild("Needle", true) or frame:FindFirstChild("Indicator", true)
                            local zone = frame:FindFirstChild("SuccessZone", true) or frame:FindFirstChild("SafeZone", true) or frame:FindFirstChild("Zone", true)
                            
                            if needle and zone then
                                local needleRot = needle.Rotation % 360
                                local zoneRot = zone.Rotation % 360
                                local size = 20
                                if zone:FindFirstChild("Size") then
                                    size = zone.Size.Value
                                elseif zone:IsA("GuiObject") then
                                    size = (zone.Size.X.Offset > 0) and (zone.Size.X.Offset / 2) or 20
                                end
                                
                                -- Deteksi posisi presisi jarum dalam safe zone
                                local diff = math.abs(needleRot - zoneRot)
                                if diff <= size or (360 - diff) <= size then
                                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                                    task.wait(0.02)
                                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                                    task.wait(0.4) -- Cooldown proteksi double press
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- ─── Killer Automation ───────────────────────────────────────────────────────
local function getNearestSurvivor()
    local nearest = nil
    local minDist = math.huge
    local hrp = getHRP()
    if not hrp then return nil end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local sHrp = p.Character:FindFirstChild("HumanoidRootPart")
            if sHrp then
                local dist = (hrp.Position - sHrp.Position).Magnitude
                if dist < minDist and not isPlayerKiller(p) then
                    minDist = dist
                    nearest = p.Character
                end
            end
        end
    end
    return nearest
end

-- Auto Attack
task.spawn(function()
    while task.wait(0.5) do
        if GetOption("AutoAttack", false) and isPlayerKiller(player) then
            pcall(function()
                local nearest = getNearestSurvivor()
                local hrp = getHRP()
                if nearest and hrp then
                    local sHrp = nearest:FindFirstChild("HumanoidRootPart")
                    if sHrp then
                        local dist = (hrp.Position - sHrp.Position).Magnitude
                        if dist <= 12 then -- Rentang jarak serang
                            -- Kirim virtual klik mouse1 untuk memicu senjata
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                            task.wait(0.05)
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                        end
                    end
                end
            end)
        end
    end
end)

-- ─── Movement hacks ──────────────────────────────────────────────────────────
local connectionNoclip
task.spawn(function()
    while task.wait(0.1) do
        -- WalkSpeed & JumpPower
        local hum = getHumanoid()
        if hum then
            local speed = GetOption("WalkSpeedSlider", 16)
            local jump = GetOption("JumpPowerSlider", 50)
            if speed ~= 16 then hum.WalkSpeed = speed end
            if jump ~= 50 then hum.JumpPower = jump end
        end
        
        -- Infinite Stamina (Bypass Stamina Value jika ada)
        pcall(function()
            local char = getCharacter()
            local stamina = char and (char:FindFirstChild("Stamina") or char:FindFirstChild("Energy"))
            if stamina and stamina:IsA("ValueBase") then
                stamina.Value = 100
            end
            local stats = player:FindFirstChild("leaderstats") or player:FindFirstChild("PlayerGui")
            local st = stats and stats:FindFirstChild("Stamina", true)
            if st and st:IsA("ValueBase") then st.Value = 100 end
        end)
    end
end)

-- Noclip loop
RunService.Stepped:Connect(function()
    if GetOption("NoclipToggle", false) then
        pcall(function()
            local char = getCharacter()
            if char then
                for _, part in ipairs(char:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end)

-- ─── GUI Layout Setup ────────────────────────────────────────────────────────
-- Tab Survivor
Tabs.Survivor:AddToggle("AutoRepair",      { Title="▶ Auto Repair Generator", Default=false, Callback = autoSave })
Tabs.Survivor:AddToggle("AutoSkillCheck",  { Title="▶ Auto Skill Check (100% Perfect)", Default=false, Callback = autoSave })

-- Tab Killer
Tabs.Killer:AddToggle("AutoAttack",        { Title="▶ Auto Attack Nearest Survivor", Default=false, Callback = autoSave })

-- Tab Visuals
Tabs.Visuals:AddToggle("EspGenerators",    { Title="Show Generators", Default=false, Callback = autoSave })
Tabs.Visuals:AddToggle("EspKiller",        { Title="Show Killer",     Default=false, Callback = autoSave })
Tabs.Visuals:AddToggle("EspSurvivors",     { Title="Show Survivors",  Default=false, Callback = autoSave })
Tabs.Visuals:AddToggle("EspPallets",       { Title="Show Pallets",    Default=false, Callback = autoSave })
Tabs.Visuals:AddToggle("EspGates",         { Title="Show Exit Gates", Default=false, Callback = autoSave })
Tabs.Visuals:AddSlider("EspDistanceLimit", { Title="ESP Distance Limit (studs)", Min=100, Max=2000, Default=1000, Rounding=0, Callback = autoSave })

-- Tab Movement
Tabs.Movement:AddSlider("WalkSpeedSlider", { Title="Walk Speed Override", Min=16, Max=120, Default=16, Rounding=0, Callback = autoSave })
Tabs.Movement:AddSlider("JumpPowerSlider", { Title="Jump Power Override", Min=50, Max=250, Default=50, Rounding=0, Callback = autoSave })
Tabs.Movement:AddToggle("NoclipToggle",    { Title="Noclip (Pass through walls)", Default=false, Callback = autoSave })

-- Tab Settings
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetFolder("ViolenceDistrict")
SaveManager:BuildConfigSection(Tabs.Settings)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()

Fluent:Notify({
    Title   = "Violence District Hub",
    Content = "Script loaded successfully! Happy surviving/hunting!",
    Duration= 8
})
