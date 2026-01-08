<p align="center">
  <img src="https://github.com/user-attachments/assets/8b624349-664f-4dff-903f-575fed47a1d7" alt="Cloud Core Logo" width="300">
</p>

## **HYDROBRIDGE V6 and V5 — Documentation and some tutorials**
**basically the same, but v6 is way cleaner and better**
**Hydrobridge** is a file-based communication protocol for Roblox. It allows multiple game instances running on the same machine to "talk" to each other by using the local file system as a data bridge.
(It's something you use for multi-instance script execution)

---

###   Quick Start

1. **Execution:** Paste this script into auto execute.
**If you want to use v5, use this script**
```lua
getgenv().request = http_request
getgenv().http = {request = http_request}

loadstring(game:HttpGet("(https://raw.githubusercontent.com/Cutebananas/hydrobrige-beta/refs/heads/main/hydrobrige%20V5.lua)"))()
```
**If you want V6 (newer version), use this**
```lua
getgenv().request = http_request
http.request = http_request

loadstring(game:HttpGet("https://raw.githubusercontent.com/Cutebananas/hydrobrige-beta/refs/heads/main/hydrobrige%20V6.lua"))()
```
2. **Identification:** A small UI will appear in the top-right corner showing your **BRIDGE ID** (e.g., `BRIDGE ID: 1`).
3. **Communication:** Use the global `hydrobridge` table to send commands between clients.

---

###  For Developers 

The script injects a global table `getgenv().hydrobridge` (shortened to `hb` in the code), which you can call from any other script or your executor's console.

#### **1. Execute on a Specific Instance**

Sends a string of code to be executed by a specific client ID.

```lua
getgenv().hydrobridge.execute(bridge id here, [[
script here boiiiiii
]])

```

#### **2. Execute on All Instances**

Sends a string of code to every active instance (including yourself).

```lua
getgenv().hydrobridge.executeAll([[
script here boiiiiiiiiii
]])
```

#### **3. Conditional Targeting (Logic Gates)**

If you want to send a command to everyone but only have specific accounts react, wrap your code in a logic gate:

```lua
local code = [[
    if game.Players.LocalPlayer.Name == "YourAltName" then
        print("Command received by the target alt.")
    end
    --Keep the part above, paste your script below here
]]
getgenv().hydrobridge.executeAll(code)

```

---
#### **4. Widely used script execution**
```lua
-- executeeeee
local code = [[
script here boiiiiiii
]]
getgenv().hydrobridge.execute(bridge id here, code)
```

###   How it Works (Under the Hood)

* **File Path:** Files are stored in `workspace/hydrobridge/`.
* **Heartbeat:** Each instance updates a `lastHeartbeat` timestamp every second. If an instance doesn't update for 15 seconds, other instances will automatically delete its file to keep the "Bridge IDs" clean.
* **Polling:** Instances check their assigned `.json` file once per second for new strings in the `commands` array.
* **Security:** Only commands containing the correct `SECRET_KEY` ("SECURE_KEY_123") will be executed via `loadstring`.

---

###  Important Notes that ur never read :(((

* **Execution Delay:** There is a polling rate of **1 second**. Commands are not instant; they may take up to 1 second to trigger on the target.
* **Executor Requirements:** Your executor must support `readfile`, `writefile`, `listfiles`, `makefolder`, and `loadstring`.
* **Studio Support:** This script identifies the environment as `"STUDIO"` if a JobId is not present.

---
SHEEEEEESH
