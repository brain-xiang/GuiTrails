-- Trail Module
-- Username
-- February 27, 2021



local TrailModule = {}
TrailModule.__index = TrailModule
local RunService = game:GetService("RunService")
local Player = game.Players.LocalPlayer

function TrailModule.new(element, lifetime, size, color, zindex, sizeScale, transparency, image, connectorEnabled)
    --[[
        input:
            element = gui element trail follows
            lifetime = int, lifetime of each generated trail particle
            size = Udim2, size of the trail particles, relative to element size if scale
            color = Color3 or NumberSequence, the color of the trail, and how it cahnges over time
            zindex = Trail ZIndex, indicating which layer it is on
            sizeScale = NumberSequence or int, how the trail particles' size changes over time
            transparency = NumberSequence or int, how the trail particles' transparency changes over
            image = ImageId, trail particles image
            connectorEnabled = bool, determins whether there are generated connectors between particles
    ]]

    local self = setmetatable({}, TrailModule)

    -- Default values
    self.element = element
    self.lifetime = lifetime or 1
    self.size = size or UDim2.new(1,0,1,0)
    self.color = (typeof(color) == "Color3" and ColorSequence.new(color) or color) or ColorSequence.new(Color3.new(255,255,255))
    self.zindex = zindex or 1
    self.sizeScale = (typeof(sizeScale) == "number" and NumberSequence.new(sizeScale) or sizeScale) or NumberSequence.new(1, 0)
    self.transparency = (typeof(transparency) == "number" and NumberSequence.new(transparency) or transparency) or NumberSequence.new(0)
    self.image = image or "http://www.roblox.com/asset/?id=6454402144"
    self.connectorEnabled = connectorEnabled or true
    self.trailParticles = {}
    self.connectors = {}
    self.Enabled = true

    -- finding/constructing a folder for the trail to recide in
    self.ScreenGui = getScreenGui(self.element)
    if self.ScreenGui:FindFirstChild("Trail") and self.ScreenGui.Trail.ClassName == "Folder" then
        self.folder = self.ScreenGui.Trail
    else
        self.folder = Instance.new("Folder")
        self.folder.Parent = self.ScreenGui
        self.folder.Name = "Trail"
    end
    

    local lastPos = self.element.AbsolutePosition
    self.loop = RunService.RenderStepped:Connect(function()
        local currentTick = tick()

        -- Extending/adding to trail
        if self.Enabled and self.element.AbsolutePosition ~= lastPos then
            
            -- Creating particle
            local particle = self:createParticle()
            self.trailParticles[particle] = currentTick
            
            -- Creating connector if enabled
            if self.connectorEnabled then
                local Connector = self:createConnector(lastPos)
                self.connectors[Connector] = currentTick
            end
            
            lastPos = self.element.AbsolutePosition
        end

        -- uppdating existing trail
        for particle, startTime in pairs(self.trailParticles) do
            local aliveTime = currentTick - startTime
            self:uppdateParticle(particle, aliveTime)
        end
        if self.connectorEnabled then
            for connector, startTime in pairs(self.connectors) do
                local aliveTime = currentTick - startTime
                self:uppdateConnector(connector, aliveTime)
            end
        end
    end)

    return self
end

function TrailModule:Destroy()
    --[[
        Destroys the trail object
    ]]

    self.Enabled = false
    repeat wait() until next(self.trailParticles) == nil
    -- DIsconnect loop
    self.loop:Disconnect()

    -- Destroys trail
    for particle,v in pairs(self.trailParticles) do
        particle:Destroy()
    end
    for Connector,v in pairs(self.connectors) do
        Connector:Destroy()
    end
    
    return nil
end

function TrailModule:uppdateConnector(connector, aliveTime)
    --[[
        Uppdates a connectors's changes over time, and handles destruction
    ]]

    if aliveTime > self.lifetime then
        self.connectors[connector] = nil
        connector:Destroy()
    else
        local currentSizeScale = evalNS(self.sizeScale, aliveTime/self.lifetime)
        local width = self.size.Y.Scale * self.element.AbsoluteSize.Y + self.size.Y.Offset
        connector.Size = UDim2.new(0, connector.Size.X.Offset, 0, width * currentSizeScale)
        connector.BackgroundTransparency = evalNS(self.transparency, aliveTime/self.lifetime)
        connector.BackgroundColor3 = evalCS(self.color, aliveTime/self.lifetime)
    end
end

function TrailModule:createConnector(lastPos)
    --[[
        returns: Frame, connector configured with properties and placed to connect last 2 particles
    ]]

    local Connector = Instance.new("Frame")
    Connector.Parent = self.folder
    Connector.AnchorPoint = Vector2.new(0.5,0.5)
    Connector.BorderSizePixel = 0
    Connector.ZIndex = self.zindex

    local point1 = Vector2.new(self.element.AbsolutePosition.X + self.element.AbsoluteSize.X/2, self.element.AbsolutePosition.Y+ self.element.AbsoluteSize.Y/2)
    local point2 = Vector2.new(lastPos.X + self.element.AbsoluteSize.X/2, lastPos.Y + self.element.AbsoluteSize.Y/2)
    local position, rotation, length = getPropertiesBridgingGap(point1, point2)
    local ScreenGuiOffset = UDim2.new(0, self.ScreenGui.AbsolutePosition.X, 0, self.ScreenGui.AbsolutePosition.Y) -- Caused by ignoreGuiInset
    Connector.Position = position - ScreenGuiOffset
    Connector.Rotation = rotation
    Connector.Size = UDim2.new(0, length, self.size.Y.Scale, self.size.Y.Offset)

    return Connector
end

function TrailModule:uppdateParticle(particle, aliveTime)
    --[[
        Uppdates a particle's changes over time, and handles destruction
    ]]

    if aliveTime > self.lifetime then
        self.trailParticles[particle] = nil
        particle:Destroy()
    else
        local currentSizeScale = evalNS(self.sizeScale, aliveTime/self.lifetime)
        local absoluteSize = Vector2.new(
            self.size.X.Scale * self.element.AbsoluteSize.X + self.size.X.Offset, 
            self.size.Y.Scale * self.element.AbsoluteSize.Y + self.size.Y.Offset
        )
        particle.Size = UDim2.new(0, absoluteSize.X * currentSizeScale, 0, absoluteSize.Y * currentSizeScale)
        particle.ImageTransparency = evalNS(self.transparency, aliveTime/self.lifetime)
        particle.ImageColor3 = evalCS(self.color, aliveTime/self.lifetime)
    end
end

function TrailModule:createParticle()
    --[[
        returns: ImageLabel, particle configured with properties
    ]]

    local particle = Instance.new("ImageLabel")
    particle.Parent = self.folder
    particle.Image = self.image
    particle.BackgroundTransparency = 1
    particle.ZIndex = self.zindex
    particle.AnchorPoint = Vector2.new(0.5,0.5)
    local absolutePosition = UDim2.new(0, self.element.AbsolutePosition.X + self.element.AbsoluteSize.X/2, 0, self.element.AbsolutePosition.Y+ self.element.AbsoluteSize.Y/2)
    local ScreenGuiOffset = UDim2.new(0, self.ScreenGui.AbsolutePosition.X, 0, self.ScreenGui.AbsolutePosition.Y) -- Caused by ignoreGuiInset
    particle.Position = absolutePosition - ScreenGuiOffset
    
    return particle
end

function getPropertiesBridgingGap(Point1, Point2)
    --[[
        input: vector2's
        
        calculates the properties a gui Object needs to fill the gap between Point1 and Point2

        returns: position = Udim2, Rotation = int, length = int
    ]]
    local connectingVector = Point2 - Point1
    local flatVector = Vector2.new(connectingVector.X, 0)
    
    local length = connectingVector.Magnitude
    local position = Point1 + (connectingVector * 0.5)
    position = UDim2.new(0, position.X, 0, position.Y) -- converting to Udim

    -- calculating inverse since magnitude gets rid of negatives, 1 or -1
    local inverse = (connectingVector.X / math.abs(connectingVector.X)) * (connectingVector.Y / math.abs(connectingVector.Y)) 
    local rotation = math.deg(math.acos(flatVector.Magnitude/connectingVector.Magnitude)) * inverse

    return position, rotation, length
end

function absoluteToLocalPosition(absolutePosition, localElement)
    --[[
        input: absolutePosition = Vector2, localElement = GuiObject
        returns: Udim2 offset, An absolute Position on the screen in form of a local position to the element provided
    ]]
    local x = absolutePosition.X - localElement.AbsolutePosition.X
    local y = absolutePosition.Y - localElement.AbsolutePosition.Y
    return UDim2.new(0, x, 0, y)
end

function getScreenGui(gui)
    --[[
        runs recursion checks of gui's parent until ScreenGui is found
        returns: ScreenGui
    ]]
    if gui.ClassName == "ScreenGui" then
        return gui
    else
       return getScreenGui(gui.Parent) 
    end
end

function evalCS(cs, time)
    --[[
        input: cs = ColorSequence, time = int, time fraction, 0 to 1
        returns: the value in teh COlorSequence at that time period
    ]]

	-- If we are at 0 or 1, return the first or last value respectively
	if time == 0 then return cs.Keypoints[1].Value end
	if time == 1 then return cs.Keypoints[#cs.Keypoints].Value end
	-- Step through each sequential pair of keypoints and see if alpha
	-- lies between the points' time values.
	for i = 1, #cs.Keypoints - 1 do
		local this = cs.Keypoints[i]
		local next = cs.Keypoints[i + 1]
		if time >= this.Time and time < next.Time then
			-- Calculate how far alpha lies between the points
			local alpha = (time - this.Time) / (next.Time - this.Time)
			-- Evaluate the real value between the points using alpha
			return Color3.new(
				(next.Value.R - this.Value.R) * alpha + this.Value.R,
				(next.Value.G - this.Value.G) * alpha + this.Value.G,
				(next.Value.B - this.Value.B) * alpha + this.Value.B
			)
		end
	end
end

function evalNS(ns, time)
    --[[
        input: ns = NumberSequence, time = int, time fraction, 0 to 1
        returns: the value in the NumberSequence at that time period
    ]]

	-- If we are at 0 or 1, return the first or last value respectively
	if time == 0 then return ns.Keypoints[1].Value end
	if time == 1 then return ns.Keypoints[#ns.Keypoints].Value end
	-- Step through each sequential pair of keypoints and see if alpha
	-- lies between the points' time values.
	for i = 1, #ns.Keypoints - 1 do
		local this = ns.Keypoints[i]
		local next = ns.Keypoints[i + 1]
		if time >= this.Time and time < next.Time then
			-- Calculate how far alpha lies between the points
			local alpha = (time - this.Time) / (next.Time - this.Time)
			-- Evaluate the real value between the points using alpha
			return (next.Value - this.Value) * alpha + this.Value
		end
	end
end

return TrailModule