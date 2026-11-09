local httpService: HttpService = game:GetService("HttpService")
local runService: RunService = game:GetService("RunService")

local toolbar = plugin:CreateToolbar("Luma")
local button = toolbar:CreateButton("Luma", "Luma IDE Sync", "rbxassetid://137225203329196", "Luma")

if not runService:IsRunMode() then
    if not runService:IsStudio() then
        error("Luma Roblox Plugin cannot run outside of Roblox Studio!")
    else
        if not httpService.HttpEnabled then
            error("HttpService is disabled!\n")
        end

        -- IDE Sync initialization here
    end
end

button.Click:Connect(function()
end)