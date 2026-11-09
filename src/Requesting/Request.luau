local RequestType = require(script.Parent.RequestType)
local httpService: HttpService = game:GetService("HttpService")

local Request = {}
Request.__index = Request

export type Request<T> = {
    UUID: string,
    RequestFunctionID: string,
    RequestType: RequestType.RequestType,

    IsCompleted: boolean,
    Response: T?,

    OnComplete: ((response: T) -> ())?,

    Complete: (self: Request<T>, response: T) -> (),
    SetCallback: (self: Request<T>, callback: (response: T) -> ()) -> (),
}

function Request.New<T>(
    uuid: string,
    functionID: string,
    requestType: RequestType.RequestType
): Request<T>

    local self = setmetatable({}, Request)

    self.UUID = uuid
    self.RequestFunctionID = functionID
    self.RequestType = requestType

    self.IsCompleted = false
    self.Response = nil
    self.OnComplete = nil

    return self
end

function Request:Complete<T>(response: T)
    if self.IsCompleted then
        return
    end

    self.Response = response
    self.IsCompleted = true

    if self.OnComplete then
        self.OnComplete(response)
    end
end

function Request:SetCallback<T>(
    callback: (response: T) -> ()
)
    self.OnComplete = callback

    if self.IsCompleted then
        callback(self.Response :: T)
    end
end

function Request:JSONEncode<T>(): string
    return httpService:JSONEncode({
        UUID = self.UUID,
        RequestFunctionID = self.RequestFunctionID,
        RequestType = self.RequestType,

        IsCompleted = self.IsCompleted,
        Response = self.Response
    })
end

return Request