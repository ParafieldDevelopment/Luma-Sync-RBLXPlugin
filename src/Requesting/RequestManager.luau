--!strict

local HttpService = game:GetService("HttpService")

local Request = require(script.Parent.Request)
local RequestType = require(script.Parent.RequestType)

export type RequestMap = {
	[string]: Request.Request<any>,
}

export type RequestContext = {
	IsCancelled: boolean,
}

type RequestHandler = (payload: any, context: RequestContext) -> any

type IncomingMessage = {
	kind: string,
	uuid: string?,
	functionID: string?,
	requestType: RequestType.RequestType?,
	payload: any?,
	success: boolean?,
	error: string?,
}

type OutgoingRequestMessage = {
	kind: "request",
	uuid: string,
	functionID: string,
	requestType: RequestType.RequestType,
	payload: any,
}

type OutgoingResponseMessage = {
	kind: "response",
	uuid: string,
	success: boolean,
	payload: any?,
	error: string?,
}

type OutgoingCancelMessage = {
	kind: "cancel",
	uuid: string,
}

type OutgoingMessage = OutgoingRequestMessage | OutgoingResponseMessage | OutgoingCancelMessage

export type RequestManager = {
	URL: string,
	Websocket: WebStreamClient,
	IsConnected: boolean,

	Requests: RequestMap,
	Handlers: { [string]: RequestHandler },
	Incoming: { [string]: RequestContext },

	Send: <T>(
		self: RequestManager,
		functionID: string,
		requestType: RequestType.RequestType,
		payload: any
	) -> Request.Request<T>,

	RegisterHandler: (self: RequestManager, functionID: string, handler: RequestHandler) -> (),
	_SendMessage: (self: RequestManager, message: OutgoingMessage) -> boolean,
	_HandleResponse: (self: RequestManager, message: IncomingMessage) -> (),
	_HandleRequest: (self: RequestManager, message: IncomingMessage) -> (),
	_HandleCancel: (self: RequestManager, message: IncomingMessage) -> (),
	_HandleMessage: (self: RequestManager, rawMessage: string) -> (),

	Close: (self: RequestManager) -> (),
}

local RequestManager = {}
RequestManager.__index = RequestManager

function RequestManager._SendMessage(self: RequestManager, message: OutgoingMessage): boolean
	if not self.IsConnected then
		return false
	end

	local success: boolean, result: any = pcall(function()
		self.Websocket:Send(HttpService:JSONEncode(message))
	end)

	if not success then
		warn("[Luma IDE Sync] Failed to send message:", result)
		return false
	end

	return true
end

function RequestManager.Send<T>(
	self: RequestManager,
	functionID: string,
	requestType: RequestType.RequestType,
	payload: any
): Request.Request<T>
	assert(self.IsConnected, "WebSocket is not connected")

	local uuid: string = HttpService:GenerateGUID(false)

	local request: Request.Request<T> = Request.New(
		uuid,
		functionID,
		requestType
	) :: any

	self.Requests[uuid] = request :: Request.Request<any>

	request:SetCancelHandler(function()
		self.Requests[uuid] = nil

		self:_SendMessage({
			kind = "cancel",
			uuid = uuid,
		})
	end)

	local success: boolean = self:_SendMessage({
		kind = "request",
		uuid = uuid,
		functionID = functionID,
		requestType = requestType,
		payload = payload,
	})

	if not success then
		self.Requests[uuid] = nil
		request:Fail("Failed to send request")
	end

	return request
end

function RequestManager.RegisterHandler(
	self: RequestManager,
	functionID: string,
	handler: RequestHandler
)
	self.Handlers[functionID] = handler
end

function RequestManager._HandleResponse(self: RequestManager, message: IncomingMessage)
	if type(message.uuid) ~= "string" then
		return
	end

	local request: Request.Request<any>? = self.Requests[message.uuid]

	if not request then
		return
	end

	self.Requests[message.uuid] = nil

	if message.success then
		request:Complete(message.payload)
	else
		request:Fail(message.error or "Remote request failed")
	end
end

function RequestManager._HandleRequest(self: RequestManager, message: IncomingMessage)
	if type(message.uuid) ~= "string" then
		return
	end

	if type(message.functionID) ~= "string" then
		return
	end

	local handler: RequestHandler? = self.Handlers[message.functionID]

	if not handler then
		self:_SendMessage({
			kind = "response",
			uuid = message.uuid,
			success = false,
			error = "Unknown function: " .. message.functionID,
		})

		return
	end

	local context: RequestContext = {
		IsCancelled = false,
	}

	self.Incoming[message.uuid] = context

	task.spawn(function()
		local success: boolean, result: any = pcall(
			handler,
			message.payload,
			context
		)

		-- The request may have been cancelled while the handler ran.
		if self.Incoming[message.uuid] ~= context then
			return
		end

		self.Incoming[message.uuid] = nil

		if context.IsCancelled then
			return
		end

		if success then
			self:_SendMessage({
				kind = "response",
				uuid = message.uuid,
				success = true,
				payload = result,
			})
		else
			self:_SendMessage({
				kind = "response",
				uuid = message.uuid,
				success = false,
				error = tostring(result),
			})
		end
	end)
end

function RequestManager._HandleCancel(self: RequestManager, message: IncomingMessage)
	if type(message.uuid) ~= "string" then
		return
	end

	local context: RequestContext? = self.Incoming[message.uuid]

	if context then
		context.IsCancelled = true
		self.Incoming[message.uuid] = nil
	end
end

function RequestManager._HandleMessage(self: RequestManager, rawMessage: string)
	local success: boolean, decoded: any = pcall(function()
		return HttpService:JSONDecode(rawMessage)
	end)

	if not success or type(decoded) ~= "table" then
		warn("[Luma IDE Sync] Received invalid JSON message")
		return
	end

	local message: IncomingMessage = decoded :: IncomingMessage

	if type(message.kind) ~= "string" then
		warn("[Luma IDE Sync] Received message without a kind")
		return
	end

	if message.kind == "response" then
		self:_HandleResponse(message)

	elseif message.kind == "request" then
		self:_HandleRequest(message)

	elseif message.kind == "cancel" then
		self:_HandleCancel(message)

	else
		warn("[Luma IDE Sync] Unknown message kind:", message.kind)
	end
end

function RequestManager.new(url: string): RequestManager
	local self: RequestManager = setmetatable({
		URL = url,
		IsConnected = false,

		Requests = {},
		Handlers = {},
		Incoming = {},

		Websocket = HttpService:CreateWebStreamClient(
			Enum.WebStreamClientType.WebSocket,
			{
				Url = url,
			}
		),
	}, RequestManager) :: any

	self.Websocket.Opened:Connect(function(statusCode: number, headers: string)
		self.IsConnected = true

		print("[Luma IDE Sync] Connected:", statusCode)
	end)

	self.Websocket.MessageReceived:Connect(function(message: string)
		self:_HandleMessage(message)
	end)

	self.Websocket.Error:Connect(function(statusCode: number, message: string)
		self.IsConnected = false

		warn(
			"[Luma IDE Sync] WebSocket error:",
			statusCode,
			message
		)
	end)

	self.Websocket.Closed:Connect(function()
		self.IsConnected = false

		-- Fail all outstanding requests when disconnected.
		for uuid: string, request: Request.Request<any> in self.Requests do
			self.Requests[uuid] = nil
			request:Fail("WebSocket connection closed")
		end

		for uuid: string, context: RequestContext in self.Incoming do
			context.IsCancelled = true
			self.Incoming[uuid] = nil
		end

		print("[Luma IDE Sync] Disconnected")
	end)

	return self
end

function RequestManager.Close(self: RequestManager)
	if self.IsConnected then
		self.Websocket:Close()
	end
end

return RequestManager
