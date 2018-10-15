local RunService = game:GetService 'RunService'
local Workspace = game:GetService 'Workspace'
local Players = game:GetService 'Players'
local ContextActionService = game:GetService 'ContextActionService'
local UserInputService = game:GetService 'UserInputService'
local GuiService = game:GetService 'GuiService'

-- Libraries
local Maid = require(script.Parent:WaitForChild 'Maid')
local Support = require(script.Parent:WaitForChild 'SupportLibrary')

-- Create class
local Handles = {}
Handles.__index = Handles

function Handles.new(Options)
    local self = setmetatable({}, Handles)

    -- Create maid for cleanup on destroyal
    self.Maid = Maid.new()

    -- Create UI container
    local Gui = Instance.new('ScreenGui')
    self.Gui = Gui
    Gui.Name = 'BTHandles'
    Gui.IgnoreGuiInset = true
    self.Maid.Gui = Gui

    -- Get camera and viewport information
    self.Camera = Workspace.CurrentCamera
    self.GuiInset = GuiService:GetGuiInset()

    -- Get list of ignorable handle obstacles
    self.ObstacleBlacklistIndex = Support.FlipTable(Options.ObstacleBlacklist or {})
    self.ObstacleBlacklist = Support.Keys(self.ObstacleBlacklistIndex)

    -- Generate a handle for each side
    self.Handles = {}
    self.HandleStates = {}
    for _, Side in ipairs(Enum.NormalId:GetEnumItems()) do

        -- Create handle
        local Handle = Instance.new('ImageButton')
        Handle.Name = Side.Name
        Handle.Image = 'rbxassetid://2347145012'
        Handle.ImageColor3 = Options.Color
        Handle.ImageTransparency = 0.33
        Handle.AnchorPoint = Vector2.new(0.5, 0.5)
        Handle.BackgroundTransparency = 1
        Handle.BorderSizePixel = 0
        Handle.ZIndex = 1

        -- Create handle dot
        local HandleDot = Handle:Clone()
        HandleDot.Active = false
        HandleDot.Size = UDim2.new(0, 4, 0, 4)
        HandleDot.Position = UDim2.new(0.5, 0, 0.5, 0)
        HandleDot.Parent = Handle
        HandleDot.ZIndex = 0

        -- Create maid for handle cleanup
        local HandleMaid = Maid.new()
        self.Maid[Side.Name] = HandleMaid

        -- Add handle hover effect
        HandleMaid.HoverStart = Handle.MouseEnter:Connect(function ()
            Handle.ImageTransparency = 0
        end)
        HandleMaid.HoverEnd = Handle.MouseLeave:Connect(function ()
            Handle.ImageTransparency = 0.33
        end)

        -- Listen for handle interactions on click
        HandleMaid.DragStart = Handle.MouseButton1Down:Connect(function (X, Y)
            local InitialHandlePlane = self.HandleStates[Handle].PlaneNormal
            local InitialSideNormal = self.HandleStates[Handle].SideNormal
            local InitialHandlePoint = self.HandleStates[Handle].WorldPoint

            -- Calculate dragging distance offset
            local AimRay = self.Camera:ViewportPointToRay(X, Y)
            local AimDistance = (InitialHandlePoint - AimRay.Origin):Dot(InitialHandlePlane) / AimRay.Direction:Dot(InitialHandlePlane)
            local AimWorldPoint = (AimDistance * AimRay.Direction) + AimRay.Origin
            local DragDistanceOffset = InitialSideNormal:Dot(AimWorldPoint - InitialHandlePoint)

            -- Run callback
            if Options.OnDragStart then
                Options.OnDragStart()
            end

            local function ProcessDragChange(AimScreenPoint)

                -- Calculate distance dragged
                local AimRay = self.Camera:ScreenPointToRay(AimScreenPoint.X, AimScreenPoint.Y)
                local AimDistance = (InitialHandlePoint - AimRay.Origin):Dot(InitialHandlePlane) / AimRay.Direction:Dot(InitialHandlePlane)
                local AimWorldPoint = (AimDistance * AimRay.Direction) + AimRay.Origin
                local DragDistance = InitialSideNormal:Dot(AimWorldPoint - InitialHandlePoint) - DragDistanceOffset

                -- Run drag callback
                if Options.OnDrag then
                    Options.OnDrag(Side, DragDistance)
                end

            end

            -- Create maid for dragging cleanup
            local DragMaid = Maid.new()
            HandleMaid.Dragging = DragMaid

            -- Perform dragging when aiming anywhere (except handle)
            DragMaid.Drag = Support.AddUserInputListener('Changed', {'MouseMovement', 'Touch'}, true, function (Input)
                ProcessDragChange(Input.Position)
            end)

            -- Perform dragging while aiming at handle
            DragMaid.InHandleDrag = Handle.MouseMoved:Connect(function (X, Y)
                local AimScreenPoint = Vector2.new(X, Y) - self.GuiInset
                ProcessDragChange(AimScreenPoint)
            end)

            -- Finish dragging when input ends
            DragMaid.DragEnd = Support.AddUserInputListener('Ended', {'MouseButton1', 'Touch'}, true, function (Input)
                HandleMaid.Dragging = nil
            end)

            -- Fire callback when dragging ends
            DragMaid.Callback = function ()
                spawn(Options.OnDragEnd)
            end

        end)

        -- Finish dragging when input ends while aiming at handle
        HandleMaid.InHandleDragEnd = Handle.MouseButton1Up:Connect(function ()
            HandleMaid.Dragging = nil
        end)

        -- Save handle
        Handle.Parent = self.Gui
        self.Handles[Side.Name] = Handle

    end

    -- Enable handle
    self:SetAdornee(Options.Adornee)
    self.Gui.Parent = Options.Parent

    -- Return new handles
    return self
end

function Handles:Hide()

    -- Make sure handles are enabled
    if not self.Running then
        return self
    end

    -- Pause updating
    self:Pause()

    -- Hide UI
    self.Gui.Enabled = false

end

function Handles:Pause()
    self.Running = false
end

local function IsFirstPerson(Camera)
    return (Camera.CFrame.p - Camera.Focus.p).magnitude <= 0.6
end

function Handles:Resume()

    -- Make sure handles are disabled
    if self.Running then
        return self
    end

    -- Allow handles to run
    self.Running = true

    -- Keep handle positions updated
    for Side, Handle in pairs(self.Handles) do
        local UnitVector = Vector3.FromNormalId(Side)
        spawn(function ()
            while self.Running do
                self:UpdateHandle(Handle, UnitVector)
                RunService.RenderStepped:Wait()
            end
        end)
    end

    -- Ignore character whenever character enters first person
    spawn(function ()
        while self.Running do
            local FirstPerson = IsFirstPerson(self.Camera)
            local Character = Players.LocalPlayer.Character
            if Character then
                self.ObstacleBlacklistIndex[Character] = FirstPerson and true or nil
                self.ObstacleBlacklist = Support.Keys(self.ObstacleBlacklistIndex)
            end
            wait(0.2)
        end
    end)

    -- Show UI
    self.Gui.Enabled = true

end

function Handles:SetAdornee(Item)
    -- Return self for chaining

    -- Save new adornee
    self.Adornee = Item
    self.IsAdorneeModel = Item and (Item:IsA 'Model') or nil

    -- Resume handles
    if Item then
        self:Resume()
    else
        self:Hide()
    end

    -- Return handles for chaining
    return self

end

local function WorldToViewportPoint(Camera, Position)

    -- Get viewport position for point
    local ViewportPoint, Visible = Camera:WorldToViewportPoint(Position)
    local CameraDepth = ViewportPoint.Z
    ViewportPoint = Vector2.new(ViewportPoint.X, ViewportPoint.Y)

    -- Adjust position if point is behind camera
    if CameraDepth < 0 then
        ViewportPoint = Camera.ViewportSize - ViewportPoint
    end

    -- Return point and visibility
    return ViewportPoint, CameraDepth, Visible

end

function Handles:BlacklistObstacle(Obstacle)
    if Obstacle then
        self.ObstacleBlacklistIndex[Obstacle] = true
        self.ObstacleBlacklist = Support.Keys(self.ObstacleBlacklistIndex)
    end
end

function Handles:UpdateHandle(Handle, SideUnitVector)
    local Camera = self.Camera

    -- Hide handles if not attached to an adornee
    if not self.Adornee then
        Handle.Visible = false
        return
    end

    -- Get adornee CFrame and size
    local AdorneeCFrame = self.IsAdorneeModel and
        self.Adornee:GetModelCFrame() or
        self.Adornee.CFrame
    local AdorneeSize = self.IsAdorneeModel and
        self.Adornee:GetModelSize() or
        self.Adornee.Size

    -- Calculate CFrame of the handle's side
    local SideCFrame = AdorneeCFrame * CFrame.new(AdorneeSize * SideUnitVector / 2)
    local SideNormal = (SideCFrame.p - AdorneeCFrame.p).unit

    -- Get viewport position of adornee and the side the handle will be on
    local AdorneeViewportPoint, AdorneeCameraDepth = WorldToViewportPoint(Camera, AdorneeCFrame.p)
    local SideViewportPoint, SideCameraDepth, SideVisible = WorldToViewportPoint(Camera, SideCFrame.p)

    -- Display handle if side is visible to the camera
    Handle.Visible = SideVisible

    -- Calculate handle size (12 px, or at least 0.5 studs)
    local StudWidth = 2 * math.tan(math.rad(Camera.FieldOfView) / 2) * SideCameraDepth
    local PixelsPerStud = Camera.ViewportSize.X / StudWidth
    local HandleSize = math.max(12, 0.5 * PixelsPerStud)
    local SpacingSize = math.max(12, 1 * PixelsPerStud)
    Handle.Size = UDim2.new(0, HandleSize, 0, HandleSize)

    -- Calculate where handles will appear on the screen
    local HandleViewportOffset = (SideViewportPoint - AdorneeViewportPoint).Unit * SpacingSize
    local HandleViewportPosition = SideViewportPoint + HandleViewportOffset
    Handle.Position = UDim2.new(
        0, HandleViewportPosition.X,
        0, HandleViewportPosition.Y
    )

    -- Calculate where handles will appear in the world
    local HandleRay = Camera:ViewportPointToRay(HandleViewportPosition.X, HandleViewportPosition.Y)
    local HandlePlaneNormal = (Handle.Name == 'Top' or Handle.Name == 'Bottom') and
        AdorneeCFrame.LookVector or
        AdorneeCFrame.UpVector
    local HandleCameraDepth = (SideCFrame.p - HandleRay.Origin):Dot(HandlePlaneNormal) / HandleRay.Direction:Dot(HandlePlaneNormal)
    local HandleWorldPoint = (HandleCameraDepth * HandleRay.Direction) + HandleRay.Origin

    -- Save handle position
    local HandleState = self.HandleStates[Handle] or {}
    self.HandleStates[Handle] = HandleState
    HandleState.PlaneNormal = HandlePlaneNormal
    HandleState.WorldPoint = HandleWorldPoint
    HandleState.SideNormal = SideNormal

    -- Hide handles if obscured by a non-blacklisted part
    local TargetRay = Ray.new(HandleRay.Origin, HandleRay.Direction * (HandleCameraDepth - 0.25))
    local Target, TargetPoint = Workspace:FindPartOnRayWithIgnoreList(TargetRay, self.ObstacleBlacklist)
    if Target then
        Handle.ImageTransparency = 1
    elseif Handle.ImageTransparency == 1 then
        Handle.ImageTransparency = 0.33
    end

end

function Handles:Destroy()

    -- Pause updating
    self.Running = nil

    -- Clean up resources
    self.Maid:Destroy()

end

return Handles