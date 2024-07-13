local mathUtil = require(script.Parent.mathUtil)

local function fuzzyDeepEquals(a: any, b: any): boolean
	if typeof(a) == typeof(b) then
		if typeof(a) == "number" and mathUtil.fuzzyEq(a, b) then
			return true
		elseif typeof(a) == "Vector3" and a:FuzzyEq(b, mathUtil.epsilon) then
			return true
		elseif typeof(a) == "CFrame" and mathUtil.cframeFuzzyEq(a, b) then
			return true
		elseif a == b then
			return true
		end
	end

	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end

	for key, value in a do
		if not fuzzyDeepEquals(value, b[key]) then
			return false
		end
	end

	for key, value in b do
		if not fuzzyDeepEquals(value, a[key]) then
			return false
		end
	end

	return true
end

return fuzzyDeepEquals
