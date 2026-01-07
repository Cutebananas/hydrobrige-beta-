--[[
    HYDROBRIDGE V4: ENTERPRISE EDITION
    Stability: High | Security: Whitelisted | Multi-Account: Supported
--]]

-- 1. INITIALIZATION & NIL GUARDS
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local JOB_ID = (game.JobId ~= "" and game.JobId) or "STUDIO_SESSION"
local FOLDER = "hydrobridge"
local SECRET_KEY = "SECURE_KEY_123" -- Change this to prevent unauthorized injections
local MY_FILE_PATH = string.format("%s/%s_%s.json", FOLDER, LocalPlayer.Name, JOB_ID:sub(1, 8))

if not isfolder(FOLDER) then makefolder(FOLDER) end

-- 2. STANDARDIZED UTILITIES
local function safeDecode(str)
    if not str or str == "" then return nil end
    local success, result = pcall(function() return HttpService:JSONDecode(str) end)
    return success and result or nil
end

local function safeEncode(tbl)
    local success, result = pcall(function() return HttpService:JSONEncode(tbl) end)
    return success and result or "{}"
end

-- 3. CORE BRIDGE OBJECT
getgenv().hydrobridge = {
    InstanceId = 0,
    Version = "4.0.0"
}
local hb = getgenv().hydrobridge

-- 4. STABLE INSTANCE NUMBERING
local function updateInstanceId()
    local files = listfiles(FOLDER)
    table.sort(files)
    for i, path in ipairs(files) do
        if path:find(LocalPlayer.Name) and path:find(JOB_ID:sub(1, 8)) then
            hb.InstanceId = i
            return i
        end
    end
    return 0
end

-- 5. UI NOTIFICATION SYSTEM
local function createUI(id)
    local coreGui = game:GetService("CoreGui")
    if coreGui:FindFirstChild("HydroBridgeUI") then coreGui.HydroBridgeUI:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "HydroBridgeUI"
    sg.ResetOnSpawn = false
    
    local label = Instance.new("TextLabel", sg)
    label.Size = UDim2.new(0, 160, 0, 25)
    label.Position = UDim2.new(1, -170, 0, 10)
    label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    label.BackgroundTransparency = 0.2
    label.TextColor3 = Color3.fromRGB(0, 200, 255)
    label.Text = "BRIDGE ID: " .. tostring(id)
    label.Font = Enum.Font.Code
    label.TextSize = 14
    
    local success, _ = pcall(function() sg.Parent = coreGui end)
    if not success then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end

-- 6. FAULT-TOLERANT EXECUTION API
hb.execute = function(targetId, scriptStr)
    local files = listfiles(FOLDER)
    table.sort(files)
    local targetPath = files[targetId]
    
    if not targetPath then return false, "Instance not found" end
    
    -- MERGE-ON-WRITE: Prevents overwriting heartbeats or other commands
    local content = isfile(targetPath) and readfile(targetPath) or "{}"
    local data = safeDecode(content) or {commands = {}}
    
    table.insert(data.commands, {
        script = scriptStr,
        secret = SECRET_KEY,
        sentAt = os.time()
    })
    
    pcall(writefile, targetPath, safeEncode(data))
    return true
end

hb.executeAll = function(scriptStr)
    local files = listfiles(FOLDER)
    for i = 1, #files do hb.execute(i, scriptStr) end
end

-- 7. THE MAIN LOOP (HEARTBEAT & COMMAND POLLING)
task.spawn(function()
    updateInstanceId()
    createUI(hb.InstanceId)
    
    while task.wait(1) do
        -- 1. RE-SYNC Instance ID if someone left/joined
        updateInstanceId()
        
        -- 2. FETCH DATA
        local content = isfile(MY_FILE_PATH) and readfile(MY_FILE_PATH) or "{}"
        local data = safeDecode(content) or {commands = {}, lastHeartbeat = 0}
        
        -- 3. PROCESS PENDING COMMANDS
        if data.commands and #data.commands > 0 then
            for _, cmd in ipairs(data.commands) do
                if cmd.secret == SECRET_KEY then
                    task.spawn(function()
                        local func, err = loadstring(cmd.script)
                        if func then 
                            local s, r = pcall(func)
                            if not s then warn("[HYDROBRIDGE] Runtime Error: " .. tostring(r)) end
                        else 
                            warn("[HYDROBRIDGE] Compilation Error: " .. tostring(err)) 
                        end
                    end)
                else
                    warn("[SECURITY] Blocked unsigned command execution attempt.")
                end
            end
            data.commands = {} -- Flush queue after processing
        end
        
        -- 4. UPDATE STATUS & WRITE BACK
        data.lastHeartbeat = os.time()
        data.username = LocalPlayer.Name
        data.jobId = JOB_ID
        
        pcall(writefile, MY_FILE_PATH, safeEncode(data))
    end
end)

print("[HYDROBRIDGE] System active on Instance #" .. tostring(hb.InstanceId))
