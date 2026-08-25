--!nonstrict
--[[
	CL_Combat
	配置場所: StarterPlayer/StarterPlayerScripts/CL_Combat

	【厳守（仕様書 11.）】
	クライアントは入力送信と描画のみ。
	命中判定・ダメージ計算をここで行ってはならない。
	ここで送るのは「撃ちたい」という意思と照準点だけで、
	実際に発射されたかどうかはサーバーが決める。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RE_Fire_Weapon   = Remotes:WaitForChild("RE_Fire_Weapon")
local RE_Reload_Weapon = Remotes:WaitForChild("RE_Reload_Weapon")
local RE_Notify_Shot   = Remotes:WaitForChild("RE_Notify_Shot")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

-- 段階1の武器。段階4.5でライン切替を実装したらサーバー同期の値に置き換える
local weaponName = "Assault"
local weapon = Config.Weapons[weaponName]

local firing = false
local lastSentAt = 0

--==================================================
-- 照準点の決定
--==================================================
-- マウスが何にも当たっていない場合は、カメラ前方の遠方点を使う
local function getAimPoint(): Vector3
	local target = mouse.Hit and mouse.Hit.Position
	if target then
		return target
	end
	return camera.CFrame.Position + camera.CFrame.LookVector * Config.M(Config.Combat.MaxAimDistanceM)
end

--==================================================
-- 送信
--==================================================
-- 送信間隔はサーバーの検証間隔と同じにする。
-- 早く送ってもサーバーが弾くだけなので、無駄な通信を減らす目的
local function sendInterval(): number
	return 60 / weapon.RPM
end

RunService.Heartbeat:Connect(function()
	if not firing then
		return
	end
	local now = os.clock()
	if now - lastSentAt < sendInterval() then
		return
	end
	lastSentAt = now
	RE_Fire_Weapon:FireServer(getAimPoint())
end)

--==================================================
-- 入力
--==================================================
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		firing = true
	elseif input.KeyCode == Enum.KeyCode.R then
		RE_Reload_Weapon:FireServer()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		firing = false
	end
end)

--==================================================
-- 曳光弾の描画（見た目のみ。判定には一切関与しない）
--==================================================
RE_Notify_Shot.OnClientEvent:Connect(function(origin: Vector3, endPoint: Vector3, shooterId: number)
	local distance = (endPoint - origin).Magnitude
	if distance < 0.1 then
		return
	end

	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = (shooterId == player.UserId)
		and Color3.fromRGB(230, 220, 160)
		or Color3.fromRGB(200, 120, 100)
	tracer.Size = Vector3.new(0.08, 0.08, distance)
	tracer.CFrame = CFrame.lookAt(origin, endPoint) * CFrame.new(0, 0, -distance / 2)
	tracer.Transparency = 0.3
	tracer.Parent = workspace

	Debris:AddItem(tracer, 0.06)
end)
