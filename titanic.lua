loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local lib = require(game.ReplicatedStorage.Library)

local fromPet = "Whale Shark"
local toPet = "Titanic Monkey"

for i,v in pairs(lib.Directory.Pets[fromPet]) do
  lib.Directory.Pets[fromPet][i] = nil
end
for i,v in pairs(lib.Directory.Pets[toPet]) do
  lib.Directory.Pets[fromPet][i] = v
end
