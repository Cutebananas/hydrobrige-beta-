--[[
PASTE THIS INTO AUTO EXECUTE
    HYDROBRIDGE V5.1: ye, definitely improved sth
    - Fixed lots of flaws from the old version
    - Removed BindToClose (Fixed Server-Only Error)
    - Added Heartbeat-only cleanup
--]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

local FOLDER = "hydrobridge"
local SECRET_KEY = "SECURE_KEY_123"
local JOB_ID = (game.JobId ~= "" and game.JobId) or "STUDIO"
local MY_FILE_NAME = string.format("%s_%s.json", LocalPlayer.Name, JOB_ID:sub(1, 8))
local MY_FILE_PATH = FOLDER .. "/" .. MY_FILE_NAME

if not isfolder(FOLDER) then makefolder(FOLDER) end

getgenv().hydrobridge = { InstanceId = 0 }
local hb = getgenv().hydrobridge

local function safeDecode(str)
    local s, r = pcall(HttpService.JSONDecode, HttpService, str)
    return s and r or nil
end

local function safeEncode(tbl)
    local s, r = pcall(HttpService.JSONEncode, HttpService, tbl)
    return s and r or "{}"
end

local function cleanup()
    local files = listfiles(FOLDER)
    local now = os.time()
    for _, path in ipairs(files) do
        local lastMod = 0
        pcall(function()
            local data = safeDecode(readfile(path))
            lastMod = data and data.lastHeartbeat or 0
        end)
        if now - lastMod > 15 then pcall(delfile, path) end
    end
end

local function updateInstanceId()
    local files = listfiles(FOLDER)
    local activeJson = {}
    for _, path in ipairs(files) do
        if path:sub(-5) == ".json" then table.insert(activeJson, path) end
    end
    table.sort(activeJson)
    for i, path in ipairs(activeJson) do
        if path:find(MY_FILE_NAME, 1, true) then
            if hb.InstanceId ~= i then
                hb.InstanceId = i
                local ui = game:GetService("CoreGui"):FindFirstChild("HydroBridgeUI") or LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("HydroBridgeUI")
                if ui then ui.TextLabel.Text = "BRIDGE ID: " .. i end
            end
            return i
        end
    end
end

local function createUI(id)
    local sg = Instance.new("ScreenGui")
    sg.Name = "HydroBridgeUI"
    local label = Instance.new("TextLabel", sg)
    label.Size = UDim2.new(0, 140, 0, 30)
    label.Position = UDim2.new(1, -150, 0, 10)
    label.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    label.TextColor3 = Color3.fromRGB(0, 255, 150)
    label.Text = "BRIDGE ID: " .. id
    label.Font = Enum.Font.Code
    label.BorderSizePixel = 0
    local success = pcall(function() sg.Parent = game:GetService("CoreGui") end)
    if not success then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end

hb.execute = function(id, code)
    local files = listfiles(FOLDER)
    local activeJson = {}
    for _, p in ipairs(files) do if p:sub(-5) == ".json" then table.insert(activeJson, p) end end
    table.sort(activeJson)
    local target = activeJson[id]
    if target then
        local data = safeDecode(readfile(target)) or {commands = {}}
        table.insert(data.commands, {script = code, secret = SECRET_KEY})
        writefile(target, safeEncode(data))
        return true
    end
    return false
end

hb.executeAll = function(code)
    local files = listfiles(FOLDER)
    for _, path in ipairs(files) do
        if path:sub(-5) == ".json" then
            local data = safeDecode(readfile(path)) or {commands = {}}
            table.insert(data.commands, {script = code, secret = SECRET_KEY})
            writefile(path, safeEncode(data))
        end
    end
end

task.spawn(function()
    cleanup()
    writefile(MY_FILE_PATH, safeEncode({lastHeartbeat = os.time(), commands = {}}))
    task.wait(math.random(1, 100) / 100)
    updateInstanceId()
    createUI(hb.InstanceId)
    
    while task.wait(1) do
        updateInstanceId()
        local content = isfile(MY_FILE_PATH) and readfile(MY_FILE_PATH) or "{}"
        local data = safeDecode(content) or {commands = {}}
        if #data.commands > 0 then
            for _, cmd in ipairs(data.commands) do
                if cmd.secret == SECRET_KEY then
                    task.spawn(function()
                        local func, err = loadstring(cmd.script)
                        if func then pcall(func) end
                    end)
                end
            end
            data.commands = {}
        end
        data.lastHeartbeat = os.time()
        pcall(writefile, MY_FILE_PATH, safeEncode(data))
    end
end)
