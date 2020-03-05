AutoDriveMessagesManager = {}
AutoDriveMessagesManager.messageTypes = {}
AutoDriveMessagesManager.messageTypes.INFO = 1
AutoDriveMessagesManager.messageTypes.WARN = 2
AutoDriveMessagesManager.messageTypes.ERROR = 3
AutoDriveMessagesManager.messageTypeColors = {{1, 1, 1}, {1, 1, 0}, {1, 0, 0}}

AutoDriveMessagesManager.messages = {}
AutoDriveMessagesManager.currentMessage = nil
AutoDriveMessagesManager.currentMessageTimer = 0

AutoDriveMessagesManager.notifications = {}
AutoDriveMessagesManager.currentNotification = nil
AutoDriveMessagesManager.currentNotificationTimer = 0

AutoDriveMessagesManager.lastNotificationVehicle = nil

function AutoDriveMessagesManager:load()
    self.messages = Queue:new()
    self.notifications = Queue:new()
end

function AutoDriveMessagesManager:addInfoMessage(text, duration)
    self:addMessage(self.messageTypes.INFO, text, duration)
end

function AutoDriveMessagesManager:addWarnMessage(text, duration)
    self:addMessage(self.messageTypes.WARN, text, duration)
end

function AutoDriveMessagesManager:addErrorMessage(text, duration)
    self:addMessage(self.messageTypes.ERROR, text, duration)
end

function AutoDriveMessagesManager:addMessage(messageType, text, duration)
    self.messages:Enqueue({messageType = messageType, text = text, duration = duration})
end

function AutoDriveMessagesManager:addNotification(vehicle, messageType, text, duration)
    self.notifications:Enqueue({vehicle = vehicle, messageType = messageType, text = text, duration = duration})
end

function AutoDriveMessagesManager:removeCurrentMessage()
    self.currentMessage = nil
    self.currentMessageTimer = 0
end

function AutoDriveMessagesManager:removeCurrentNotification()
    self.currentNotification = nil
    self.currentNotificationTimer = 0
end

function AutoDriveMessagesManager:update(dt)
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

function AutoDriveMessagesManager:draw()
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
