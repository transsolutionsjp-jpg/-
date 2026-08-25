--!nonstrict
--[[
	SV_Combat
	配置場所: ServerScriptService/SV_Combat

	射撃・ヒット判定・ダメージ確定を担当する。

	【厳守（仕様書 11. 技術前提）】
	サーバー権威。ダメージ・死亡・得点・勝敗は全てここで確定する。
	クライアントから受け取ってよいのは照準点のみで、
	命中判定・ダメージ値・体力値をクライアントから受け取ってはならない。

	【厳守（仕様書 12. 禁止事項）】
	射撃による自滅を発生させない。
	残り体力が使用コストを下回る場合、その武器は発射不可とする。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Net = require(script.Parent.SV_Net)
local State = require(script.Parent.SV_State)
local Character = require(script.Parent.SV_Character)

local Combat = {}

local RE_Notify_Hit   = Net.Get("RE_Notify_Hit")
local RE_Notify_Shot  = Net.Get("RE_Notify_Shot")
local RE_Notify_Death = Net.Get("RE_Notify_Death")
local RE_Sync_State   = Net.Get("RE_Sync_State")

-- 段階3（得点集計）から接続するためのフック。ここでは得点計算を行わない
local killedBindable = Instance.new("BindableEvent")
Combat.Killed = killedBindable.Event

--==================================================
-- 状態同期（サーバー → クライアント）
--==================================================
function Combat.Sync(player: Player)
	local st = State.Get(player)
	if not st then return end

	local humanoid = Combat.GetHumanoid(player)
	local now = os.clock()

	RE_Sync_State:FireClient(player, {
		Health    = humanoid and humanoid.Health or 0,
		MaxHealth = humanoid and humanoid.MaxHealth or 0,
		Ammo      = st.Ammo,
		Reserve   = st.Reserve,
		Reloading = now < st.ReloadingUntil,
		ReloadEndsAt = st.ReloadingUntil,
		Bleeding  = now < st.BleedUntil,
		Weapon    = st.WeaponName,
		Alive     = st.Alive,
	})
end

function Combat.GetHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return humanoid
end

--==================================================
-- 拡散の適用
--==================================================
-- 空中時の実効拡散 = SpreadDeg / (1 - Airborne.AccuracyPenalty)
-- 仕様書 7.「命中精度 -30%」をサーバー側で確定させる
local function applySpread(direction: Vector3, spreadDeg: number): Vector3
	if spreadDeg <= 0 then
		return direction
	end
	local maxAngle = math.rad(spreadDeg)
	-- 円内一様分布にするため sqrt を掛ける
	local angle = maxAngle * math.sqrt(math.random())
	local roll  = math.random() * math.pi * 2
	local base  = CFrame.lookAt(Vector3.zero, direction)
	return (base * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

--==================================================
-- ダメージ確定
--==================================================
function Combat.ApplyDamage(victim: Player, attacker: Player?, amount: number, isBleed: boolean)
	local st = State.Get(victim)
	if not st or not st.Alive then return end

	local humanoid = Combat.GetHumanoid(victim)
	if not humanoid then return end

	local attackerId = attacker and attacker.UserId or nil
	State.LogDamage(st, attackerId, amount)

	if not isBleed then
		st.LastAttackerId = attackerId
	end
	st.DiedByBleed = isBleed

	humanoid.Health = math.max(0, humanoid.Health - amount)

	-- 継続ダメージ（段階1.7）
	-- 被弾のたびに更新。体力15以下では新規付与しない
	if Config.Bleed.Enabled and not isBleed then
		if humanoid.Health > Config.Bleed.MinHPFloor then
			local now = os.clock()
			st.BleedUntil = now + Config.Bleed.DurationSec
			st.BleedNextTickAt = now + 1
		end
	end

	Combat.Sync(victim)
end

--==================================================
-- 死亡処理
--==================================================
function Combat.OnDeath(victim: Player)
	local st = State.Get(victim)
	if not st or not st.Alive then return end

	st.Alive = false
	st.BleedUntil = 0

	-- 撃破点の帰属（仕様書 1.）
	--   通常: 止めを刺した者（LastHit）
	--   継続ダメージによる死亡: 最も多くダメージを与えた者
	local creditId: number?
	if st.DiedByBleed and Config.Scoring.BleedDeathCredit == "MostDamage" then
		creditId = State.MostDamageId(st)
	else
		creditId = st.LastAttackerId
	end

	-- 自滅・場外は誰にも入らない
	if creditId == victim.UserId then
		creditId = nil
	end

	local killer = creditId and Players:GetPlayerByUserId(creditId) or nil

	-- 得点集計は段階3。ここでは事実の確定のみを行う
	killedBindable:Fire(victim, killer, st.DiedByBleed)

	RE_Notify_Death:FireAllClients({
		VictimId = victim.UserId,
		KillerId = creditId,
		ByBleed  = st.DiedByBleed,
	})

	Combat.Sync(victim)
end

--==================================================
-- 射撃
--==================================================
function Combat.TryFire(player: Player, aimPoint: Vector3)
	local st = State.Get(player)
	if not st or not st.Alive then return end

	local humanoid = Combat.GetHumanoid(player)
	if not humanoid then return end

	local character = player.Character
	local head = character and character:FindFirstChild(Config.Combat.HeadPartName)
	if not head then return end

	local weapon = Config.Weapons[st.WeaponName]
	if not weapon then return end

	local now = os.clock()

	-- リロード中は撃てない
	if now < st.ReloadingUntil then return end

	-- 連射間隔（サーバー側で検証する。クライアントの申告は信用しない）
	local interval = 60 / weapon.RPM
	if now - st.LastFireAt < interval * Config.Combat.FireRateTolerance then return end

	-- 弾薬（補給なし・拾得なし）
	if st.Ammo <= 0 then return end

	-- 使用コスト。体力が足りなければ発射しない（自滅させない）
	local cost = weapon.UseCostHP or 0
	if Config.Health.BlockWhenInsufficientHP then
		if humanoid.Health - cost < Config.Health.MinHPToAct then
			return
		end
	end

	-- 照準点の妥当性検証
	if typeof(aimPoint) ~= "Vector3" then return end
	local origin = head.Position
	local delta = aimPoint - origin
	if delta.Magnitude < 0.01 then return end
	if delta.Magnitude > Config.M(Config.Combat.MaxAimDistanceM) then
		delta = delta.Unit * Config.M(Config.Combat.MaxAimDistanceM)
	end

	-- 消費を確定
	st.LastFireAt = now
	st.Ammo -= 1
	if cost > 0 then
		humanoid.Health = math.max(Config.Health.MinHPToAct, humanoid.Health - cost)
	end

	-- 拡散（空中なら精度低下）
	local spreadDeg = weapon.SpreadDeg or 0
	if Character.IsAirborne(humanoid) then
		spreadDeg = spreadDeg / (1 - Config.Airborne.AccuracyPenalty)
	end
	local direction = applySpread(delta.Unit, spreadDeg)

	-- レイキャスト（射程は実効射程で打ち切る）
	local range = Config.M(weapon.RangeEffectiveM)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, direction * range, params)
	local endPoint = result and result.Position or (origin + direction * range)

	-- 曳光弾の描画用。命中判定の結果ではなく見た目のためだけに送る
	RE_Notify_Shot:FireAllClients(origin, endPoint, player.UserId)

	if result then
		local hitPart = result.Instance
		local hitCharacter = hitPart:FindFirstAncestorOfClass("Model")
		local hitHumanoid = hitCharacter and hitCharacter:FindFirstChildOfClass("Humanoid")

		if hitHumanoid and hitHumanoid.Health > 0 then
			local victim = Players:GetPlayerFromCharacter(hitCharacter)
			local isHead = hitPart.Name == Config.Combat.HeadPartName
			local damage = weapon.DamageBody * (isHead and (weapon.HeadshotMul or 1) or 1)

			if victim then
				Combat.ApplyDamage(victim, player, damage, false)
			else
				-- Bot（段階2）用。Player に紐づかない Humanoid にも通す
				hitHumanoid.Health = math.max(0, hitHumanoid.Health - damage)
			end

			RE_Notify_Hit:FireClient(player, isHead)
		end
	end

	Combat.Sync(player)
end

--==================================================
-- リロード
--==================================================
function Combat.TryReload(player: Player)
	local st = State.Get(player)
	if not st or not st.Alive then return end

	local weapon = Config.Weapons[st.WeaponName]
	if not weapon or not weapon.MagSize then return end

	local now = os.clock()
	if now < st.ReloadingUntil then return end
	if st.Ammo >= weapon.MagSize then return end
	if st.Reserve <= 0 then return end

	local token = now + weapon.ReloadSec
	st.ReloadingUntil = token
	Combat.Sync(player)

	task.delay(weapon.ReloadSec, function()
		-- 切替を挟んだ場合はリロードをやり直す（段階4.5で切替実装時に判定を追加する）
		local cur = State.Get(player)
		if not cur or not cur.Alive then return end
		-- 別のリロードで上書きされていたら、この完了処理は破棄する
		if cur.ReloadingUntil ~= token then return end

		local need = weapon.MagSize - cur.Ammo
		local take = math.min(need, cur.Reserve)
		cur.Ammo += take
		cur.Reserve -= take
		cur.ReloadingUntil = 0
		Combat.Sync(player)
	end)
end

return Combat
