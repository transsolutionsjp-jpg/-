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
-- 不可視キャップ
--==================================================
-- 越えられない壁の上に、見えない当たり判定を積む。
-- 高さが足りていても上に乗れる場所が無くなるため、助走で越えられなくなる。
--
-- CanQuery = false が必須。true にすると弾が見えない壁に当たり、
-- 遮蔽の高さが実質的に変わってしまう（射線を切る役割が壊れる）。
local function addNoMountCap(wall: BasePart)
	local capHeight = M(Config.MapStandards.SolidWallCapM)
	if capHeight <= 0 then
		return
	end

	local cap = Instance.new("Part")
	cap.Name = wall.Name .. "_Cap"
	cap.Size = Vector3.new(wall.Size.X, capHeight, wall.Size.Z)
	cap.CFrame = wall.CFrame * CFrame.new(0, (wall.Size.Y + capHeight) / 2, 0)
	cap.Anchored = true
	cap.Transparency = 1
	cap.CanCollide = true
	cap.CanQuery = false -- 弾は通す
	cap.CanTouch = false
	cap.Parent = wall.Parent
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
		{ h = Config.MapStandards.CoverCrouchM, color = Color3.fromRGB(120, 160, 120), solid = false },
		{ h = Config.MapStandards.CoverStandM,  color = Color3.fromRGB(160, 150, 110), solid = false },
		{ h = Config.MapStandards.WallSolidM,   color = Color3.fromRGB(170, 110, 110), solid = true  },
	}

	local count = Config.TestArena.CoverCount
	local radius = M(Config.Map.CenterZoneM)

	for i = 1, count do
		local angle = (i - 1) * (math.pi * 2 / count)
		local spec = heights[((i - 1) % #heights) + 1]
		local height = M(spec.h)

		local wall = newPart(
			("Cover_%d_%.1fm"):format(i, spec.h),
			Vector3.new(M(4.0), height, M(0.6)),
			CFrame.new(math.cos(angle) * radius, height / 2, math.sin(angle) * radius)
				* CFrame.Angles(0, -angle, 0),
			spec.color,
			parent
		)

		-- 越えられない壁にはキャップを付ける。付けないと助走で乗り上げられる
		if spec.solid then
			addNoMountCap(wall)
		end
	end
end

--==================================================
-- 高さ検証台
--==================================================
-- 「何mまでなら助走で越えられるか」を実測するための設備。
-- ここの壁にはキャップを付けない。素の挙動を測るのが目的のため。
local function buildHeightProbe(parent: Instance)
	local probe = Config.TestArena.HeightProbe
	if not probe.Enabled then
		return
	end

	local count = #probe.HeightsM
	local spacing = M(probe.SpacingM)
	local startX = -spacing * (count - 1) / 2
	local z = M(probe.OffsetM)

	for i, heightM in ipairs(probe.HeightsM) do
		local height = M(heightM)
		local vaultable = heightM <= Config.MapStandards.WallVaultableM

		local wall = newPart(
			("Probe_%.1fm"):format(heightM),
			Vector3.new(M(probe.WidthM), height, M(probe.ThicknessM)),
			CFrame.new(startX + spacing * (i - 1), height / 2, z),
			vaultable
				and Color3.fromRGB(160, 150, 110)
				or Color3.fromRGB(170, 110, 110),
			parent
		)

		-- 高さを頭上に表示する。どれを試しているか分からなくなるため
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "HeightLabel"
		billboard.Size = UDim2.new(0, 90, 0, 30)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, M(0.7), 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = wall

		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.Text = ("%.1fm"):format(heightM)
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextStrokeTransparency = 0.2
		text.Parent = billboard
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

--==================================================
-- Studio 初期状態の片付け
--==================================================
-- 新規プレイスに最初から入っている Baseplate と SpawnLocation を消す。
-- 残しておくと、こちらのスポーン地点と競合してプレイヤーが
-- 中央に湧いてしまう。手作業で消させないためにコード側で処理する。
local function clearDefaults(keep: Instance)
	for _, child in ipairs(workspace:GetChildren()) do
		if child == keep then
			continue
		end
		if child.Name == "Baseplate" and child:IsA("BasePart") then
			child:Destroy()
		elseif child:IsA("SpawnLocation") then
			child:Destroy()
		end
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

	clearDefaults(folder)

	buildFloor(folder)
	buildSpawns(folder)
	buildCovers(folder)
	buildHeightProbe(folder)
	buildSightlineMarkers(folder)
	buildBoundary(folder)
end

return Arena
