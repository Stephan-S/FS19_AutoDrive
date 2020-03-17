ADMessagesManager = {}
ADMessagesManager.messageTypes = {}
ADMessagesManager.messageTypes.INFO = 1
ADMessagesManager.messageTypes.WARN = 2
ADMessagesManager.messageTypes.ERROR = 3
ADMessagesManager.messageTypeColors = {{1, 1, 1}, {1, 1, 0}, {1, 0, 0}}

ADMessagesManager.messages = {}
ADMessagesManager.currentMessage = nil
ADMessagesManager.currentMessageTimer = 0

ADMessagesManager.notifications = {}
ADMessagesManager.currentNotification = nil
ADMessagesManager.currentNotificationTimer = 0

ADMessagesManager.lastNotificationVehicle = nil

function ADMessagesManager:load()
    self.messages = Queue:new()
    self.notifications = Queue:new()
end

function ADMessagesManager:addInfoMessage(text, duration)
    self:addMessage(self.messageTypes.INFO, text, duration)
end

function ADMessagesManager:addWarnMessage(text, duration)
    self:addMessage(self.messageTypes.WARN, text, duration)
end

function ADMessagesManager:addErrorMessage(text, duration)
    self:addMessage(self.messageTypes.ERROR, text, duration)
end

function ADMessagesManager:addMessage(messageType, text, duration)
    self.messages:Enqueue({messageType = messageType, text = text, duration = duration})
end

function ADMessagesManager:addNotification(vehicle, messageType, text, duration)
    self.notifications:Enqueue({vehicle = vehicle, messageType = messageType, text = text, duration = duration})
end

function ADMessagesManager:removeCurrentMessage()
    self.currentMessage = nil
    self.currentMessageTimer = 0
end

function ADMessagesManager:removeCurrentNotification()
    self.currentNotification = nil
    self.currentNotificationTimer = 0
end

function ADMessagesManager:update(dt)
    -- messages handling
    if self.currentMessage == nil then
        self.currentMessage = self.messages:Dequeue()
    else
        self.currentMessageTimer = self.currentMessageTimer + dt
        -- if we have more messages in queue we decrease their lifespan
        local lifeSpan = self.currentMessage.duration
        if self.messages:Count() > 0 then
            lifeSpan = lifeSpan / 2
        end
        if self.currentMessageTimer >= lifeSpan then
            self:removeCurrentMessage()
        end
    end

    -- notifications handling
    if self.currentNotification == nil then
        self.currentNotification = self.notifications:Dequeue()
        if self.currentNotification ~= nil then
            self.lastNotificationVehicle = self.currentNotification.vehicle
        end
    else
        self.currentNotificationTimer = self.currentNotificationTimer + dt
        if self.currentNotificationTimer >= self.currentNotification.duration then
            self:removeCurrentNotification()
        end
    end
end

function ADMessagesManager:draw()
    -- TODO: we should implement some kind of hud instead of a simple text, maybe with also a dismiss button
    if self.currentMessage ~= nil then
        local color = self.messageTypeColors[self.currentMessage.messageType]
        setTextColor(color[1], color[2], color[3], 1)
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(0.5, 0.14, 0.016, self.currentMessage.text)
        setTextColor(1, 1, 1, 1)
    end

    if self.currentNotification ~= nil then
        local color = self.messageTypeColors[self.currentNotification.messageType]
        setTextColor(color[1], color[2], color[3], 1)
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(0.5, 0.86, 0.017, self.currentNotification.text)
        setTextColor(1, 1, 1, 1)
    end
end
