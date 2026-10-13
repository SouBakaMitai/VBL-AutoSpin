-- VBL Auto Spin v1.0 | Roblox Luau
-- Standalone: no loadstring, no external HTTP requests.
-- Normal spin only by default. Real spins are consumed; no free-spin exploit.
-- UI/remote names are based on public VBL scripts and may change with game updates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild("PlayerGui")

local env = (type(getgenv) == "function" and getgenv()) or _G
if env.VBLSpinControl and type(env.VBLSpinControl.Close) == "function" then
    pcall(env.VBLSpinControl.Close)
end
local alive, running, token = true, false, 0
local gui
local function stop()
    running = false
    token = token + 1
end
local controller = { Close = function()
    alive = false
    stop()
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

gui = new("ScreenGui", {
    Name = "VBL_AutoSpin_Standalone", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
}, playerGui)
local main = new("Frame", {
    Name = "Panel", Size = UDim2.fromOffset(360, 346),
    Position = UDim2.new(0.5, -180, 0.5, -173),
    BackgroundColor3 = C.bg, Active = true,
}, gui)
round(main, 12)
new("UIStroke", { Color = Color3.fromRGB(62, 71, 95), Thickness = 1 }, main)
local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 43), BackgroundColor3 = C.panel,
    Active = true,
}, main)
round(header, 12)
label(header, "VBL AUTO SPIN  |  v1.0", 12, 20, 15, C.white)
local minimize = button(header, "–", 286, 7, 28, 28)
local close = button(header, "X", 320, 7, 28, 28, C.red)
local body = new("Frame", {
    Position = UDim2.fromOffset(0, 43), Size = UDim2.new(1, 0, 1, -43),
    BackgroundTransparency = 1,
}, main)
label(body, "Chọn loại spin", 8, 18)
local styleBtn = button(body, "STYLE", 15, 30, 158, 34, C.blue)
local abilityBtn = button(body, "ABILITY", 187, 30, 158, 34)
label(body, "Tên muốn săn (phân cách bằng dấu phẩy)", 71, 18)
local targetBox = box(body, "Ví dụ: Timeskip Hinoto, Ronin", 92, "")
label(body, "Giãn cách (giây)          Giới hạn lượt", 132, 18)
local delayBox = box(body, "Giây", 152, "2.0")
delayBox.Size = UDim2.fromOffset(158, 34)
local countBox = box(body, "Số lượt", 152, "100")
countBox.Position = UDim2.fromOffset(187, 152)
countBox.Size = UDim2.fromOffset(158, 34)
local startBtn = button(body, "BẮT ĐẦU AUTO SPIN", 15, 198, 330, 37, C.green)
local status = label(body, "Sẵn sàng | Chỉ dùng spin hiện có", 243, 22, 12, C.muted)
status.TextWrapped = true
local progress = label(body, "Đã gửi: 0 lượt", 270, 18, 12, C.muted)

local mode = "Style"
local function refreshButtons()
    styleBtn.BackgroundColor3 = mode == "Style" and C.blue or C.input
    abilityBtn.BackgroundColor3 = mode == "Ability" and C.blue or C.input
end
local function setStatus(message, color)
    if alive then status.Text = message; status.TextColor3 = color or C.muted end
end
local function refreshStart()
    startBtn.Text = running and "DỪNG AUTO SPIN" or "BẮT ĐẦU AUTO SPIN"
    startBtn.BackgroundColor3 = running and C.red or C.green
end
styleBtn.MouseButton1Click:Connect(function()
    if not running then mode = "Style"; refreshButtons() end
end)
abilityBtn.MouseButton1Click:Connect(function()
    if not running then mode = "Ability"; refreshButtons() end
end)

startBtn.MouseButton1Click:Connect(function()
    if running then
        stop()
        refreshStart()
        setStatus("Đã dừng thủ công")
        return
    end
    local wanted, n = targetsFrom(targetBox.Text)
    local delay = tonumber(delayBox.Text)
    local limit = tonumber(countBox.Text)
    if n == 0 then setStatus("Nhập ít nhất một tên mục tiêu!", C.red); return end
    if not delay or delay < 1.5 or delay > 15 then
        setStatus("Giãn cách phải từ 1.5 đến 15 giây", C.red); return
    end
    if not limit or limit % 1 ~= 0 or limit < 1 or limit > 10000 then
        setStatus("Giới hạn phải từ 1 đến 10000 lượt", C.red); return
    end
    local readName = mode == "Style" and equippedStyle or equippedAbility
    local current = readName()
    if not current then
        setStatus("Mở trang " .. mode .. " trong Lobby rồi thử lại", C.red)
        return
    end
    local remote = remoteFor(mode)
    if not remote then
        setStatus("Không tìm thấy lệnh quay " .. mode .. " (game có thể đã cập nhật)", C.red)
        return
    end
    running = true
    token = token + 1
    local myToken = token
    refreshStart()
    progress.Text = "Đã gửi: 0 lượt"
    task.spawn(function()
        local rolls = 0
        while alive and running and token == myToken do
            current = readName()
            if not current then
                setStatus("Không đọc được kết quả, đã dừng để tránh hao spin", C.red)
                break
            end
            progress.Text = ("Hiện tại: %s  |  Đã gửi: %d/%d"):format(current, rolls, limit)
            if wanted[norm(current)] then
                setStatus("TRÚNG MỤC TIÊU: " .. current, C.green)
                break
            end
            if rolls >= limit then
                setStatus("Đã chạm giới hạn " .. limit .. " lượt", C.muted)
                break
            end
            setStatus("Đang quay " .. mode .. "...", C.blue)
            -- false = normal spin in publicly available older VBL Roll examples.
            -- This is a real remote call, so the game's server still decides cost/result.
            local ok, result = pcall(function() return remote:InvokeServer(false) end)
            if not ok then
                setStatus("Lỗi gọi lệnh quay: " .. tostring(result):sub(1, 68), C.red)
                break
            end
            if not (alive and running and token == myToken) then break end
            if result == false then
                setStatus("Server từ chối spin (có thể đã hết lượt)", C.red)
                break
            end
            rolls = rolls + 1
            task.wait(delay)
        end
        if alive and token == myToken then
            running = false
            refreshStart()
        end
    end)
end)
close.MouseButton1Click:Connect(function()
    controller.Close()
    if env.VBLSpinControl == controller then env.VBLSpinControl = nil end
end)
local minimized = false
minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    main.Size = UDim2.fromOffset(360, minimized and 43 or 346)
    minimize.Text = minimized and "+" or "–"
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
