local deg = math.deg
local newVector3 = Vector3.new

local function TransformPartToCFrame(Part, CFrame)
	local OrientationX, OrientationY, OrientationZ = CFrame:ToOrientation()
	Part.Orientation = newVector3(deg(OrientationX), deg(OrientationY), deg(OrientationZ))
	Part.Position = CFrame.Position
end

local function TranslatePartsRelativeToPart(BasePart, InitialStates)
	-- Moves the given parts in `InitialStates` to BasePart's current position, with their original offset from it

	-- Get focused part's position for offsetting
	local RelativeTo = InitialStates[BasePart].CFrame:inverse()

	-- Calculate offset and move each part
	for Part, InitialState in pairs(InitialStates) do

		-- Calculate how far apart we should be from the focused part
		local Offset = RelativeTo * InitialState.CFrame

		-- Move relative to the focused part by this part's offset from it
		Part.Position = (BasePart.CFrame * Offset).Position

	end
end

local function TransformPartsRelativeToPart(BasePart, InitialStates)
	-- Moves, rotates the given parts in `InitialStates` to BasePart's current position, with their original offset from it

	-- Get focused part's position for offsetting
	local RelativeTo = InitialStates[BasePart].CFrame:inverse()

	-- Calculate offset and move each part
	for Part, InitialState in pairs(InitialStates) do

		-- Calculate how far apart we should be from the focused part
		local Offset = RelativeTo * InitialState.CFrame

		-- Move relative to the focused part by this part's offset from it
		local TargetCFrame = BasePart.CFrame * Offset
		local OrientationX, OrientationY, OrientationZ = TargetCFrame:ToOrientation()
		Part.Orientation = newVector3(deg(OrientationX), deg(OrientationY), deg(OrientationZ))
		Part.Position = TargetCFrame.Position

	end
end

local function GetIncrementMultiple(Number, Increment)

	-- Get how far the actual distance is from a multiple of our increment
	local MultipleDifference = Number % Increment

	-- Identify the closest lower and upper multiples of the increment
	local LowerMultiple = Number - MultipleDifference
	local UpperMultiple = Number - MultipleDifference + Increment

	-- Calculate to which of the two multiples we're closer
	local LowerMultipleProximity = math.abs(Number - LowerMultiple)
	local UpperMultipleProximity = math.abs(Number - UpperMultiple)

	-- Use the closest multiple of our increment as the distance moved
	if LowerMultipleProximity <= UpperMultipleProximity then
		Number = LowerMultiple
	else
		Number = UpperMultiple
	end

	return Number
end

return {
	TranslatePartsRelativeToPart = TranslatePartsRelativeToPart;
	TransformPartsRelativeToPart = TransformPartsRelativeToPart;
	GetIncrementMultiple = GetIncrementMultiple;
	TransformPartToCFrame = TransformPartToCFrame;
}