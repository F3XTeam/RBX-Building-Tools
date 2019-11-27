-- Create class
local InstancePool = {}
InstancePool.__index = InstancePool

function InstancePool.new(Timeout, GenerateCallback, CleanupCallback)

    -- Prepare new pool
    local self = {
        Timeout = Timeout,
        Generate = GenerateCallback,
        Cleanup = CleanupCallback,
        All = {},
        Free = {},
        InUse = {},
        LastUse = {}
    }

    -- Return pool
    return setmetatable(self, InstancePool)

end

function InstancePool:Release(Instance)

    -- Log the last use of this instance
    local ReleaseTime = tick()
    self.LastUse[Instance] = ReleaseTime

    -- Remove instance if not used after timeout
    coroutine.resume(coroutine.create(function ()
        wait(self.Timeout)
        if self.LastUse[Instance] == ReleaseTime then
            self:Remove(Instance)
        end
    end))

    -- Run cleanup routine on instance
    self.Cleanup(Instance)

    -- Free instance
    self.InUse[Instance] = nil
    self.Free[Instance] = true

end

function InstancePool:Get()

    -- Get free instance, or generate a new one
    local Instance = next(self.Free) or self.Generate()

    -- Reserve instance
    self.Free[Instance] = nil
    self.LastUse[Instance] = nil
    self.All[Instance] = true
    self.InUse[Instance] = true

    -- Return instance
    return Instance

end

function InstancePool:Remove(Instance)
    self.Free[Instance] = nil
    self.InUse[Instance] = nil
    self.LastUse[Instance] = nil
    self.All[Instance] = nil
    Instance:Destroy()
end

function InstancePool:ReleaseAll()
    for Instance in pairs(self.InUse) do
        self:Release(Instance)
    end
end

function InstancePool.Generate()
    error('No instance generation callback specified', 2)
end

-- Default cleanup routine (can be overridden)
function InstancePool.Cleanup(Instance)
    Instance.Parent = nil
end

return InstancePool