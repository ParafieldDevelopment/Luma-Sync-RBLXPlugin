type RequestManager = {
    URL: string,
    Websocket: WebSocketClient
}

local RequestManager = {}
RequestManager.__index = RequestManager

function RequestManager.connect(url: string)
    local self = setmetatable({}, RequestManager)

    self.URL = url

    

    return self
end

return RequestManager