-- src/core/service_locator.lua
local ServiceLocator = {}
local services = {}

-- Private storage
local services = {}
local serviceMetadata = {}
local debugMode = false

-- Configuration
ServiceLocator.DEBUG = false -- Set to true for verbose logging

-- Register a service with optional metadata
-- @param name string: Unique service identifier
-- @param service any: The service instance
-- @param metadata table: Optional metadata (dependencies, version, etc.)
function ServiceLocator.register(name, service, metadata)
    assert(type(name) == "string" and #name > 0, "Service name must be a non-empty string")
    assert(service ~= nil, "Cannot register nil service: " .. name)

    if services[name] then
        local msg = string.format("[ServiceLocator] WARNING: Service '%s' already registered. Overwriting.", name)
        print(msg)
    end

    services[name] = service
    serviceMetadata[name] = metadata or {}
    serviceMetadata[name].registrationTime = love.timer.getTime()

    if ServiceLocator.DEBUG then
        print(string.format("[ServiceLocator] Registered service: %s (type: %s)", name, type(service)))
    end
end

-- Get a registered service
-- @param name string: Service identifier
-- @return any: The service instance
function ServiceLocator.get(name)
    local service = services[name]

    if not service then
        local availableServices = {}
        for serviceName, _ in pairs(services) do
            table.insert(availableServices, serviceName)
        end
        table.sort(availableServices)

        local errorMsg = string.format(
            "[ServiceLocator] Service not found: '%s'\nAvailable services: %s",
            name,
            table.concat(availableServices, ", ")
        )
        error(errorMsg)
    end
    
    return service
end

-- Check if a service is registered
-- @param name string: Service identifier
-- @return boolean: True if service exists
function ServiceLocator.has(name)
    return services[name] ~= nil
end

-- Try to get a service, return nil if not found (safe version)
-- @param name string: Service identifier
-- @return any|nil: The service instance or nil
function ServiceLocator.tryGet(name)
    return services[name]
end

-- Unregister a service
-- @param name string: Service identifier
function ServiceLocator.unregister(name)
    if services[name] then
        services[name] = nil
        serviceMetadata[name] = nil

        if ServiceLocator.DEBUG then
            print(string.format("[ServiceLocator] Unregistered service: %s", name))
        end
    else
        print(string.format("[ServiceLocator] WARNING: Attempted to unregister non-existent service: %s", name))
    end
end

-- Clear all registered services
function ServiceLocator.clear()
    if ServiceLocator.DEBUG then
        print("[ServiceLocator] Clearing all services")
    end

    services = {}
    serviceMetadata = {}
end

-- Get all registered service names
-- @return table: Array of service names
function ServiceLocator.getAllServiceNames()
    local names = {}
    for name, _ in pairs(services) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- Get metadata for a service
-- @param name string: Service identifier
-- @return table|nil: Service metadata or nil
function ServiceLocator.getMetadata(name)
    return serviceMetadata[name]
end

-- Print debug information about all services
function ServiceLocator.printDebugInfo()
    print("\n=== ServiceLocator Debug Info ===")
    print(string.format("Total services registered: %d", ServiceLocator.getServiceCount()))

    local names = ServiceLocator.getAllServiceNames()
    for _, name in ipairs(names) do
        local service = services[name]
        local meta = serviceMetadata[name]
        local serviceType = type(service)

        if serviceType == "table" and service.__index then
            serviceType = "class instance"
        end

        print(string.format("  - %s: %s (registered: %.2fs ago)",
            name,
            serviceType,
            meta.registrationTime and (love.timer.getTime() - meta.registrationTime) or 0
        ))
    end
    print("=================================\n")
end

-- Get count of registered services
-- @return number: Number of services
function ServiceLocator.getServiceCount()
    local count = 0
    for _ in pairs(services) do
        count = count + 1
    end
    return count
end

-- Validate that required services are registered
-- @param requiredServices table: Array of service names
-- @return boolean, table: success, array of missing services
function ServiceLocator.validateServices(requiredServices)
    local missing = {}

    for _, serviceName in ipairs(requiredServices) do
        if not ServiceLocator.has(serviceName) then
            table.insert(missing, serviceName)
        end
    end

    if #missing > 0 then
        return false, missing
    end

    return true, {}
end

-- Enable or disable debug mode
-- @param enabled boolean: Debug mode state
function ServiceLocator.setDebugMode(enabled)
    ServiceLocator.DEBUG = enabled
    print(string.format("[ServiceLocator] Debug mode: %s", enabled))
end

return ServiceLocator