--------------------------------
-- parazeeknova's hypr config --
--------------------------------
local function safe_require(module)
    local status, err = pcall(require, module)
    if not status then
        local msg = "Failed to load Hyprland module: " .. tostring(module) .. "\nError: " .. tostring(err)
        print(msg)
        os.execute("notify-send -u critical -a 'Hyprland' 'Config Error' '" .. msg:gsub("'", "'\\''") .. "'")
    end
end

safe_require('modules.core.monitors')
safe_require('modules.core.input')
safe_require('modules.binds')
safe_require('modules.autostart')
safe_require('modules.env')
safe_require('modules.decorations')
safe_require('modules.layout')
safe_require('modules.misc')
safe_require('modules.windowrules')
safe_require('modules.workspace.rules')
