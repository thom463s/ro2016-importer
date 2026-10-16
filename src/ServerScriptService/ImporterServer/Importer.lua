local SpecialNames = require(script.Parent.SpecialNames)
local Classes = require(script.Parent.Classes)

local ASSET_URL = "rbxassetid://"

local WIDTH = {
	bool = 1,
	number = 1,
	string = 1,
	content = 1,
	ref = 1,
	vector2 = 2,
	numberrange = 2,
	vector3 = 3,
	color3 = 3,
	brickcolor = 3,
	udim2 = 4,
	cframe = 6,
	colorsequence = 1,
	numbersequence = 1,
}

local ID_OVERRIDES = {
	[26] = "Weld",
	[32] = "ScreenGui",
	[37] = "Accessory",
}

local SUBSTITUTES = {
	Accessory = "Hat",
	WeldConstraint = "Weld",
	GuiMain = "ScreenGui",
}

local ENUM_REMAP = {
	GridSortOrder = {
		[0] = 1,
		[1] = 2,
		[2] = 0
	},
	PartType = {
		[3] = 1,
		[4] = 1
	},
	ScaleType = {
		[2] = 0,
		[3] = 0,
		[4] = 0
	},
	AnimationPriority = {
		[3] = 2,
		[4] = 2,
		[5] = 2
	},
	PoseEasingStyle = {
		[5] = 3
	},
	Material = {
		[1568] = 272,
		[1584] = 288,
		[2304] = 1312,
		[2305] = 1312,
		[2306] = 836,
		[2307] = 848,
		[2308] = 800,
		[2309] = 1312,
		[2310] = 816,
		[2311] = 272,
	},
	Font = {
		[16] = 4,
		[17] = 3,
		[18] = 3,
		[19] = 4,
		[20] = 4,
		[21] = 14,
		[22] = 9,
		[23] = 14,
		[24] = 4,
		[25] = 15,
		[26] = 9,
		[27] = 15,
		[28] = 9,
		[29] = 3,
		[30] = 12,
		[31] = 9,
		[32] = 9,
		[33] = 8,
		[34] = 12,
		[35] = 3,
		[36] = 11,
		[37] = 9,
		[38] = 9,
		[39] = 3,
		[40] = 3,
		[41] = 10,
		[42] = 12,
		[43] = 10,
		[44] = 3,
		[45] = 3,
		[46] = 3,
		[47] = 3,
		[48] = 4,
		[49] = 4,
		[50] = 1,
		[51] = 2,
		[100] = 3,
	},
}

local FIRST_PROPERTIES = {
	"Shape",
	"Size",
	"CFrame",
	"MaxHealth",
	"MaxValue",
	"MinValue",
	"MaxValue",
	"Value",
}

local SKIP_PROPERTIES = {
	FormFactor = true,
	LayoutOrder = true,
	SliceScale = true,
}

local ATTACHMENT_SKIP_PROPERTIES = {
	Axis = true,
	SecondaryAxis = true,
	Position = true,
	Rotation = true,
}

local idToClass = {}
for className, data in pairs(Classes) do
	if data[1] then
		idToClass[data[1]] = className
	end
end
for id, className in pairs(ID_OVERRIDES) do
	idToClass[id] = className
end

local specialIdToName = {}
local specialCount = 0
for name, id in pairs(SpecialNames) do
	specialIdToName[id] = name
	if id > specialCount then
		specialCount = id
	end
end

local strings
local Ref = {}
local Importer = {}

local schemaCache = {}
local function getSchema(className)
	if schemaCache[className] then
		return schemaCache[className]
	end

	local schema = {}
	local function walk(currentClassName)
		local data = Classes[currentClassName]
		if not data then
			return
		end

		if data[2] then
			walk(data[2])
		end

		local list = data[3]
		for index = 1, #list, 2 do
			table.insert(schema, {
				name = list[index],
				type = list[index + 1]
			})
		end
	end

	walk(className)
	schemaCache[className] = schema
	return schema
end

local enumCache = {}
local function enumItems(enumName)
	if enumCache[enumName] == nil then
		local success, items = pcall(function()
			return Enum[enumName]:GetEnumItems()
		end)

		local byValue = false
		if success then
			byValue = {}
			for _, item in ipairs(items) do
				byValue[item.Value] = item
			end
		end
		enumCache[enumName] = byValue
	end
	return enumCache[enumName]
end

local function num(token)
	local number = tonumber(token)
	if number ~= nil and number == number then
		return number
	end
	if token == "inf" or token == "Infinity" then
		return math.huge
	end
	if token == "-inf" or token == "-Infinity" then
		return -math.huge
	end
	return 0
end

local function resolveString(token, isProperty)
	local index = tonumber(token)
	if index == nil or index == 0 then
		return nil
	end
	if index == -1 then
		return ""
	end
	if index <= specialCount then
		return specialIdToName[index]
	end

	local text = strings[index - specialCount]
	if text ~= nil then
		return text
	end
	if isProperty then
		return string.concat(ASSET_URL, token)
	end
	return nil
end

local function makeCFrame(tokens, index)
	return CFrame.new(num(tokens[index]), num(tokens[index + 1]), num(tokens[index + 2]))
		* CFrame.Angles(0, math.rad(num(tokens[index + 4])), 0)
		* CFrame.Angles(math.rad(num(tokens[index + 3])), 0, 0)
		* CFrame.Angles(0, 0, math.rad(num(tokens[index + 5])))
end

local function color(tokens, index)
	return Color3.new(
		num(tokens[index]) / 255,
		num(tokens[index + 1]) / 255,
		num(tokens[index + 2]) / 255
	)
end

local function decodeValue(propertyType, tokens, index)
	local token = tokens[index]

	if propertyType == "bool" then
		return token == "1" or token == 1
	elseif propertyType == "number" then
		return num(token)
	elseif propertyType == "string" or propertyType == "content" then
		return resolveString(token, true)
	elseif propertyType == "ref" then
		local rank = tonumber(token)
		if rank and rank > 0 then
			return setmetatable({
				rank = rank
			}, Ref)
		end
		return nil
	elseif propertyType == "vector2" then
		return Vector2.new(num(token), num(tokens[index + 1]))
	elseif propertyType == "numberrange" then
		local min = num(token)
		local max = num(tokens[index + 1])
		if min > max then
			min, max = max, min
		end
		return NumberRange.new(min, max)
	elseif propertyType == "vector3" then
		return Vector3.new(num(token), num(tokens[index + 1]), num(tokens[index + 2]))
	elseif propertyType == "color3" then
		return color(tokens, index)
	elseif propertyType == "brickcolor" then
		return BrickColor.new(color(tokens, index))
	elseif propertyType == "udim2" then
		return UDim2.new(num(token), num(tokens[index + 1]), num(tokens[index + 2]), num(tokens[index + 3]))
	elseif propertyType == "cframe" then
		return makeCFrame(tokens, index)
	elseif propertyType == "colorsequence" then
		local keypoints = {}
		for i = 1, num(token) do
			local at = index + 1 + (i - 1) * 4
			keypoints[i] = ColorSequenceKeypoint.new(num(tokens[at]), color(tokens, at + 1))
		end
		local success, sequence = pcall(function()
			return ColorSequence.new(keypoints)
		end)
		return success and sequence
	elseif propertyType == "numbersequence" then
		local keypoints = {}
		for i = 1, num(token) do
			local at = index + 1 + (i - 1) * 3
			keypoints[i] = NumberSequenceKeypoint.new(num(tokens[at]), num(tokens[at + 1]), num(tokens[at + 2]))
		end
		local success, sequence = pcall(function()
			return NumberSequence.new(keypoints)
		end)
		return success and sequence
	end

	return num(token)
end

local function fieldWidth(propertyType, tokens, pos)
	if propertyType == "colorsequence" then
		return 1 + 4 * (tonumber(tokens[pos]) or 0)
	elseif propertyType == "numbersequence" then
		return 1 + 3 * (tonumber(tokens[pos]) or 0)
	end
	return WIDTH[propertyType] or 1
end

local function parse(tokens)
	local headerSize = tonumber(tokens[1])
	if not headerSize then
		error("Importer: not exporter data (paste chunk 1 first, Debug table off)", 0)
	end

	local hasNames = tokens[2] == "1"
	local hasStrings = tokens[3] == "1"
	local pos = headerSize + 2

	strings = {}
	if hasNames or hasStrings then
		local count = tonumber(tokens[pos]) or 0
		for index = 1, count do
			strings[index] = tokens[pos + index]
		end
		pos = pos + count + 1
	end

	local rows = {}
	while tokens[pos] ~= nil do
		local rank = #rows + 1
		local className = idToClass[tonumber(tokens[pos])]
		local parent = tonumber(tokens[pos + 1])
		if not className or not parent or parent < 0 or parent >= rank then
			warn("Importer: bad data at instance", rank, "token", pos, tokens[pos])
			error("Importer: data out of step (missing chunk, wrong order, or Classes out of date)", 0)
		end
		pos = pos + 2

		local row = {
			className = className,
			parent = parent,
			values = {},
			schema = getSchema(className),
		}

		if hasNames then
			row.name = resolveString(tokens[pos], false)
			pos = pos + 1
		end

		for _, field in ipairs(row.schema) do
			local width = fieldWidth(field.type, tokens, pos)
			if tokens[pos + width - 1] == nil then
				error("Importer: data ends early (missing chunks)", 0)
			end
			row.values[field.name] = decodeValue(field.type, tokens, pos)
			pos = pos + width
		end

		if not hasNames and tokens[pos] == "-1" then
			row.name = resolveString(tokens[pos + 1], false)
			pos = pos + 2
		end

		rows[rank] = row
		if rank % 200 == 0 then
			wait()
		end
	end

	return rows
end

local function set(inst, prop, value)
	return pcall(function()
		inst[prop] = value
	end)
end

local function createInstance(row)
	local className = row.className
	local success, inst = pcall(Instance.new, className)

	if className == "MeshPart" then
		local meshId = row.values.MeshId
		if success and (not meshId or meshId == "" or set(inst, "MeshId", meshId)) then
			row.values.MeshId = nil
			return inst
		end

		inst = Instance.new("Part")
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = meshId or ""
		mesh.TextureId = row.values.TextureID or ""
		mesh.Parent = inst

		row.values.MeshId = nil
		row.values.TextureID = nil
		return inst
	end

	if not success and className == "UIListLayout" then
		return nil
	end
	if not success and SUBSTITUTES[className] then
		success, inst = pcall(Instance.new, SUBSTITUTES[className])
	end
	if not success then
		warn("Importer: could not create", className, "- using Folder")
		inst = Instance.new("Folder")
	end

	return inst
end

local function applyProperty(inst, row, field, value, refs, failed)
	local prop = field.name
	local propertyType = field.type

	if type(value) == "table" and getmetatable(value) == Ref then
		table.insert(refs, {
			inst = inst,
			prop = prop,
			rank = value.rank,
			row = row,
		})
		return
	end

	if not WIDTH[propertyType] then
		local items = enumItems(propertyType)
		if not items then
			return
		end
		local remap = ENUM_REMAP[propertyType]
		value = items[remap and remap[value] or value]
		if not value then
			return
		end
	end

	if inst:IsA("BasePart") then
		if prop == "Color" then
			prop = "BrickColor"
			value = BrickColor.new(value)
		elseif prop == "BrickColor" and row.values.Color then
			return
		end
	end

	if not set(inst, prop, value) then
		if prop == "AnchorPoint" then
			row.anchor = value
		elseif prop == "Enabled" and value == false and inst:IsA("JointInstance") then
			row.noPart1 = true
		elseif prop ~= "Enabled" and prop ~= "MeshId" then
			failed[prop] = row.className
		end
	end
end

local function foldAnchor(inst, anchor)
	local position = inst.Position
	local size = inst.Size

	set(inst, "Position", UDim2.new(
		position.X.Scale - anchor.X * size.X.Scale,
		position.X.Offset - anchor.X * size.X.Offset,
		position.Y.Scale - anchor.Y * size.Y.Scale,
		position.Y.Offset - anchor.Y * size.Y.Offset
	))
end

local function applyRow(inst, row, refs, failed)
	local values = row.values
	local done = {}

	if inst:IsA("BasePart") then
		set(inst, "FormFactor", Enum.FormFactor.Custom)
	end

	local fieldsByName = {}
	for _, field in ipairs(row.schema) do
		fieldsByName[field.name] = field
	end

	for _, prop in ipairs(FIRST_PROPERTIES) do
		if fieldsByName[prop] and values[prop] ~= nil then
			applyProperty(inst, row, fieldsByName[prop], values[prop], refs, failed)
			done[prop] = true
		end
	end

	for _, field in ipairs(row.schema) do
		local prop = field.name
		local skip = done[prop]
			or SKIP_PROPERTIES[prop]
			or values[prop] == nil
			or (row.className == "Attachment" and values.CFrame and ATTACHMENT_SKIP_PROPERTIES[prop])

		if not skip then
			applyProperty(inst, row, field, values[prop], refs, failed)
		end
	end

	if row.anchor and (row.anchor.X ~= 0 or row.anchor.Y ~= 0) then
		foldAnchor(inst, row.anchor)
	end
end

local function layoutItems(rows, created, layoutRank)
	local layout = rows[layoutRank]
	local items = {}

	for rank, row in ipairs(rows) do
		local inst = created[rank]
		if rank ~= layoutRank
			and row.parent == layout.parent
			and inst
			and inst:IsA("GuiObject")
		then
			table.insert(items, {
				inst = inst,
				row = row,
				rank = rank
			})
		end
	end

	local sortOrder = layout.values.SortOrder
	table.sort(items, function(a, b)
		if sortOrder == 0 and a.inst.Name ~= b.inst.Name then
			return a.inst.Name < b.inst.Name
		end
		if sortOrder == 2 then
			local orderA = a.row.values.LayoutOrder or 0
			local orderB = b.row.values.LayoutOrder or 0
			if orderA ~= orderB then
				return orderA < orderB
			end
		end
		return a.rank < b.rank
	end)

	return items
end

local function alignStart(align, scale, offset)
	if align == 0 then
		return (1 - scale) / 2, -offset / 2
	end
	if align == 2 then
		return 1 - scale, -offset
	end
	return 0, 0
end

local function applyListLayout(rows, created, rank)
	local values = rows[rank].values
	local horizontal = values.FillDirection == 0
	local mainAlign = horizontal and values.HorizontalAlignment or values.VerticalAlignment
	local crossAlign = horizontal and values.VerticalAlignment or values.HorizontalAlignment

	local items = {}
	local totalScale = 0
	local totalOffset = 0
	for _, item in ipairs(layoutItems(rows, created, rank)) do
		if item.inst.Visible then
			local length = horizontal and item.inst.Size.X or item.inst.Size.Y
			totalScale = totalScale + length.Scale
			totalOffset = totalOffset + length.Offset
			table.insert(items, item.inst)
		end
	end

	local currentScale, currentOffset = alignStart(mainAlign, totalScale, totalOffset)
	for _, inst in ipairs(items) do
		local main = horizontal and inst.Size.X or inst.Size.Y
		local cross = horizontal and inst.Size.Y or inst.Size.X
		local crossScale, crossOffset = alignStart(crossAlign, cross.Scale, cross.Offset)

		if horizontal then
			set(inst, "Position", UDim2.new(currentScale, currentOffset, crossScale, crossOffset))
		else
			set(inst, "Position", UDim2.new(crossScale, crossOffset, currentScale, currentOffset))
		end

		currentScale = currentScale + main.Scale
		currentOffset = currentOffset + main.Offset
	end
end

function Importer.importFromTokens(tokens, destinationParent)
	local rows = parse(tokens)
	local created = {}
	local holders = {}
	local refs = {}
	local failed = {}

	for rank, row in ipairs(rows) do
		local inst = createInstance(row)
		local parent = holders[row.parent]

		if inst then
			if row.name then
				set(inst, "Name", row.name)
			end
			applyRow(inst, row, refs, failed)
			if parent then
				inst.Parent = parent
			end
			created[rank] = inst
			holders[rank] = inst
		else
			holders[rank] = parent
		end

		if rank % 200 == 0 then
			wait()
		end
	end

	for _, ref in ipairs(refs) do
		local target = created[ref.rank]
		if target and not (ref.prop == "Part1" and ref.row.noPart1) then
			if not set(ref.inst, ref.prop, target) then
				failed[ref.prop] = ref.row.className
			end
		end
	end

	for rank, row in ipairs(rows) do
		if row.parent > 0 and row.className == "UIListLayout" and not created[rank] then
			applyListLayout(rows, created, rank)
		elseif row.parent > 0
			and row.className == "UIGridLayout"
			and created[rank]
			and row.values.SortOrder == 2
		then
			for _, item in ipairs(layoutItems(rows, created, rank)) do
				item.inst.Parent = nil
				item.inst.Parent = holders[row.parent]
			end
		end
	end

	for prop, className in pairs(failed) do
		warn("Importer: could not set", className, prop)
	end

	local root = created[1]
	if root then
		root.Parent = destinationParent
	end

	return root, #rows
end

return Importer
