--[[
    HYDROBRIDGE V6.0: Optimized & Refactored
    - Implemented Throttling: ID updates and Cleanup run on slower intervals to save CPU.
    - Robust Error Handling: Better JSON safety and pcall wrapping.
    - Persistent Cleanup: Garbage collection now runs periodically, not just once.
    - Non-Blocking IO: Added yields during heavy file operations.
    - Modular Structure: Separated UI, FileSystem, and Bridge logic.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

--CONFIGURATION
local CONFIG = {
    Folder = "hydrobridge",
    SecretKey = "SECURE_KEY_123", -- In production, use a dynamic or obfuscated key
    HeartbeatInterval = 1.0,       -- How often to check for commands/update presence
    CleanupInterval = 10.0,        -- How often to clear dead files (saves performance)
    TimeoutSeconds = 15,           -- Time before a file is considered dead
    JobId = (game.JobId ~= "" and game.JobId) or "STUDIO"
}

--STATE
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
local MyFileName = string.format("%s_%s.json", LocalPlayer.Name, CONFIG.JobId:sub(1, 8))
local MyFilePath = CONFIG.Folder .. "/" .. MyFileName

-- Ensure Environment
if not isfolder(CONFIG.Folder) then makefolder(CONFIG.Folder) end

-- Initialize Global Table
getgenv().hydrobridge = getgenv().hydrobridge or {}
local Bridge = getgenv().hydrobridge
Bridge.InstanceId = 0

-- UTILITIES

local function Log(msg)
    -- Optional: print("[HydroBridge]: " .. tostring(msg))
end

local function SafeDecode(str)
    if not str or str == "" then return nil end
    local success, result = pcall(HttpService.JSONDecode, HttpService, str)
    return success and result or nil
end

local function SafeEncode(tbl)
    local success, result = pcall(HttpService.JSONEncode, HttpService, tbl)
    return success and result or "{}"
end

local function GetBridgeFiles()
    local files = listfiles(CONFIG.Folder)
    local jsonFiles = {}
    for _, path in ipairs(files) do
        if path:sub(-5) == ".json" then
            table.insert(jsonFiles, path)
        end
    end
    table.sort(jsonFiles)
    return jsonFiles
end

-- CORE LOGIC

-- Garbage Collection: Removes files from crashed/left instances
local function RunCleanup()
    local files = listfiles(CONFIG.Folder)
    local now = os.time()
    
    for _, path in ipairs(files) do
        -- Wrap in pcall to prevent crash on file access error
        local success, err = pcall(function()
            local content = readfile(path)
            local data = SafeDecode(content)
            
            -- If file is corrupted or timestamp is too old, delete it
            if not data or (data.lastHeartbeat and (now - data.lastHeartbeat > CONFIG.TimeoutSeconds)) then
                delfile(path)
                Log("Cleaned up stale file: " .. path)
            end
        end)
        
        -- Yield briefly every few checks to prevent lag spikes if folder has many files
        if _ % 5 == 0 then task.wait() end 
    end
end

-- ID Calculation: Determines 'Who am I' in the sorting order
local function UpdateInstanceId()
    local activeFiles = GetBridgeFiles()
    
    for i, path in ipairs(activeFiles) do
        if path:find(MyFileName, 1, true) then
            if Bridge.InstanceId ~= i then
                Bridge.InstanceId = i
                return true -- ID Changed
            end
            return false
        end
    end
    return false
end

-- UI Management: Handles the visual indicator
local function UpdateUI()
    local uiName = "HydroBridgeUI"
    local existing = CoreGui:FindFirstChild(uiName) or LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild(uiName)
    
    if existing then
        local label = existing:FindFirstChild("StatusLabel")
        if label then label.Text = "BRIDGE ID: " .. Bridge.InstanceId end
    else
        -- Create UI only if missing
        local sg = Instance.new("ScreenGui")
        sg.Name = uiName
        sg.ResetOnSpawn = false 
        
        local label = Instance.new("TextLabel", sg)
        label.Name = "StatusLabel"
        label.Size = UDim2.new(0, 140, 0, 30)
        label.Position = UDim2.new(1, -150, 0, 10)
        label.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        label.TextColor3 = Color3.fromRGB(0, 255, 150)
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.Text = "BRIDGE ID: " .. Bridge.InstanceId
        label.BorderSizePixel = 0
        
        -- Try CoreGui (Security check), fallback to PlayerGui
        local success = pcall(function() sg.Parent = CoreGui end)
        if not success then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    end
end

-- // API EXPORTS \\ --

Bridge.execute = function(targetId, code)
    local activeFiles = GetBridgeFiles()
    local targetPath = activeFiles[targetId]
    
    if targetPath then
        local content = isfile(targetPath) and readfile(targetPath) or "{}"
        local data = SafeDecode(content) or {commands = {}}
        
        table.insert(data.commands, {
            script = code, 
            secret = CONFIG.SecretKey,
            sender = Bridge.InstanceId
        })
        
        writefile(targetPath, SafeEncode(data))
        return true
    end
    return false
end

Bridge.executeAll = function(code)
    local activeFiles = GetBridgeFiles()
    for _, path in ipairs(activeFiles) do
        task.spawn(function() -- Async write to prevent blocking
            local content = isfile(path) and readfile(path) or "{}"
            local data = SafeDecode(content) or {commands = {}}
            
            table.insert(data.commands, {
                script = code, 
                secret = CONFIG.SecretKey,
                sender = Bridge.InstanceId
            })
            
            writefile(path, SafeEncode(data))
        end)
    end
end

-- // MAIN LOOPS \\ --

-- 1. Heartbeat & Command Processor (Fast Loop)
task.spawn(function()
    Log("HydroBridge Started.")
    
    -- Initial creation
    writefile(MyFilePath, SafeEncode({lastHeartbeat = os.time(), commands = {}}))
    UpdateInstanceId()
    UpdateUI()

    while task.wait(CONFIG.HeartbeatInterval) do
        -- Read my own file
        if isfile(MyFilePath) then
            local content = readfile(MyFilePath)
            local data = SafeDecode(content) or {commands = {}}
            local dirty = false
            
            -- Process Commands
            if data.commands and #data.commands > 0 then
                for _, cmd in ipairs(data.commands) do
                    if cmd.secret == CONFIG.SecretKey then
                        task.spawn(function()
                            local func, syntaxErr = loadstring(cmd.script)
                            if func then 
                                local s, runErr = pcall(func)
                                if not s then warn("[HB Error]:", runErr) end
                            else
                                warn("[HB Syntax]:", syntaxErr)
                            end
                        end)
                    end
                end
                data.commands = {} -- Clear commands after processing
                dirty = true
            end
            
            -- Update Heartbeat
            data.lastHeartbeat = os.time()
            writefile(MyFilePath, SafeEncode(data))
        else
            -- Re-create file if deleted externally
            writefile(MyFilePath, SafeEncode({lastHeartbeat = os.time(), commands = {}}))
        end
    end
end)

-- 2. Cleanup & ID Re-Sync (Slow Loop)
task.spawn(function()
    while task.wait(CONFIG.CleanupInterval) do
        RunCleanup()
        local idChanged = UpdateInstanceId()
        if idChanged then UpdateUI() end
    end
end)
