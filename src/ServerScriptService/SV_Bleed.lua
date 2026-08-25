--!nonstrict
--[[
	SV_Bleed
	配置場所: ServerScriptService/SV_Bleed

	継続ダメージ（段階1.7）

	仕様書 2.:
		被弾時、毎秒1ダメージを3秒間。被弾のたびに更新
		最大累計3ダメージ
		体力15以下では停止する（反撃不能のスパイラルを防ぐ）
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local State = require(script.Parent.SV_State)
local Combat = require(script.Parent.SV_Combat)

local Bleed = {}

function Bleed.Start()
	if not Config.Bleed.Enabled then
		return
	end

	RunService.Heartbeat:Connect(function()
		local now = os.clock()

		for player, st in pairs(State.All()) do
			if st.Alive and st.BleedUntil > now and now >= st.BleedNextTickAt then
				local humanoid = Combat.GetHumanoid(player)

				if not humanoid then
					st.BleedUntil = 0
				elseif humanoid.Health <= Config.Bleed.MinHPFloor then
					-- 反撃不能のスパイラルを防ぐため、ここで打ち切る
					st.BleedUntil = 0
					Combat.Sync(player)
				else
					st.BleedNextTickAt = now + 1

					-- 継続ダメージによる死亡は最多ダメージ者に帰属させるため
					-- 攻撃者を指定せず、DamageLog の集計に委ねる
					Combat.ApplyDamage(player, nil, Config.Bleed.DamagePerSec, true)
				end
			end
		end
	end)
end

return Bleed
