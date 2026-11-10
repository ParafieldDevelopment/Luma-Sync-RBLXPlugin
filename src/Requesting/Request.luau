--!strict

local RequestType = require(script.Parent.RequestType)

local Request = {}
Request.__index = Request

export type Request<T> = {
	UUID: string,
	RequestFunctionID: string,
	RequestType: RequestType.RequestType,

	IsCompleted: boolean,
	IsCancelled: boolean,

	Response: T?,
	Error: string?,

	OnComplete: ((response: T) -> ())?,
	OnCancel: (() -> ())?,
	OnError: ((message: string) -> ())?,

	_CancelHandler: (() -> ())?,

	Complete: (self: Request<T>, response: T) -> (),
	Cancel: (self: Request<T>) -> (),
	Fail: (self: Request<T>, message: string) -> (),

	SetCallback: (self: Request<T>, callback: (response: T) -> ()) -> (),
	SetCancelCallback: (self: Request<T>, callback: () -> ()) -> (),
	SetErrorCallback: (self: Request<T>, callback: (message: string) -> ()) -> (),

	SetCancelHandler: (self: Request<T>, callback: () -> ()) -> (),
}

function Request.New<T>(
	uuid: string,
	functionID: string,
	requestType: RequestType.RequestType
): Request<T>
	local self: Request<T> = setmetatable({}, Request) :: any

	self.UUID = uuid
	self.RequestFunctionID = functionID
	self.RequestType = requestType

	self.IsCompleted = false
	self.IsCancelled = false

	self.Response = nil
	self.Error = nil

	self.OnComplete = nil
	self.OnCancel = nil
	self.OnError = nil

	self._CancelHandler = nil

	return self
end

function Request.Complete<T>(self: Request<T>, response: T)
	if self.IsCompleted or self.IsCancelled then
		return
	end

	self.Response = response
	self.IsCompleted = true

	if self.OnComplete then
		self.OnComplete(response)
	end
end

function Request.Cancel<T>(self: Request<T>)
	if self.IsCompleted or self.IsCancelled then
		return
	end

	self.IsCancelled = true

	if self._CancelHandler then
		self._CancelHandler()
	end

	if self.OnCancel then
		self.OnCancel()
	end
end

function Request.Fail<T>(self: Request<T>, message: string)
	if self.IsCompleted or self.IsCancelled then
		return
	end

	self.Error = message
	self.IsCompleted = true

	if self.OnError then
		self.OnError(message)
	end
end

function Request.SetCallback<T>(
	self: Request<T>,
	callback: (response: T) -> ()
)
	self.OnComplete = callback

	if self.IsCompleted and self.Error == nil then
		callback(self.Response :: T)
	end
end

function Request.SetCancelCallback<T>(
	self: Request<T>,
	callback: () -> ()
)
	self.OnCancel = callback

	if self.IsCancelled then
		callback()
	end
end

function Request.SetErrorCallback<T>(
	self: Request<T>,
	callback: (message: string) -> ()
)
	self.OnError = callback

	if self.IsCompleted and self.Error ~= nil then
		callback(self.Error)
	end
end

function Request.SetCancelHandler<T>(
	self: Request<T>,
	callback: () -> ()
)
	self._CancelHandler = callback

	if self.IsCancelled then
		callback()
	end
end

return Request
