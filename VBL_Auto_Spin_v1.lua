-- Auto Spin Vip Pro | Roblox Luau
-- Normal/Lucky consume real spins. FurHub is loaded only if requested in UI.
-- In historical VBL Roll examples false = Normal. true = Lucky is assumed,
-- NOT verified against the current game. Test Lucky with limit 1 first.
-- Game remotes and UI paths may change after updates.
-- Settings auto-save to a local JSON file if readfile/writefile are supported.
-- Auto Start runs when this script is executed only if explicitly enabled.
-- No queue_on_teleport or auto-execute: the executor handles launching.
-- Optional handoff: after reaching the configured roll LIMIT without the target,
-- execute the FurHub loader. NEVER triggers FurHub's rollback button or payload.
-- FurHub is third-party obfuscated code: enabling this option runs unverified code.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild("PlayerGui")

local env = (type(getgenv) == "function" and getgenv()) or _G
if env.VBLSpinControl and type(env.VBLSpinControl.Close) == "function" then
    pcall(env.VBLSpinControl.Close)
end
local alive, running, starting, token = true, false, false, 0
local gui
local saveOnClose
local function stop()
    starting = false
    running = false
    token = token + 1
end
local controller = { Close = function()
    alive = false
    stop()
    if saveOnClose then pcall(saveOnClose) end
    if gui then gui:Destroy() end
end }
env.VBLSpinControl = controller

local function trim(v)
    return tostring(v or ""):gsub("<[^>]*>", ""):gsub("^%s+", ""):gsub("%s+$", "")
end
local function norm(v)
    return trim(v):lower():gsub("%s+", " ")
end
local function targetsFrom(text)
    local set, count = {}, 0
    for entry in tostring(text):gmatch("[^,;\n]+") do
        local key = norm(entry)
        if key ~= "" and not set[key] then
            set[key] = true
            count = count + 1
        end
    end
    return set, count
end
local function child(root, ...)
    for _, name in ipairs({...}) do
        if not root then return nil end
        root = root:FindFirstChild(name)
    end
    return root
end
local function getText(obj)
    if obj and (obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton")) then
        local s = trim(obj.Text)
        if s ~= "" then return s end
    end
    return nil
end

local function equippedStyle()
    local styles = child(playerGui, "Interface", "Lobby", "Styles")
    local name = getText(child(styles, "TopPanel", "DisplayName"))
    if name then return name end
    local char = player.Character
    local object = child(char, "JerseyBack", "StyleName")
    if object then
        if object:IsA("StringValue") then return trim(object.Value) end
        return getText(object)
    end
    return nil
end
local function equippedAbility()
    local abilities = child(playerGui, "Interface", "Lobby", "Abilities")
    if not abilities then return nil end
    -- Find the currently EQUIPPED ability instead of a random ability list item.
    for _, node in ipairs(abilities:GetDescendants()) do
        if node:IsA("TextLabel") and node.Name == "Subheader"
           and norm(node.Text) == "equipped" then
            local title = node.Parent and node.Parent:FindFirstChild("Title")
            local name = getText(title)
            if name and norm(name) ~= "locked" then return name end
        end
    end
    local name = getText(child(abilities, "TopPanel", "DisplayName"))
    if name then return name end
    for _, node in ipairs(abilities:GetDescendants()) do
        if node:IsA("TextLabel") and norm(node.Text):find("current ability", 1, true) then
            local label = node.Parent and node.Parent:FindFirstChild("DisplayName")
            name = getText(label)
            if name then return name end
        end
    end
    return nil
end
local function remoteFor(mode)
    local names = (mode == "Style")
        and { StyleService = true, StylesService = true }
        or  { AbilityService = true, AbilitiesService = true }
    -- Works with different Knit package versions under ReplicatedStorage.Packages._Index.
    local index = child(ReplicatedStorage, "Packages", "_Index")
    if not index then return nil end
    for _, node in ipairs(index:GetDescendants()) do
        if names[node.Name] then
            local remote = child(node, "RF", "Roll")
            if remote and remote:IsA("RemoteFunction") then
                return remote
            end
        end
    end
    return nil
end

local C = {
    bg = Color3.fromRGB(20, 23, 33), panel = Color3.fromRGB(30, 35, 48),
    input = Color3.fromRGB(39, 44, 60), white = Color3.fromRGB(239, 242, 250),
    muted = Color3.fromRGB(169, 178, 196), blue = Color3.fromRGB(73, 132, 252),
    green = Color3.fromRGB(61, 185, 124), red = Color3.fromRGB(220, 85, 94)
}
local function new(class, props, parent)
    local x = Instance.new(class)
    for k, v in pairs(props) do x[k] = v end
    if parent then x.Parent = parent end
    return x
end
local function round(obj, radius)
    new("UICorner", { CornerRadius = UDim.new(0, radius or 9) }, obj)
end
local function label(parent, text, y, height, size, color)
    return new("TextLabel", {
        Position = UDim2.new(0, 15, 0, y), Size = UDim2.new(1, -30, 0, height),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham,
        Text = text, TextColor3 = color or C.muted, TextSize = size or 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end
local function box(parent, hint, y, text)
    local x = new("TextBox", {
        Position = UDim2.new(0, 15, 0, y), Size = UDim2.new(1, -30, 0, 34),
        BackgroundColor3 = C.input, TextColor3 = C.white,
        PlaceholderColor3 = C.muted, PlaceholderText = hint,
        Text = text or "", ClearTextOnFocus = false,
        Font = Enum.Font.Gotham, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
    round(x)
    new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, x)
    return x
end
local function button(parent, text, x, y, w, h, color)
    local obj = new("TextButton", {
        Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, w, 0, h),
        BackgroundColor3 = color or C.input, AutoButtonColor = true,
        Text = text, TextColor3 = C.white, Font = Enum.Font.GothamBold, TextSize = 13,
    }, parent)
    round(obj)
    return obj
end

-- Compact single-panel UI: every control is visible without scrolling.
-- The UIScale adjusts the whole panel to small mobile viewports.
local PANEL_W, PANEL_H = 360, 405
local uiScale
local function fitToViewport()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(960, 600)
    if uiScale then
        uiScale.Scale = math.min(1, (viewport.X - 22) / PANEL_W, (viewport.Y - 22) / PANEL_H)
    end
end

gui = new("ScreenGui", {
    Name = "AutoSpinVipPro", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
}, playerGui)
local main = new("Frame", {
    Name = "Panel", Size = UDim2.fromOffset(PANEL_W, PANEL_H),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = C.bg, Active = true,
}, gui)
uiScale = new("UIScale", { Scale = 1 }, main)
fitToViewport()
round(main, 12)
new("UIStroke", { Color = Color3.fromRGB(62, 71, 95), Thickness = 1 }, main)
local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.panel,
    Active = true,
}, main)
round(header, 12)
local heading = label(header, "Auto Spin Vip Pro", 11, 20, 15, C.white)
heading.Font = Enum.Font.GothamBold
local minimize = button(header, "–", 286, 7, 28, 28)
local close = button(header, "X", 320, 7, 28, 28, C.red)
local body = new("Frame", {
    Position = UDim2.fromOffset(0, 42),
    Size = UDim2.new(1, 0, 1, -42), BackgroundTransparency = 1,
}, main)
local function smallLabel(text, x, y, w)
    return new("TextLabel", {
        Position = UDim2.fromOffset(x,y), Size = UDim2.fromOffset(w,15),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        TextSize = 10, TextColor3 = C.muted, Text = text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, body)
end
smallLabel("LOẠI QUAY", 15, 6, 159)
smallLabel("LOẠI SPIN", 187, 6, 158)
local styleBtn = button(body, "STYLE", 15, 24, 76, 29, C.blue)
local abilityBtn = button(body, "ABILITY", 95, 24, 79, 29)
local normalBtn = button(body, "NORMAL", 187, 24, 76, 29, C.blue)
local luckyBtn = button(body, "LUCKY", 267, 24, 78, 29)
for _, b in ipairs({styleBtn, abilityBtn, normalBtn, luckyBtn}) do b.TextSize = 12 end

smallLabel("STYLE / ABILITY MUỐN SĂN", 15, 59, 330)
local targetBox = box(body, "Ví dụ: Timeskip Hinoto, Ronin, Sanju", 77, "")
targetBox.Size = UDim2.fromOffset(330, 31)

smallLabel("DELAY (GIÂY)", 15, 113, 158)
smallLabel("GIỚI HẠN LƯỢT", 187, 113, 158)
local delayBox = box(body, "Giây", 130, "0.5")
delayBox.Size = UDim2.fromOffset(158, 30)
local countBox = box(body, "Số lượt", 130, "100")
countBox.Position = UDim2.fromOffset(187, 130)
countBox.Size = UDim2.fromOffset(158, 30)

local autoStartBtn = button(body, "AUTO START: TẮT", 15, 168, 159, 32)
local hubBtn = button(body, "AUTO FURHUB: TẮT", 187, 168, 158, 32)
autoStartBtn.TextSize, hubBtn.TextSize = 12, 12
local startBtn = button(body, "▶ BẮT ĐẦU AUTO SPIN", 15, 207, 330, 35, C.green)
local manualHubBtn = button(body, "↗ MỞ FURHUB NGAY", 15, 249, 236, 34, Color3.fromRGB(88, 68, 153))
local saveBtn = button(body, "LƯU", 259, 249, 86, 34, C.blue)

local status = label(body, "Sẵn sàng", 289, 28, 11, C.muted)
status.TextWrapped = true
local progress = label(body, "Đã quay: 0 / 100", 320, 18, 11, C.muted)
progress.TextTruncate = Enum.TextTruncate.AtEnd
local settingsHint = label(body, "Cài đặt: đang tải...", 341, 16, 10, C.muted)
settingsHint.TextTruncate = Enum.TextTruncate.AtEnd

local FURHUB_URL = "https://raw.githubusercontent.com/mrmangola/FurHub/main/FurHub"

local mode, spinKind, openFurHub, autoStart = "Style", "Normal", false, false
local luckyArmedUntil = 0

-- Save only harmless UI preferences; never persist the running state.
local configFile = "VBL_AutoSpin_settings.json"
local targets = { Style = "", Ability = "" }
local function sanitizedConfig(raw)
    if type(raw) ~= "table" then return nil end
    local incoming = type(raw.targets) == "table" and raw.targets or {}
    return {
        version = 1,
        mode = raw.mode == "Ability" and "Ability" or "Style",
        spinKind = raw.spinKind == "Lucky" and "Lucky" or "Normal",
        openFurHub = raw.openFurHub == true,
        autoStart = raw.autoStart == true,
        targets = {
            Style = type(incoming.Style) == "string" and incoming.Style:sub(1, 2000) or "",
            Ability = type(incoming.Ability) == "string" and incoming.Ability:sub(1, 2000) or "",
        },
        delay = type(raw.delay) == "string" and raw.delay:sub(1, 30) or "2.0",
        limit = type(raw.limit) == "string" and raw.limit:sub(1, 30) or "100",
    }
end

local function loadSettings()
    if type(readfile) == "function" then
        local ok, contents = pcall(readfile, configFile)
        if ok and type(contents) == "string" then
            local valid, decoded = pcall(function()
                return HttpService:JSONDecode(contents)
            end)
            if valid then
                local cfg = sanitizedConfig(decoded)
                if cfg then return cfg, "file" end
            end
        end
    end
    local cached = sanitizedConfig(env.VBLSpinSettingsCache)
    if cached then return cached, "session" end
    return nil, "default"
end

local function saveSettings()
    targets[mode] = targetBox.Text
    local cfg = {
        version = 1, mode = mode, spinKind = spinKind,
        openFurHub = openFurHub,
        autoStart = autoStart,
        targets = { Style = targets.Style, Ability = targets.Ability },
        delay = delayBox.Text, limit = countBox.Text,
    }
    -- In-memory fallback lasts until the executor session ends.
    env.VBLSpinSettingsCache = cfg
    if type(writefile) == "function" and type(readfile) == "function" then
        local ok, err = pcall(function()
            writefile(configFile, HttpService:JSONEncode(cfg))
        end)
        if ok then
            settingsHint.Text = "Đã lưu tự động (JSON)"
            settingsHint.TextColor3 = C.green
            return true
        end
        settingsHint.Text = "Lỗi lưu file: " .. tostring(err):sub(1, 22)
        settingsHint.TextColor3 = C.red
        return false
    end
    settingsHint.Text = "Chỉ nhớ trong phiên này"
    settingsHint.TextColor3 = C.red
    return false
end

local restored, restoreSource = loadSettings()
if restored then
    mode = restored.mode
    spinKind = restored.spinKind
    openFurHub = restored.openFurHub
    autoStart = restored.autoStart
    targets = restored.targets
    targetBox.Text = targets[mode]
    delayBox.Text = restored.delay
    countBox.Text = restored.limit
end
settingsHint.Text = restoreSource == "file" and "Đã tải thiết lập đã lưu"
    or restoreSource == "session" and "Đã tải thiết lập trong phiên"
    or "Chưa có thiết lập đã lưu"
settingsHint.TextColor3 = restoreSource == "file" and C.green or C.muted
saveOnClose = saveSettings

local function refreshButtons()
    styleBtn.BackgroundColor3 = mode == "Style" and C.blue or C.input
    abilityBtn.BackgroundColor3 = mode == "Ability" and C.blue or C.input
    normalBtn.BackgroundColor3 = spinKind == "Normal" and C.blue or C.input
    luckyBtn.BackgroundColor3 = spinKind == "Lucky" and C.blue or C.input
    hubBtn.BackgroundColor3 = openFurHub and C.blue or C.input
    hubBtn.Text = openFurHub and "AUTO FURHUB: BẬT" or "AUTO FURHUB: TẮT"
    autoStartBtn.BackgroundColor3 = autoStart and C.blue or C.input
    autoStartBtn.Text = autoStart and "AUTO START: BẬT" or "AUTO START: TẮT"
end
refreshButtons()

local function chooseMode(nextMode)
    if running or starting then return end
    targets[mode] = targetBox.Text
    mode = nextMode
    targetBox.Text = targets[mode]
    luckyArmedUntil = 0
    refreshButtons()
    saveSettings()
end

local function setStatus(message, color)
    if alive then status.Text = message; status.TextColor3 = color or C.muted end
end
local function refreshStart()
    local busy = running or starting
    startBtn.Text = busy and "■ DỪNG AUTO SPIN" or "▶ BẮT ĐẦU AUTO SPIN"
    startBtn.BackgroundColor3 = busy and C.red or C.green
end
styleBtn.MouseButton1Click:Connect(function()
    chooseMode("Style")
end)
abilityBtn.MouseButton1Click:Connect(function()
    chooseMode("Ability")
end)
normalBtn.MouseButton1Click:Connect(function()
    if not running and not starting then
        spinKind = "Normal"; luckyArmedUntil = 0; refreshButtons()
        saveSettings()
        setStatus("Đã chọn Normal Spin")
    end
end)
luckyBtn.MouseButton1Click:Connect(function()
    if not running and not starting then
        spinKind = "Lucky"; luckyArmedUntil = 0
        if autoStart then
            autoStart = false -- switching from Normal to Lucky requires renewed auto-start consent
            setStatus("Đã chọn Lucky: AUTO START tự tắt; bật lại để xác nhận", C.red)
        else
            setStatus("Lucky Spin dùng vé hiếm, cần xác nhận trước khi quay", C.red)
        end
        refreshButtons()
        saveSettings()
    end
end)

-- Auto-save after editing a text field, and allow explicit save.
targetBox.FocusLost:Connect(function() saveSettings() end)
delayBox.FocusLost:Connect(function() saveSettings() end)
countBox.FocusLost:Connect(function() saveSettings() end)
hubBtn.MouseButton1Click:Connect(function()
    if running or starting then
        setStatus("Dừng quay trước khi đổi Auto FurHub", C.red)
        return
    end
    openFurHub = not openFurHub
    refreshButtons()
    saveSettings()
    setStatus(openFurHub and "FurHub sẽ chạy khi chạm giới hạn mà chưa trúng" or "Đã tắt tự mở FurHub", openFurHub and C.red or C.muted)
end)
saveBtn.MouseButton1Click:Connect(function()
    if saveSettings() then setStatus("Đã lưu thiết lập trên máy", C.green)
    else setStatus("Executor chưa hỗ trợ lưu qua phiên", C.red) end
end)

-- The switch affects FUTURE script executions; turning it off also cancels
-- any pending/current spin session. Lucky requires a second opt-in tap.
local autoLuckyConfirmUntil = 0
autoStartBtn.MouseButton1Click:Connect(function()
    if autoStart then
        autoStart = false
        autoLuckyConfirmUntil = 0
        if running or starting then
            stop()
            refreshStart()
        end
        refreshButtons()
        saveSettings()
        setStatus("AUTO START đã TẮT, đã dừng quay nếu đang chạy", C.muted)
        return
    end
    if spinKind == "Lucky" and os.clock() > autoLuckyConfirmUntil then
        autoLuckyConfirmUntil = os.clock() + 8
        setStatus("AUTO START sẽ tiêu Lucky Spin! Nhấn lại trong 8 giây", C.red)
        return
    end
    autoLuckyConfirmUntil = 0
    autoStart = true
    refreshButtons()
    local savedToDisk = saveSettings()
    setStatus(savedToDisk and "AUTO START bật; có hiệu lực từ lần execute sau"
        or "AUTO START bật; cần readfile/writefile để nhớ sau rejoin",
        savedToDisk and C.green or C.red)
end)

local furHubLoading = false
local function launchFurHub(expectedToken)
    if not alive or furHubLoading then return end
    if expectedToken ~= nil and token ~= expectedToken then return end
    furHubLoading = true
    manualHubBtn.Text = "ĐANG MỞ FURHUB..."
    manualHubBtn.BackgroundColor3 = C.input
    task.spawn(function()
        if not alive or (expectedToken ~= nil and token ~= expectedToken) then
            furHubLoading = false
            return
        end
        local ok, err = pcall(function()
            if type(loadstring) ~= "function" then
                error("Executor không hỗ trợ loadstring")
            end
            local source = game:HttpGet(FURHUB_URL)
            local entry = loadstring(source)
            if type(entry) ~= "function" then error("Không tải được FurHub") end
            entry()
        end)
        furHubLoading = false
        if not alive then return end
        manualHubBtn.Text = "↗ MỞ FURHUB NGAY"
        manualHubBtn.BackgroundColor3 = Color3.fromRGB(88, 68, 153)
        if not ok then
            setStatus("Lỗi mở FurHub: " .. tostring(err):sub(1, 66), C.red)
        else
            setStatus("Đã chạy loader FurHub", C.green)
        end
    end)
end

manualHubBtn.MouseButton1Click:Connect(function()
    if furHubLoading then
        setStatus("FurHub đang được mở...", C.blue)
        return
    end
    -- Stop queued rolls before manually loading the external hub.
    if running or starting then
        stop()
        refreshStart()
    end
    setStatus("Đang mở FurHub thủ công...", C.blue)
    launchFurHub(nil)
end)

local function beginSpin(autoLaunch)
    if not alive or running or starting then return end
    saveSettings()
    local wanted, n = targetsFrom(targetBox.Text)
    local delay = tonumber(delayBox.Text)
    local limit = tonumber(countBox.Text)
    if n == 0 then setStatus("Nhập ít nhất một tên mục tiêu!", C.red); return end
    if not delay or delay < 0.5 or delay > 15 then
        setStatus("Giãn cách phải từ 0.5 đến 15 giây", C.red); return
    end
    if not limit or limit % 1 ~= 0 or limit < 1 or limit > 10000 then
        setStatus("Giới hạn phải từ 1 đến 10000 lượt", C.red); return
    end
    -- For manual Lucky starts retain the two-tap confirmation. Auto-start's
    -- explicitly saved switch is the one-time opt-in for subsequent executions.
    if spinKind == "Lucky" and not autoLaunch and os.clock() > luckyArmedUntil then
        luckyArmedUntil = os.clock() + 8
        setStatus("LUCKY tiêu vé hiếm! Nhấn BẮT ĐẦU lần nữa trong 8 giây", C.red)
        return
    end
    luckyArmedUntil = 0
    local useLucky = spinKind == "Lucky"
    local selectedMode = mode
    local readName = selectedMode == "Style" and equippedStyle or equippedAbility
    starting = true
    token = token + 1
    local myToken = token
    refreshStart()
    progress.Text = "Đã gửi: 0 lượt"
    if autoLaunch then setStatus("AUTO START: đang chờ giao diện game...", C.blue) end
    task.spawn(function()
        -- Rejoin/auto-execute may run before Roblox builds the Lobby UI.
        -- Wait only for actual readable result + valid Roll remote; never guess.
        local current, remote
        local deadline = os.clock() + (autoLaunch and 20 or 0)
        repeat
            if not (alive and starting and token == myToken) then return end
            current = readName()
            if current then remote = remoteFor(selectedMode) end
            if current and remote then break end
            if os.clock() >= deadline then
                starting = false
                refreshStart()
                if not current then
                    setStatus("Mở trang " .. selectedMode .. " trong Lobby; không tự quay", C.red)
                else
                    setStatus("Không tìm thấy lệnh quay " .. selectedMode .. "; không tự quay", C.red)
                end
                return
            end
            task.wait(0.4)
        until false
        if not (alive and starting and token == myToken) then return end
        starting = false
        running = true
        refreshStart()
        local rolls = 0
        local finishReason = nil
        while alive and running and token == myToken do
            current = readName()
            if not current then
                finishReason = "read_error"
                setStatus("Không đọc được kết quả, đã dừng để tránh hao spin", C.red)
                break
            end
            progress.Text = ("Hiện tại: %s  |  Đã gửi: %d/%d"):format(current, rolls, limit)
            -- Hitting the target ALWAYS has priority over the limit / FurHub.
            if wanted[norm(current)] then
                finishReason = "target"
                setStatus("TRÚNG MỤC TIÊU: " .. current, C.green)
                break
            end
            if rolls >= limit then
                finishReason = "limit"
                break
            end
            setStatus("Đang quay " .. spinKind .. " " .. mode .. "...", C.blue)
            -- Historical examples use false for Normal; true for Lucky is unverified.
            local ok, result = pcall(function() return remote:InvokeServer(useLucky) end)
            if not (alive and running and token == myToken) then
                finishReason = "cancelled"
                break
            end
            if not ok then
                finishReason = "remote_error"
                setStatus("Lỗi gọi lệnh quay: " .. tostring(result):sub(1, 68), C.red)
                break
            end
            if result == false then
                -- Could be no spins, cooldown, server rejection, etc. Never guess.
                finishReason = "rejected"
                setStatus("Server từ chối spin; chưa xác minh nguyên nhân", C.red)
                break
            end
            rolls = rolls + 1
            task.wait(delay)
        end

        if not (alive and running and token == myToken) then return end
        -- Let the final roll's UI result settle before any optional handoff.
        if finishReason == "limit" then
            local finalName = readName()
            for _ = 1, 10 do
                if not (alive and running and token == myToken) then return end
                if finalName and wanted[norm(finalName)] then
                    finishReason = "target"
                    setStatus("TRÚNG MỤC TIÊU: " .. finalName, C.green)
                    break
                end
                task.wait(0.15)
                finalName = readName()
            end
            if finishReason == "limit" and not finalName then
                finishReason = "read_error"
                setStatus("Không đọc được kết quả lượt cuối; KHÔNG mở FurHub", C.red)
            end
        end

        if alive and running and token == myToken then
            running = false
            refreshStart()
            if finishReason == "limit" then
                if not openFurHub then
                    setStatus("Đã chạm giới hạn " .. limit .. " lượt; FurHub đang tắt", C.muted)
                else
                    setStatus("Không trúng sau " .. limit .. " lượt. Đang mở FurHub...", C.blue)
                    -- Enabled only via the Auto FurHub switch.
                    launchFurHub(myToken)
                end
            end
        end
    end)
end

-- Manual start/stop is always available, regardless of the auto-start switch.
startBtn.MouseButton1Click:Connect(function()
    if running or starting then
        stop()
        refreshStart()
        setStatus("Đã dừng thủ công")
    else
        beginSpin(false)
    end
end)

-- This script never schedules or executes itself after teleport.
-- If executor launches it again, saved autoStart can trigger beginSpin.
if autoStart then
    task.defer(function()
        if alive and autoStart and not running and not starting then beginSpin(true) end
    end)
end

close.MouseButton1Click:Connect(function()
    controller.Close()
    if env.VBLSpinControl == controller then env.VBLSpinControl = nil end
end)
local minimized = false
minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    main.Size = UDim2.fromOffset(PANEL_W, minimized and 42 or PANEL_H)
    minimize.Text = minimized and "+" or "–"
    fitToViewport()
end)

-- Drag with mouse or touch.
local dragging, dragInput, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not (alive and dragging) then return end
    if input == dragInput or (dragInput and dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input == dragInput then dragging = false; dragInput = nil end
end)

-- Keep the entire panel visible even in phone landscape orientation.
-- New cameras can be created after script injection, so refresh the connection.
local cameraConnection
local function bindCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then
        cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if alive then fitToViewport() end
        end)
    end
    fitToViewport()
end
bindCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if alive then bindCamera() end
end)
