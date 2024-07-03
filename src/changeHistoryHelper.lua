local ChangeHistoryService = game:GetService("ChangeHistoryService")

local changeHistoryHelper = {}

local willStartAppending = false
local isAppending = false
function changeHistoryHelper.startAppendingAfterNextCommit()
	willStartAppending = true
	isAppending = false
end

function changeHistoryHelper.stopAppending()
	willStartAppending = false
	isAppending = false
end

function changeHistoryHelper.recordUndoChange(changeFunc)
	if ChangeHistoryService:IsRecordingInProgress() then
		ChangeHistoryService:FinishRecording("", Enum.FinishRecordingOperation.Cancel)
	end

	local recordingId = ChangeHistoryService:TryBeginRecording("IntelliscaleChange", "Intelliscale Change")
	changeFunc()
	ChangeHistoryService:FinishRecording(
		recordingId,
		if isAppending then Enum.FinishRecordingOperation.Append else Enum.FinishRecordingOperation.Commit
	)

	if willStartAppending then
		isAppending = true
		willStartAppending = false
	end
end

return changeHistoryHelper
