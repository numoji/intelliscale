local ChangeHistoryService = game:GetService("ChangeHistoryService")

function recordUndoChange(changeFunc)
	if ChangeHistoryService:IsRecordingInProgress() then
		ChangeHistoryService:FinishRecording(nil, Enum.FinishRecordingOperation.Cancel)
	end

	local recordingId = ChangeHistoryService:TryBeginRecording("IntelliscaleChange", "Intelliscale Change")
	changeFunc()
	ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
end

return recordUndoChange
