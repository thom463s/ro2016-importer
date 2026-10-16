local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local remotes = ReplicatedStorage:WaitForChild("ImporterRemotes")

local gui = Instance.new("ScreenGui")
gui.Name = "ImporterGui"
gui.Parent = script.Parent

local input = Instance.new("TextBox")
input.Name = "Input"
input.Text = "Input Data Here"
input.ClearTextOnFocus = true
input.BackgroundColor3 = Color3.new(1, 1, 1)
input.Position = UDim2.new(0, 10, 0.5, -25)
input.Size = UDim2.new(0, 200, 0, 50)
input.Parent = gui

local submit = Instance.new("TextButton")
submit.Name = "Submit"
submit.Text = "Submit"
submit.BackgroundColor3 = Color3.new(1, 1, 1)
submit.Position = UDim2.new(0, 10, 0.5, 30)
submit.Size = UDim2.new(0, 97, 0, 25)
submit.Parent = gui

local import = Instance.new("TextButton")
import.Name = "Import"
import.Text = "Import"
import.BackgroundColor3 = Color3.new(1, 1, 1)
import.Position = UDim2.new(0, 113, 0.5, 30)
import.Size = UDim2.new(0, 97, 0, 25)
import.Parent = gui

local count = 0

submit.MouseButton1Click:connect(function()
	local success, tokens = pcall(function()
		return HttpService:JSONDecode(input.Text)
	end)

	if not success or type(tokens) ~= "table" then
		input.Text = "Not valid data, copy the whole value"
		return
	end

	remotes.SendImportData:FireServer(tokens)
	count = count + 1
	input.Text = ""
	
	print("Importer: sent chunk", count)
end)

import.MouseButton1Click:connect(function()
	remotes.RunImport:FireServer()
	count = 0
end)
