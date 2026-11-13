local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local RequestManagerModule = require(script.Parent.Requesting.RequestManager)

-- Toolbar
local toolbar = plugin:CreateToolbar("Luma")

local button = toolbar:CreateButton(
    "Luma",
    "Open the connection UI\n\nDisconnected",
    "rbxassetid://137225203329196",
    "Luma IDE Sync"
)
button.ClickableWhenViewportHidden = true

-- State
local manager: RequestManagerModule.RequestManager? = nil
local connections: {RBXScriptConnection} = {}
local widget: DockWidgetPluginGui
local widgetFrame: any

-- Status
local function setStatus(status: string, color: Color3)
    widgetFrame.ConnectionStatus.Status.Text = status
    widgetFrame.ConnectionStatus.Status.TextColor3 = color
end

-- Cleanup
local function cleanup()
    for _, connection in connections do
        connection:Disconnect()
    end

    table.clear(connections)
end

-- Connection
local function connect()
    cleanup()

    setStatus("Connecting...",Color3.fromRGB(255, 185, 0))

    local success, result = pcall(function()
        local url = (plugin:GetSetting("URL") or "ws://localhost:3343") :: string
        return RequestManagerModule.new(url)
    end)

    if not success then
        warn("[Luma] Failed to initialize RequestManager:", result)
        setStatus("Connection Failed",Color3.fromRGB(255, 0, 0))
        return
    end

    manager = result

    if not manager or not manager.Websocket then
        setStatus("Disconnected",Color3.fromRGB(255, 0, 0))
        return
    end

    local websocket = manager.Websocket

    table.insert(connections, websocket.Opened:Connect(function()
        print("[Luma] Connected!")
        setStatus("Connected",Color3.fromRGB(0, 255, 0))
    end))

    table.insert(connections, websocket.Error:Connect(function(message)
        warn("[Luma] WebSocket error:", message)
        setStatus("Connection Error",Color3.fromRGB(255, 0, 0))
    end))

    table.insert(connections, websocket.Closed:Connect(function()
        print("[Luma] Disconnected!")
        setStatus("Disconnected",Color3.fromRGB(255, 0, 0))
    end))
end

-- Initialization
local function initialize()
    if not RunService:IsStudio() then
        button.Enabled = false
        return
    end

    local widgetInfo = DockWidgetPluginGuiInfo.new(
        Enum.InitialDockState.Float,
        false,
        false,
        1000,
        800,
        1000,
        800
    )

    widget = plugin:CreateDockWidgetPluginGuiAsync(
        "LumaConnection",
        widgetInfo
    )

    widget.Title = "Luma"

    local frame = script.Parent.Window :: Frame
    widgetFrame = frame:Clone()
    widgetFrame.Parent = widget

    button.Enabled = true
    setStatus("Disconnected", Color3.fromRGB(255, 0, 0))

    local textbox: TextBox = widgetFrame.URLOverride.TextBox
    local url = (plugin:GetSetting("URL") or "ws://localhost:3343") :: string

    textbox.Text = url

    textbox:GetAttributeChangedSignal("Text"):Connect(function()
        plugin:SetSetting("URL",textbox.Text)
    end)

    widgetFrame.ConnectButton.Activated:Connect(function()
        connect()
    end)
end

-- Events
button.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)

plugin.Unloading:Connect(function()
    cleanup()
end)

-- Start
initialize()
