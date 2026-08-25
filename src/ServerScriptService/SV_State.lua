--!nonstrict
--[[
	SV_State
	配置場所: ServerScriptService/SV_State

	プレイヤーごとの権威状態を保持する。サーバーのみが書き換える。

	体力について:
	体力は Humanoid.Health をそのまま「単一リソース」として使う。
	装備コスト・使用コスト・維持コスト・被弾ダメージは全てここから引かれる。
	（仕様書 2. 体力（単一リソース））
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

local State = {}

local store: { [Player]: any } = {}

-- 段階1では武器1種のみ。ライン切替は段階4.5で汎用処理として実装する
function State.Create(player: Player, weaponName: string)
	local weapon = Config.Weapons[weaponName]
	assert(weapon, ("SV_State: 未定義の武器 '%s'"):format(weaponName))

	local magSize = weapon.MagSize or 0
	local mags = weapon.Mags or 1

	local st = {
		Alive          = true,

		WeaponName     = weaponName,
		Ammo           = magSize,
		Reserve        = math.max(0, (mags - 1) * magSize),
		LastFireAt     = 0,
		ReloadingUntil = 0,

		-- 継続ダメージ（段階1.7）
		BleedUntil     = 0,
		BleedNextTickAt= 0,

		-- 撃破点の帰属に使う（段階3で得点集計から参照する）
		DamageLog      = {} :: { [number]: number }, -- UserId -> 累計ダメージ
		LastAttackerId = nil :: number?,
		DiedByBleed    = false,
	}

	store[player] = st
	return st
end

function State.Get(player: Player)
	return store[player]
end

function State.Remove(player: Player)
	store[player] = nil
end

function State.All()
	return store
end

-- 与ダメージの記録。継続ダメージ死亡時の最多ダメージ判定に使う
function State.LogDamage(st, attackerId: number?, amount: number)
	if not attackerId then
		return
	end
	st.DamageLog[attackerId] = (st.DamageLog[attackerId] or 0) + amount
end

-- 最も多くダメージを与えた者の UserId を返す
function State.MostDamageId(st): number?
	local bestId, bestAmount = nil, 0
	for id, amount in pairs(st.DamageLog) do
		if amount > bestAmount then
			bestId, bestAmount = id, amount
		end
	end
	return bestId
end

return State
