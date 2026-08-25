--!nonstrict
--[[
	CL_HUD
	配置場所: StarterPlayer/StarterPlayerScripts/CL_HUD

	段階1のHUD。表示のみで、値は全てサーバーから受け取る。

	体力バーが1本しかないことを見せるのがこのHUDの役割。
	装備コスト・使用コスト・被弾ダメージが同じバーを削ることを、
	プレイヤーが常に見える状態にしておく。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RE_Sync_State = Remotes:WaitForChild("RE_Sync_State")
local RE_Notify_Hit = Remotes:WaitForChild("RE_Notify_Hit")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--==================================================
-- 構築
--==================================================
local gui = Instance.new("ScreenGui")
gui.Name = "CL_HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local function newLabel(name: string, size: UDim2, pos: UDim2, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextStrokeTransparency = 0.6
	label.Parent = parent
	return label
end

-- 体力バー
local healthFrame = Instance.new("Frame")
healthFrame.Name = "HealthFrame"
healthFrame.Size = UDim2.new(0, 320, 0, 18)
healthFrame.Position = UDim2.new(0, 28, 1, -84)
healthFrame.BackgroundColor3 = Color3.fromRGB(28, 30, 34)
healthFrame.BorderSizePixel = 0
healthFrame.Parent = gui

local healthFill = Instance.new("Frame")
healthFill.Name = "Fill"
healthFill.Size = UDim2.new(1, 0, 1, 0)
healthFill.BackgroundColor3 = Color3.fromRGB(210, 215, 220)
healthFill.BorderSizePixel = 0
healthFill.Parent = healthFrame

-- 継続ダメージ中の表示
local bleedMark = newLabel("Bleed", UDim2.new(0, 120, 0, 18),
	UDim2.new(0, 332, 1, -84), gui)
bleedMark.TextColor3 = Color3.fromRGB(220, 110, 90)
bleedMark.Text = ""
bleedMark.TextSize = 13

local healthText = newLabel("HealthText", UDim2.new(0, 320, 0, 20),
	UDim2.new(0, 28, 1, -106), gui)
healthText.TextSize = 15

local ammoText = newLabel("AmmoText", UDim2.new(0, 320, 0, 24),
	UDim2.new(0, 28, 1, -58), gui)
ammoText.TextSize = 18

local stateText = newLabel("StateText", UDim2.new(0, 320, 0, 18),
	UDim2.new(0, 28, 1, -34), gui)
stateText.TextSize = 13
stateText.TextColor3 = Color3.fromRGB(180, 185, 190)

-- 照準点
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.Size = UDim2.new(0, 4, 0, 4)
crosshair.Position = UDim2.new(0.5, -2, 0.5, -2)
crosshair.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
crosshair.BorderSizePixel = 0
crosshair.Parent = gui

-- ヒットマーカー
local hitMarker = newLabel("HitMarker", UDim2.new(0, 40, 0, 40),
	UDim2.new(0.5, -20, 0.5, -20), gui)
hitMarker.Text = "×"
hitMarker.TextSize = 28
hitMarker.TextXAlignment = Enum.TextXAlignment.Center
hitMarker.TextTransparency = 1

--==================================================
-- 更新
--==================================================
local latest = {
	Health = 0, MaxHealth = Config.Health.Max,
	Ammo = 0, Reserve = 0,
	Reloading = false, Bleeding = false, Alive = true,
}

local function render()
	local ratio = latest.MaxHealth > 0 and (latest.Health / latest.MaxHealth) or 0
	healthFill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)

	-- 継続ダメージが止まる体力を割っているかで色を変える
	if latest.Health <= Config.Bleed.MinHPFloor then
		healthFill.BackgroundColor3 = Color3.fromRGB(210, 120, 100)
	else
		healthFill.BackgroundColor3 = Color3.fromRGB(210, 215, 220)
	end

	healthText.Text = ("体力 %d / %d"):format(
		math.ceil(latest.Health), math.ceil(latest.MaxHealth))

	bleedMark.Text = latest.Bleeding and "継続ダメージ" or ""

	if latest.Reloading then
		ammoText.Text = "リロード中"
	else
		ammoText.Text = ("%d / %d"):format(latest.Ammo, latest.Reserve)
	end

	if not latest.Alive then
		stateText.Text = "戦闘不能（リスポーンなし）"
		stateText.TextColor3 = Color3.fromRGB(220, 120, 100)
	end
end

RE_Sync_State.OnClientEvent:Connect(function(data)
	for key, value in pairs(data) do
		latest[key] = value
	end
	render()
end)

RE_Notify_Hit.OnClientEvent:Connect(function(isHead: boolean)
	hitMarker.TextColor3 = isHead
		and Color3.fromRGB(240, 180, 90)
		or Color3.fromRGB(240, 240, 240)
	hitMarker.TextTransparency = 0
	task.delay(0.12, function()
		hitMarker.TextTransparency = 1
	end)
end)

--==================================================
-- 空中表示
--==================================================
-- 仕様書 7.「空中では命中精度 -30%・回避不可」
-- 判定はサーバーが行う。ここは今その状態にあることを伝えるだけ
RunService.RenderStepped:Connect(function()
	if not latest.Alive then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local state = humanoid:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.FallingDown

	if airborne then
		stateText.Text = ("空中 — 命中精度 -%d%%"):format(Config.Airborne.AccuracyPenalty * 100)
		stateText.TextColor3 = Color3.fromRGB(230, 190, 110)
		crosshair.Size = UDim2.new(0, 10, 0, 10)
		crosshair.Position = UDim2.new(0.5, -5, 0.5, -5)
	else
		stateText.Text = ""
		crosshair.Size = UDim2.new(0, 4, 0, 4)
		crosshair.Position = UDim2.new(0.5, -2, 0.5, -2)
	end
end)

render()
