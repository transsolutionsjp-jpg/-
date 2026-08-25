--!nonstrict
--[[
	SV_Character
	配置場所: ServerScriptService/SV_Character

	キャラクターの生成と、移動・体力の初期設定を担当する。

	【段階1の注意（仕様書 13.）】
	基本ジャンプ高1.9mと空中ペナルティを最初から入れること。
	後付けすると全ての操作感が変わり、それまでの調整が無駄になる。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local State = require(script.Parent.SV_State)

local Character = {}

--==================================================
-- 最大体力（装備コスト）
--==================================================
-- 枠コストは「装備したスロット数」に応じて最大体力から減算される。
-- 段階1は武器1種のみ＝1スロット＝SlotCost[1]=0 なので減算なし。
function Character.MaxHealthForSlots(slotCount: number): number
	local total = 0
	for i = 1, math.min(slotCount, #Config.SlotCost) do
		total += Config.SlotCost[i]
	end
	return math.max(1, Config.Health.Max - total)
end

--==================================================
-- 空中判定（サーバー側で確定する）
--==================================================
-- 通常ジャンプ・空中ジャンプ・落下中を問わず接地していなければ空中。
-- 仕様書 7. 空中状態の共通ルール（削除禁止）
function Character.IsAirborne(humanoid: Humanoid): boolean
	local s = humanoid:GetState()
	return s == Enum.HumanoidStateType.Freefall
		or s == Enum.HumanoidStateType.Jumping
		or s == Enum.HumanoidStateType.FallingDown
end

--==================================================
-- 体力の自動回復を止める
--==================================================
-- Roblox が挿入する Health スクリプトを削除する。
-- 仕様書 2.「試合中の回復なし」
local function killRegen(character: Model)
	local existing = character:FindFirstChild("Health")
	if existing and existing:IsA("BaseScript") then
		existing:Destroy()
	end
	-- 後から挿入される場合に備えて短時間だけ監視する
	local conn
	conn = character.ChildAdded:Connect(function(child)
		if child.Name == "Health" and child:IsA("BaseScript") then
			child:Destroy()
		end
	end)
	task.delay(5, function()
		if conn then conn:Disconnect() end
	end)
end

--==================================================
-- 移動設定の適用
--==================================================
local function applyMovement(humanoid: Humanoid, weaponName: string)
	local weapon = Config.Weapons[weaponName]
	local moveMul = (weapon and weapon.MoveSpeedMul) or 1.0

	humanoid.WalkSpeed = Config.M(Config.Movement.WalkSpeedMps) * moveMul

	-- JumpPower ではなく JumpHeight を使う。仕様が高さ(m)で定義されているため
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Config.M(Config.Movement.BaseJumpHeightM)
end

--==================================================
-- 着地後の再ジャンプ待機
--==================================================
local function applyJumpCooldown(humanoid: Humanoid)
	local baseHeight = Config.M(Config.Movement.BaseJumpHeightM)

	humanoid.StateChanged:Connect(function(_, newState)
		if newState ~= Enum.HumanoidStateType.Landed then
			return
		end
		humanoid.JumpHeight = 0
		task.delay(Config.Movement.JumpCooldownSec, function()
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid.JumpHeight = baseHeight
			end
		end)
	end)
end

--==================================================
-- 初期化
--==================================================
function Character.Setup(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	killRegen(character)

	local st = State.Get(player)
	local weaponName = st and st.WeaponName or Config.Bot.Loadout[1]

	-- 段階1は装備1スロットのみ
	local maxHealth = Character.MaxHealthForSlots(1)
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth

	applyMovement(humanoid, weaponName)
	applyJumpCooldown(humanoid)

	return humanoid
end

--==================================================
-- 生成（リスポーンは実装しない）
--==================================================
function Character.Spawn(player: Player)
	local st = State.Get(player)
	if st and not st.Alive then
		-- 仕様書 12. 禁止事項: リスポーン・蘇生
		return
	end
	player:LoadCharacter()
end

return Character
