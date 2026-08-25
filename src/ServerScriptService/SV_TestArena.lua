--!nonstrict
--[[
	SV_TestArena
	配置場所: ServerScriptService/SV_TestArena

	段階1の検証専用アリーナ。本番マップではない。

	目的:
		1. 移動速度・ジャンプ高が体感と合っているかを確かめる
		2. 高さ基準（MapStandards）どおりに「越えられる/越えられない」が機能するか
		3. 長射線で射程の打ち切りが機能するか

	全ての寸法は GameConfig を参照する。ここに数値を直書きしないこと。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

local Arena = {}

local M = Config.M

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

--==================================================
-- 床
--==================================================
local function buildFloor(parent: Instance)
	local diameter = M(Config.TestArena.FloorDiameterM)
	local floor = newPart(
		"Floor",
		Vector3.new(diameter, M(1), diameter),
		CFrame.new(0, -M(0.5), 0),
		Color3.fromRGB(80, 84, 88),
		parent
	)
	floor.Shape = Enum.PartType.Cylinder
	-- Cylinder は X 軸方向が高さになるため回転させる
	floor.Size = Vector3.new(M(1), diameter, diameter)
	floor.CFrame = CFrame.new(0, -M(0.5), 0) * CFrame.Angles(0, 0, math.rad(90))
end

--==================================================
-- スポーン地点
--==================================================
-- 段階1では中立スポーン。チーム分けは段階3で行う
local function buildSpawns(parent: Instance)
	local radius = M(Config.Map.SpawnRadiusM)
	local count = Config.Map.SpawnCount

	for i = 1, count do
		local angle = (i - 1) * (math.pi * 2 / count)
		local pos = Vector3.new(math.cos(angle) * radius, M(0.5), math.sin(angle) * radius)

		local spawn = Instance.new("SpawnLocation")
		spawn.Name = ("Spawn_%d"):format(i)
		spawn.Size = Vector3.new(M(2), M(0.2), M(2))
		spawn.CFrame = CFrame.new(pos)
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0 -- ForceField を出さない（1試合1命のため無意味）
		spawn.Color = Color3.fromRGB(120, 140, 160)
		spawn.Parent = parent
	end
end

--==================================================
-- 遮蔽物
--==================================================
-- 高さ基準の検証用に3種類を並べる:
--   CoverCrouchM  1.1m しゃがんで隠れる
--   CoverStandM   1.8m 立って隠れる／ジャンプ(1.9m)で越えられる
--   WallSolidM    2.2m 越えられない
local function buildCovers(parent: Instance)
	local heights = {
		{ h = Config.MapStandards.CoverCrouchM, color = Color3.fromRGB(120, 160, 120) },
		{ h = Config.MapStandards.CoverStandM,  color = Color3.fromRGB(160, 150, 110) },
		{ h = Config.MapStandards.WallSolidM,   color = Color3.fromRGB(170, 110, 110) },
	}

	local count = Config.TestArena.CoverCount
	local radius = M(Config.Map.CenterZoneM)

	for i = 1, count do
		local angle = (i - 1) * (math.pi * 2 / count)
		local spec = heights[((i - 1) % #heights) + 1]
		local height = M(spec.h)

		newPart(
			("Cover_%d_%.1fm"):format(i, spec.h),
			Vector3.new(M(4.0), height, M(0.6)),
			CFrame.new(math.cos(angle) * radius, height / 2, math.sin(angle) * radius)
				* CFrame.Angles(0, -angle, 0),
			spec.color,
			parent
		)
	end
end

--==================================================
-- 長射線
--==================================================
-- 仕様書 4.「マップ側には長射線を2〜3本必ず用意する（選択肢の存在保証）」
-- 対面スポーン間 = 約70m = スナイパー実効射程。ここでは射線を塞がないだけ
local function buildSightlineMarkers(parent: Instance)
	if not Config.TestArena.LongSightlines then
		return
	end

	local radius = M(Config.Map.SpawnRadiusM)
	for i = 1, Config.Map.LongSightlines do
		local angle = (i - 1) * (math.pi / Config.Map.LongSightlines)
		local marker = newPart(
			("Sightline_%d"):format(i),
			Vector3.new(radius * 2, M(0.05), M(0.4)),
			CFrame.new(0, M(0.03), 0) * CFrame.Angles(0, angle, 0),
			Color3.fromRGB(200, 190, 120),
			parent
		)
		marker.CanCollide = false
		marker.Transparency = 0.5
	end
end

--==================================================
-- 境界（見えない壁）
--==================================================
-- 仕様書 9.「見えない壁で物理的に阻む（退場システムは実装しない）」
local function buildBoundary(parent: Instance)
	if Config.Boundary.Method ~= "InvisibleWall" then
		return
	end

	local radius = M(Config.TestArena.FloorDiameterM) / 2
	local height = M(Config.MapStandards.FloorHeightM * 3)
	local segments = 24
	local segWidth = (2 * math.pi * radius) / segments * 1.1

	for i = 1, segments do
		local angle = (i - 1) * (math.pi * 2 / segments)
		local wall = newPart(
			("Boundary_%d"):format(i),
			Vector3.new(segWidth, height, M(0.5)),
			CFrame.new(math.cos(angle) * radius, height / 2, math.sin(angle) * radius)
				* CFrame.Angles(0, -angle + math.pi / 2, 0),
			Color3.fromRGB(255, 255, 255),
			parent
		)
		wall.Transparency = 1
		wall.CanCollide = true
	end
end

function Arena.Build()
	if not Config.TestArena.Enabled then
		return
	end

	local existing = workspace:FindFirstChild("TestArena")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "TestArena"
	folder.Parent = workspace

	buildFloor(folder)
	buildSpawns(folder)
	buildCovers(folder)
	buildSightlineMarkers(folder)
	buildBoundary(folder)
end

return Arena
