--!strict
local function round(number: number, increment: number): number
	return math.floor(number / increment + 0.5) * increment
end

return round
