-- Class that memoizes sorting by inserting values in order. Optimized for very large arrays.
-- @author Validark

local sort = table.sort
local insert = table.insert

local SortedArray = {}
local Comparisons = setmetatable({}, {__mode = "k"})

SortedArray.__index = {
	Unpack = unpack;
	Concat = table.concat;
	RemoveIndex = table.remove;
}

function SortedArray.new(self, Comparison)
	if self then
		sort(self, Comparison)
	else
		self = {}
	end

	Comparisons[self] = Comparison
	return setmetatable(self, SortedArray)
end

local function FindClosest(self, Value, Low, High, Eq, Lt)
	local Middle do
		local Sum = Low + High
		Middle = (Sum - Sum % 2) / 2
	end

	if Middle == 0 then
		return nil
	end

	local Compare = Lt or Comparisons[self]
	local Value2 = self[Middle]

	while Middle ~= High do
		if Eq then
			if Eq(Value, Value2) then
				return Middle
			end
		elseif Value == Value2 then
			return Middle
		end

		local Bool

		if Compare then
			Bool = Compare(Value, Value2)
		else
			Bool = Value < Value2
		end

		if Bool then
			High = Middle - 1
		else
			Low = Middle + 1
		end

		local Sum = Low + High
		Middle = (Sum - Sum % 2) / 2
		Value2 = self[Middle]
	end

	return Middle
end

function SortedArray.__index:Insert(Value)
	-- Inserts a Value into the SortedArray while maintaining its sortedness

	local Position = FindClosest(self, Value, 1, #self)
	local Value2 = self[Position]

	if Value2 then
		local Compare = Comparisons[self]
		local Bool

		if Compare then
			Bool = Compare(Value, Value2)
		else
			Bool = Value < Value2
		end

		Position = Bool and Position or Position + 1
	else
		Position = 1
	end

	insert(self, Position, Value)

	return Position
end

function SortedArray.__index:Find(Value, Eq, Lt, U_0, U_n)
	-- Finds a Value in a SortedArray and returns its position (or nil if non-existant)

	local Position = FindClosest(self, Value, U_0 or 1, U_n or #self, Eq, Lt)

	local Bool

	if Position then
		if Eq then
			Bool = Eq(Value, self[Position])
		else
			Bool = Value == self[Position]
		end
	end

	return Bool and Position or nil
end

function SortedArray.__index:Copy()
	local New = {}

	for i = 1, #self do
		New[i] = self[i]
	end

	return New
end

function SortedArray.__index:Clone()
	local New = {}

	for i = 1, #self do
		New[i] = self[i]
	end

	Comparisons[New] = Comparisons[self]
	return setmetatable(New, SortedArray)
end

function SortedArray.__index:RemoveElement(Signature, Eq, Lt)
	local Position = self:Find(Signature, Eq, Lt)

	if Position then
		return self:RemoveIndex(Position)
	end
end

function SortedArray.__index:Sort()
	sort(self, Comparisons[self])
end

function SortedArray.__index:SortIndex(Index)
	-- Sorts a single element at number Index
	-- Useful for when a single element is somehow altered such that it should get a new position in the array

	return self:Insert(self:RemoveIndex(Index))
end

function SortedArray.__index:SortElement(Signature, Eq, Lt)
	-- Sorts a single element if it exists
	-- Useful for when a single element is somehow altered such that it should get a new position in the array

	return self:Insert(self:RemoveElement(Signature, Eq, Lt))
end

function SortedArray.__index:GetIntersection(SortedArray2, Eq, Lt)
	-- Returns a SortedArray of Commonalities between self and another SortedArray
	-- If applicable, the returned SortedArray will inherit the Comparison function from self

	if SortedArray ~= getmetatable(SortedArray2) then error("bad argument #2 to GetIntersection: expected SortedArray, got " .. typeof(SortedArray2) .. " " .. tostring(SortedArray2)) end
	local Commonalities = SortedArray.new(nil, Comparisons[self])
	local Count = 0
	local Position = 1
	local NumSelf = #self
	local NumSortedArray2 = #SortedArray2

	if NumSelf > NumSortedArray2 then -- Iterate through the shorter SortedArray
		NumSelf, NumSortedArray2 = NumSortedArray2, NumSelf
		self, SortedArray2 = SortedArray2, self
	end

	for i = 1, NumSelf do
		local Current = self[i]
		local CurrentPosition = SortedArray2:Find(Current, Eq, Lt, Position, NumSortedArray2)

		if CurrentPosition then
			Position = CurrentPosition
			Count = Count + 1
			Commonalities[Count] = Current
		end
	end

	return Commonalities
end

return SortedArray