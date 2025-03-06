local Tool = script.Parent.Parent

-- Libraries
local Libraries = Tool:WaitForChild 'Libraries'
local Signal = require(Libraries:WaitForChild 'Signal')

History = {

	-- Record stack
	Stack = {},

	-- Current position in record stack
	Index = 0,

	-- History change event
	Changed = Signal.new(),
	
	-- To prevent edge cases where multiple actions take place at the same time 
	Debounce = false

};

function WaitForDebounce()
	while History.Debounce do
		task.wait();
	end;
end;

function History.Undo()
	-- Unapplies the previous record in stack

	-- Stay within boundaries
	if History.Index - 1 < 0 then
		return;
	end;

	-- Prevent edit conflicts
	WaitForDebounce();
	History.Debounce = true;

	-- Get the history record, unapply it
	local Record = History.Stack[History.Index];
	Record:Unapply();

	-- Update the index
	History.Index = History.Index - 1;

	-- Fire the Changed event
	History.Changed:Fire();

	-- Release debounce lock
	History.Debounce = false;

end;

function History.Redo()
	-- Applies the next record in stack

	-- Stay within boundaries
	if History.Index + 1 > #History.Stack then
		return;
	end;
	
	-- Prevent edit conflicts
	WaitForDebounce();
	History.Debounce = true;

	-- Update the index
	History.Index = History.Index + 1;

	-- Get the history record and apply it
	local Record = History.Stack[History.Index];
	Record:Apply();

	-- Fire the Changed event
	History.Changed:Fire();

	-- Release debounce lock
	History.Debounce = false;
	
end;

function History.Add(Record)
	-- Adds new history record to stack

	-- Prevent edit conflicts
	WaitForDebounce();
	History.Debounce = true;

	-- Update the index
	History.Index = History.Index + 1;

	-- Register the new history record
	History.Stack[History.Index] = Record;

	-- Clear history ahead
	for Index = History.Index + 1, #History.Stack do
		History.Stack[Index] = nil;
	end;

	-- Fire the Changed event
	History.Changed:Fire();

	-- Release debounce lock
	History.Debounce = false;

end;

return History;
