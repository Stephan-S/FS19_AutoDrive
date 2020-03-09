MessagesManager = {}
MessagesManager.messageTypes = {}
MessagesManager.messageTypes.INFO = 1
MessagesManager.messageTypes.WARN = 2
MessagesManager.messageTypes.ERROR = 3
MessagesManager.messageTypeColors = {{1, 1, 1}, {1, 1, 0}, {1, 0, 0}}

MessagesManager.messages = {}
MessagesManager.currentMessage = nil
MessagesManager.currentMessageTimer = 0

MessagesManager.notifications = {}
MessagesManager.currentNotification = nil
MessagesManager.currentNotificationTimer = 0

MessagesManager.lastNotificationVehicle = nil

function MessagesManager:load()
    self.messages = Queue:new()
    self.notifications = Queue:new()
end

function MessagesManager:addInfoMessage(text, duration)
    self:addMessage(self.messageTypes.INFO, text, duration)
end

function MessagesManager:addWarnMessage(text, duration)
    self:addMessage(self.messageTypes.WARN, text, duration)
end

function MessagesManager:addErrorMessage(text, duration)
    self:addMessage(self.messageTypes.ERROR, text, duration)
end

function MessagesManager:addMessage(messageType, text, duration)
    self.messages:Enqueue({messageType = messageType, text = text, duration = duration})
end

function MessagesManager:addNotification(vehicle, messageType, text, duration)
    self.notifications:Enqueue({vehicle = vehicle, messageType = messageType, text = text, duration = duration})
end

function MessagesManager:removeCurrentMessage()
    self.currentMessage = nil
    self.currentMessageTimer = 0
end

function MessagesManager:removeCurrentNotification()
    self.currentNotification = nil
    self.currentNotificationTimer = 0
end

function MessagesManager:update(dt)
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

function MessagesManager:draw()
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
