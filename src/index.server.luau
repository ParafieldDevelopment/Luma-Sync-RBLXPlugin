local httpService: HttpService = game:GetService("HttpService")
local runService: RunService = game:GetService("RunService")
local RequestManager = require(script.Parent.Requesting.RequestManager)
local _requestManager = require(script.Parent.Requesting.RequestManager)

local toolbar = plugin:CreateToolbar("Luma")
local button = toolbar:CreateButton("Luma", "Open the connection UI\n\nDisabled", "rbxassetid://137225203329196", "Luma IDE Sync")
button.Enabled = false

local manager: RequestManager.RequestManager? = nil

if not runService:IsRunMode() then
    if not runService:IsStudio() then
        error("Luma Roblox Plugin cannot run outside of Roblox Studio!")
    else
        if not httpService.HttpEnabled then
            error("HttpService is disabled!\n")
        end

        button.Tooltip = "Open the connection UI\n\nDisconnected"
    end
end

button.Click:Connect(function()
    -- IDE Sync initialization here

    button.Tooltip = "Open the connection UI\n\nConnecting..."

    manager = _requestManager.new("ws://localhost:3343")
    if manager and manager.Websocket then
        manager.Websocket.Opened:Connect(function()
            button.Tooltip = "Open the connection UI\n\nConnected"
        end)

        manager.Websocket.Error:Connect(function()
            button.Tooltip = "Open the connection UI\n\nDisconnected"
        end)

        manager.Websocket.Closed:Connect(function()
            button.Tooltip = "Open the connection UI\n\nDisconnected"
        end)
    end
end)