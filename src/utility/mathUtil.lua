--!strict
local epsilon = 1e-5

local mathUtil = {}

function mathUtil.fuzzyEq(a: number, b: number): boolean
	return math.abs(a - b) < epsilon
end

function mathUtil.round(number: number, increment: number): number
	return math.floor(number / increment + 0.5) * increment
end

function mathUtil.cframeFuzzyEq(a: CFrame, b: CFrame): boolean
	return a.Position:FuzzyEq(b.Position, epsilon)
		and a.LookVector:FuzzyEq(b.LookVector, epsilon)
		and a.UpVector:FuzzyEq(b.UpVector, epsilon)
		and a.RightVector:FuzzyEq(b.RightVector, epsilon)
end

return mathUtil
