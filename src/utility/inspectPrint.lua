local function inspectPrint(string, level)
	local n = debug.info(2, "n")
	local s, l = debug.info(1 + level, "sl")
	local s2, l2 = debug.info(2 + level, "sl")
	print(`{string} through {n} [{s:match("%a+$")}: {l}][{s2:match("%a+$")}: {l2}]`)
end

return inspectPrint
