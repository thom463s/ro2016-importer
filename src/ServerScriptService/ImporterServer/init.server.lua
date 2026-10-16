local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Importer = require(script.Importer)

local MAX_TOKENS_PER_CHUNK = 2000000
local ROOT_SERVICES = {
	ScreenGui = "StarterGui",
	Team = "Teams",
	Sky = "Lighting",
}

local remotes = ReplicatedStorage:FindFirstChild("ImporterRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "ImporterRemotes"
	remotes.Parent = ReplicatedStorage
end

local function getRemote(name)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local sendDataEvent = getRemote("SendImportData")
local runImportEvent = getRemote("RunImport")

local pendingImports = {}

sendDataEvent.OnServerEvent:connect(function(player, tokens)
	if type(tokens) ~= "table" then return end
	if #tokens == 0 or #tokens > MAX_TOKENS_PER_CHUNK then return end

	pendingImports[player] = pendingImports[player] or {}
	table.insert(pendingImports[player], tokens)

	print("Importer: received chunk", #pendingImports[player], "|", #tokens, "values")
end)

runImportEvent.OnServerEvent:connect(function(player)
	local data = pendingImports[player]
	if not data then
		return
	end
	pendingImports[player] = nil

	local final = {}
	for _, tokens in ipairs(data) do
		for _, v in ipairs(tokens) do
			table.insert(final, v)
		end
	end

	local success, root, count = pcall(Importer.importFromTokens, final, nil)
	if not success then
		warn("Importer: import failed:", root)
		return
	end

	local service = ROOT_SERVICES[root.ClassName]
	if service then
		root.Parent = game:GetService(service)
	else
		local destRoot = ServerStorage:FindFirstChild("ImportedModels")
		if not destRoot then
			destRoot = Instance.new("Folder")
			destRoot.Name = "ImportedModels"
			destRoot.Parent = ServerStorage
		end
		root.Parent = destRoot
	end

	print("Importer: imported", count, "instances ->", root:GetFullName())
end)

Players.PlayerRemoving:Connect(function(player)
	pendingImports[player] = nil
end)
