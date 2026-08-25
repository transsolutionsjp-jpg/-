--!nonstrict
--[[
	SV_Main
	配置場所: ServerScriptService/SV_Main

	段階1 / 1.5 / 1.7 の起動処理。

	実装済み:
		段階1   移動・射撃・ヒット判定（武器1種のみ = Assault）
		段階1.5 体力消費型の射撃
		段階1.7 継続ダメージ

	未実装（実装順序を飛ばさないこと）:
		段階2  Bot
		段階3  チーム分け・得点集計・終了判定
		段階4  レーダーUI
		段階4.5 ライン切替（汎用処理として実装する）
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config    = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Net       = require(script.Parent.SV_Net)
local State     = require(script.Parent.SV_State)
local Character = require(script.Parent.SV_Character)
local Combat    = require(script.Parent.SV_Combat)
local Bleed     = require(script.Parent.SV_Bleed)
local Arena     = require(script.Parent.SV_TestArena)

-- 段階1で使用する唯一の武器
local STAGE1_WEAPON = "Assault"

--==================================================
-- 起動
--==================================================
-- リスポーンは実装しない。生成はサーバーが1回だけ行う。
-- 誰かが参加する前に必ず切っておくこと
Players.CharacterAutoLoads = false

Arena.Build()
Bleed.Start()

--==================================================
-- 入力の受信（意思のみ）
--==================================================
Net.Get("RE_Fire_Weapon").OnServerEvent:Connect(function(player, aimPoint)
	Combat.TryFire(player, aimPoint)
end)

Net.Get("RE_Reload_Weapon").OnServerEvent:Connect(function(player)
	Combat.TryReload(player)
end)

--==================================================
-- プレイヤー
--==================================================
local function onCharacterAdded(player: Player, character: Model)
	local humanoid = Character.Setup(player, character)

	humanoid.Died:Connect(function()
		Combat.OnDeath(player)
	end)

	Combat.Sync(player)
end

local function onPlayerAdded(player: Player)
	State.Create(player, STAGE1_WEAPON)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	Character.Spawn(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	State.Remove(player)
end)

--==================================================
-- 撃破の記録（得点集計は段階3で実装する）
--==================================================
Combat.Killed:Connect(function(victim, killer, byBleed)
	if killer then
		print(("[KILL] %s -> %s%s"):format(
			killer.Name, victim.Name, byBleed and " (継続ダメージ)" or ""))
	else
		print(("[DEATH] %s (帰属なし)"):format(victim.Name))
	end
end)
