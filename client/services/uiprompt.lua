UIPrompt = {}

local promptGroup = GetRandomIntInRange(0, 0xffffff)

UIPrompt.activate = function(title)
    local label = VarString(10, 'LITERAL_STRING', title)
    UiPromptSetActiveGroupThisFrame(promptGroup, label, 0, 0, 0, 0)
end

UIPrompt.initialize = function()
    local str = _U('CraftText')
    CraftPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(CraftPrompt, Config.Keys["G"])
    str = VarString(10, 'LITERAL_STRING', str)
    UiPromptSetText(CraftPrompt, str)
    UiPromptSetEnabled(CraftPrompt, true)
    UiPromptSetVisible(CraftPrompt, true)
    UiPromptSetStandardMode(CraftPrompt, true)
    UiPromptSetGroup(CraftPrompt, promptGroup, 0)
    UiPromptRegisterEnd(CraftPrompt)
end
