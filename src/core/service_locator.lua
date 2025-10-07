-- src/core/service_locator.lua
local ServiceLocator = {}
local services = {}

function ServiceLocator.register(name, service)
    assert(name and service, "Invalid service registration")
    services[name] = service
end

function ServiceLocator.get(name)
    local service = services[name]
    assert(service, "Service not found: " .. tostring(name))
    return service
end

function ServiceLocator.clear()
    services = {}
end

return ServiceLocator