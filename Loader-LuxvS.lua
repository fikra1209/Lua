repeat task.wait() until game:IsLoaded()

local Universal = "https://raw.githubusercontent.com/fikra1209/Lua/main/keyless/Universal.lua"
local Games = {
    [89469502395769]  = "https://raw.githubusercontent.com/louissxe/Lua/main/keyless/kickalucky.lua",
    [92416421522960]  = "https://raw.githubusercontent.com/louissxe/Lua/main/keyless/slimerng.lua",
    [70845479499574]  = "https://raw.githubusercontent.com/louissxe/Lua/main/keyless/bitebynight.lua",
    [130274245431977] = "https://raw.githubusercontent.com/louissxe/Lua/main/keyless/ClimbAndPlunge.lua",
    [117381420723145] = "https://raw.githubusercontent.com/fikra1209/Lua/main/keyless/summon_heroes.lua", -- Lobby SH
    [93978595733734]  = "https://raw.githubusercontent.com/fikra1209/Lua/main/keyless/violence_district.lua", -- Violence District
}

-- Deteksi pintar jika masuk arena battle Summon Heroes
local url = Games[game.PlaceId]
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
if not url and remotes and remotes:FindFirstChild("Waves_Ready") then
    url = "https://raw.githubusercontent.com/fikra1209/Lua/main/keyless/summon_heroes.lua"
end

loadstring(game:HttpGet(url or Universal))()
