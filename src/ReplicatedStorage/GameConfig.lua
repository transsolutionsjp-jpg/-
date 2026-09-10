--!strict
--[[
	GameConfig.lua
	配置場所: ReplicatedStorage/GameConfig

	【厳守】
	調整可能な数値をスクリプト内に直書きしないこと。必ずこのファイルを参照する。
	理由: バランスは実プレイで反復調整するため、1回の調整コストを5分以内に抑える必要がある。

	【単位について】
	本ファイルの距離・高さは全てメートル(m)で記述する。仕様書と一致させるため。
	Roblox内部はスタッド(stud)なので、使用時は Config.M() で変換すること。
	STUDS_PER_METER は段階1で実機検証し、体感に合わせて調整してよい。
]]

local Config = {}

--==================================================
-- 0. 単位変換
--==================================================

Config.STUDS_PER_METER = 3.571 -- 1 stud = 0.28m

-- メートル → スタッド
function Config.M(meters: number): number
	return meters * Config.STUDS_PER_METER
end

--==================================================
-- 1. 試合形式
--==================================================

Config.Match = {
	Mode                = "Elimination",
	MaxDurationSec      = 300,   -- 上限5分。通常は決着により終了する
	EndWhenOneTeamLeft  = true,  -- 生存チームが1以下で即終了（必須）
	Respawn             = false, -- リスポーン・蘇生は実装しない
	ShowLiveRanking     = true,  -- 4チームの得点を常時表示

	TeamCount           = 4,
	TeamSize            = 3,

	-- 初版設定（人数が集まらない期間用）
	InitialTeamCount    = 3,
	InitialTeamSize     = 2,
}

Config.Scoring = {
	KillPoint              = 1,
	SoleSurvivorBonus      = 2,
	FinishBonus            = 1,     -- 完走ボーナス（途中離脱の抑止）
	SelfKillPoint          = 0,     -- 自滅・場外は誰にも入らない

	-- 時間切れで決着しない場合、生存ボーナスは与えない
	-- 理由: 待機して生き残ることに価値を持たせないため
	SurvivorBonusOnTimeout = false,

	-- 撃破点の帰属
	-- "LastHit"        : 止めを刺した者（横取りは実力不足として許容する）
	-- "MostDamageTeam" : 最多ダメージ者（現在は未採用）
	CreditMethod           = "LastHit",
	-- 継続ダメージによる死亡のみ、最多ダメージ者に帰属させる
	BleedDeathCredit       = "MostDamage",
}

Config.Ranking = {
	Mode      = "Cumulative",
	EntryCost = 2,  -- 1試合あたりの参加コスト
	MinScore  = 0,  -- 累計は0未満にしない
}

Config.Spectator = {
	Enabled       = true,
	CanSwitchView = true,  -- 味方視点への切替
	CanPing       = true,
	HideLeaveButton = true, -- 離脱ボタンを目立たせない
}

--==================================================
-- 2. 体力（単一リソース）
--==================================================

Config.Health = {
	Max                     = 100,
	RegenInMatch            = false, -- 試合中の回復なし
	BlockWhenInsufficientHP = true,  -- 体力不足時は発射不可（自滅させない）
	MinHPToAct              = 1,
}

Config.Bleed = {
	Enabled      = true,
	DamagePerSec = 1,    -- 下方修正済み（旧2）
	DurationSec  = 3,    -- 下方修正済み（旧4）
	RefreshOnHit = true,
	MinHPFloor   = 15,   -- これ以下では停止（反撃不能のスパイラルを防ぐ）
}

--==================================================
-- 3. 装備システム
--==================================================

Config.Loadout = {
	Lines              = 2,
	SlotsPerLine       = 4,
	TotalSlots         = 8,

	LineRestriction    = false, -- 種別による配置制限なし
	CategoryLimits     = nil,   -- カテゴリ所持数制限なし（シールドを除く）
	DirectSelect       = false, -- 直接選択は実装しない（順送りのみ）

	SwitchTimeSec      = 0.4,   -- 1回の切替。この間は攻撃不可
	ReloadCancelReset  = true,  -- 切替を挟むとリロードはやり直し
	ShareAmmoBySameWeapon = true, -- 同一武器は弾薬共有（総弾数は増えない）

	AllowPickup        = false, -- 試合中の武器拾得なし
	AmmoResupply       = false, -- 補給なし
}

-- 枠コスト（最大体力から減算）8スロット全埋めで 100 → 60
Config.SlotCost = { 0, 3, 4, 5, 6, 7, 7, 8 }

Config.Hands = {
	Total             = 2,
	DualWieldFireBoth = false, -- 片手2つでも同時発射は不可
	DualWieldSwapSec  = 0.15,  -- 片手同士の持ち替えは高速
}

--==================================================
-- 4. 移動・空中
--==================================================

Config.Movement = {
	WalkSpeedMps     = 7.0,  -- 中心到達まで約5秒
	BaseJumpHeightM  = 1.9,  -- バリケード(1.8m)を越えられる高さ
	JumpCooldownSec  = 0.4,  -- 着地後の再ジャンプ待機
}

-- 空中状態の共通ペナルティ（削除禁止）
-- 通常ジャンプ・空中ジャンプ・落下中を問わず常に適用
Config.Airborne = {
	AccuracyPenalty   = 0.30, -- 命中精度 -30%
	DisableDodge      = true, -- 回避不可
	AppliesToAllJumps = true,
}

--==================================================
-- 5. レーダー
--==================================================

Config.Radar = {
	Mode        = "Global", -- 全プレイヤーの位置を常時表示
	UpdateRate  = 0.1,
	ShowHeight  = false,    -- 高さ情報は表示しない（数少ない隠れた情報）
	ShowDeployables = true, -- 設置物も表示する

	--[[
		実装上の必須事項:
		サーバー側で電磁迷彩使用者を除外してから送信すること。
		クライアント側での非表示処理は禁止（改造で丸見えになる）。
		光学迷彩使用者は座標を送ってよいが、別アイコンで表示する。
	]]
}

--==================================================
-- 6. 武器
--==================================================
-- Handedness: "Two" = 両手 / "One" = 片手 / "None" = 手を使わない

Config.Weapons = {

	Assault = {
		Category        = "Offensive",
		Handedness      = "Two",
		DamageBody      = 18,
		HeadshotMul     = 1.5,
		RPM             = 600,
		MagSize         = 30,
		Mags            = 4,
		UseCostHP       = 1,
		RangeEffectiveM = 40,
		MoveSpeedMul    = 1.00,
		SwitchInSec     = 0.4,
		SwitchOutSec    = 0.4,
		ReloadSec       = 2.2,
		SpreadDeg       = 1.0,
	},

	Shotgun = {
		Category        = "Offensive",
		Handedness      = "Two",
		DamageBody      = 12,
		Pellets         = 8,
		HeadshotMul     = 1.5,
		RPM             = 70,
		MagSize         = 6,
		Mags            = 5,
		UseCostHP       = 4,
		RangeEffectiveM = 15,
		MoveSpeedMul    = 1.05,
		SwitchInSec     = 0.4,
		SwitchOutSec    = 0.4,
		ReloadSec       = 3.0,
		SpreadDeg       = 4.0,
	},

	Marksman = {
		Category        = "Offensive",
		Handedness      = "Two",
		DamageBody      = 55,
		HeadshotMul     = 2.0,
		RPM             = 50,
		MagSize         = 8,
		Mags            = 4,
		UseCostHP       = 6,
		RangeEffectiveM = 55,
		MoveSpeedMul    = 0.95,
		SwitchInSec     = 0.5,
		SwitchOutSec    = 0.5,
		ReloadSec       = 2.6,
		SpreadDeg       = 0.4,
	},

	Sniper = {
		Category        = "Offensive",
		Handedness      = "Two",  -- 使用中は片手武器を含む全ての他装備を使用不可
		DamageBody      = 60,     -- 最低最大体力60でも即死させない
		HeadshotMul     = 2.0,    -- 頭部のみ即死
		RPM             = 35,
		MagSize         = 5,
		Mags            = 4,
		UseCostHP       = 3,      -- あえて低め。常時コストを既に払っているため
		RangeEffectiveM = 70,     -- 対面スポーン間距離＝上限

		MoveSpeedMul       = 0.90, -- 通常時
		MoveSpeedMulScoped = 0.40, -- スコープ中
		ScopeDisablesRadar = true, -- 必須。事前照準を防ぐ

		SwitchInSec     = 0.8,    -- 構えるまで
		SwitchOutSec    = 1.0,    -- 下ろすまで（こちらを重くする）
		ReloadSec       = 3.2,
		SpreadDeg       = 0.15,
	},

	Handgun = {
		Category        = "Offensive",
		Handedness      = "One",
		DamageBody      = 22,
		HeadshotMul     = 1.5,
		RPM             = 300,
		MagSize         = 12,
		Mags            = 5,
		UseCostHP       = 0.5,
		RangeEffectiveM = 25,
		MoveSpeedMul    = 1.00,
		SwitchInSec     = 0.3,
		SwitchOutSec    = 0.3,
		ReloadSec       = 1.6,
		SpreadDeg       = 1.4,
	},

	Melee = {
		Category        = "Offensive",
		Handedness      = "One",
		DamageBody      = 45,
		HeadshotMul     = 1.0,
		CooldownSec     = 1.2,
		UseCostHP       = 0,      -- 最後の手段は常に残す
		RangeEffectiveM = 3,
		MoveSpeedMul    = 1.10,
		SwitchInSec     = 0.3,
		SwitchOutSec    = 0.3,
		SpreadDeg       = 0,
	},
}

--==================================================
-- 7. シールド
--==================================================

Config.ShieldRule = {
	DeployerCanAttack      = false, -- 展開者本人は攻撃できない
	BlocksAllyFire         = false, -- 味方の弾は通す
	BlocksEnemyFire        = true,  -- 敵の弾は遮る
	LockWeaponSwitch       = true,  -- 展開中は両ラインとも切替不可

	MaxPerLine             = 1,     -- 各ライン1種まで（最大2枚）

	BreakPenaltyHP         = 15,    -- 破壊時の体力ペナルティ
	RequireCycleToRedeploy = true,  -- 再展開には一度別装備への切替が必要
	RedeployScope          = "Category", -- "Slot" にしないこと（下記理由）
	--[[
		RedeployScope を "Slot" にすると、ライン1のシールドが破壊された直後に
		ライン2のシールドを0秒で展開でき、切替を挟む制約が迂回される。
		必ず "Category" とし、1枚壊れたら全シールドを再装填待ちにすること。
	]]

	--[[
		ダメージ計算:
			プレイヤー被害 = 元ダメージ × (1 - DamageReduction)
			シールド耐久  -= 元ダメージ
			耐久0以下で消滅（その弾には軽減が適用される）
	]]
}

Config.Shields = {

	-- 実装順: Standard を完成させてから、他2種をパラメータ違いで追加する
	Standard = {
		Category        = "Shield",
		Handedness      = "None",
		DeployCostHP    = 12,
		DurationSec     = 3,
		Health          = 40,   -- スナイパー1発(60)で破壊される
		DamageReduction = 0.40,
		WidthM          = 1.2,  -- 狭い。側面から回り込める
		HeightM         = 1.5,
		CooldownSec     = 6,
		DeployRangeM    = 3,
		AllowAirPlace   = true,
	},

	Focus = {
		Category        = "Shield",
		Handedness      = "None",
		DeployCostHP    = 15,
		DurationSec     = 3,
		Health          = 90,
		DamageReduction = 0.60,
		WidthM          = 0.8,  -- 極端に狭い。1歩ずれれば無効
		HeightM         = 1.4,
		CooldownSec     = 6,
		DeployRangeM    = 3,
		AllowAirPlace   = true,
	},

	Wide = {
		Category        = "Shield",
		Handedness      = "None",
		DeployCostHP    = 18,
		DurationSec     = 2.5,
		Health          = 20,
		DamageReduction = 0.25,
		WidthM          = 3.5,  -- 味方複数人を守れる唯一の装備
		HeightM         = 2.0,
		CooldownSec     = 6,
		DeployRangeM    = 3,
		AllowAirPlace   = true,
		ProtectsAllies  = true,
	},
}

--==================================================
-- 8. 支援装備
--==================================================

Config.Deployable = {
	RemoveOnOwnerDeath = true, -- 設置者の死亡で消滅
	RemoveOnMatchEnd   = true,
	AllowRemotePlace   = false, -- 遠隔設置は実装しない
}

Config.Gear = {

	Barricade = {
		Category        = "Deployable",
		Handedness      = "None",
		DeployCostHP    = 25,

		CastTimeSec     = 1.2,   -- ★テストプレイで最初に調整する数値
		CastRooted      = true,  -- 生成中は移動不可（膠着防止の主機構）
		CastCancelable  = true,
		CastRefundRatio = 0.5,

		DurationSec     = 10,
		Health          = 200,
		WidthM          = 4.0,
		HeightM         = 1.8,   -- 通常ジャンプ(1.9m)で越えられる
		MaxActive       = 1,
		CooldownSec     = 15,
		DeployRangeM    = 5,
		ShowOnRadar     = true,

		Purpose         = "BlockLineOfSight", -- 通行阻止は目的としない
	},

	AirJump = {
		Category           = "Mobility",
		Handedness         = "None",
		CostHP             = 10,
		MaxConsecutive     = 2,   -- 着地でリセット
		JumpHeightM        = 8.0,
		LandingCooldownSec = 1.0,
	},

	StealthRadar = { -- 電磁迷彩
		Category        = "Stealth",
		Handedness      = "None", -- 武器を構えたまま潜伏できる
		ActivateCostHP  = 5,
		CostPerSec      = 4,
		BreakOnFire     = true,
		ReactivateDelay = 0.5,
		LockoutAtStartSec = 5,    -- 試合開始後5秒は使用不可
		AutoReleaseHP   = 20,     -- 体力20で強制解除
		VisibleToEye    = true,   -- 目視では見える
		VisibleOnRadar  = false,
		--[[
			常時全体レーダー環境下において、姿を消す唯一の手段。
			実質的な必須装備となるが、これは許容する。
			装備率が100%に張り付いた場合、消費コストではなく
			効果を弱める方向で調整すること（例: 移動中は映る）。
		]]
	},

	StealthOptical = { -- 光学迷彩
		Category        = "Stealth",
		Handedness      = "Two",  -- 両手を占有＝移動しかできない
		ActivateCostHP  = 5,
		CostPerSec      = 8,
		SwitchOutSec    = 1.0,    -- 解除に1秒。奇襲は成立しない
		AutoReleaseHP   = 20,
		VisibleToEye    = false,
		VisibleOnRadar  = true,   -- 別アイコンで表示
		FootstepAudible = true,
		ShimmerSpeedThresholdMps = 3.5, -- この速度超で輪郭が歪む
	},
}

-- 攻撃する支援装備（投擲物・トラップ等）
-- 初版では実装しない。将来追加する際の共通規則
Config.OffensiveGearRule = {
	Enabled         = false,
	CategoryLimited = false,
	ChargesPerSlot  = 1,     -- 1スロットあたり1〜2個
	ResupplyInMatch = false,
	Handedness      = "None",
}

--==================================================
-- 9. マップ
--==================================================

Config.Map = {
	Shape         = "Circle",
	DiameterM     = 80,   -- 狭めから始める。広げるのは容易、狭めるのは困難
	SpawnRadiusM  = 35,
	SpawnCount    = 4,
	CenterZoneM   = 20,
	LongSightlines = 3,   -- スナイパー用の長射線を最低2〜3本用意する
}

-- マップ制作の高さ基準（マップ着手前に厳守）
Config.MapStandards = {
	CoverCrouchM  = 1.1,  -- しゃがんで隠れる
	CoverStandM   = 1.8,  -- 立って隠れる
	WallVaultableM = 1.8, -- 以下なら飛び越え可
	WallSolidM    = 2.2,  -- 以上なら飛び越え不可
	FloorHeightM  = 4.0,  -- 建物の階高

	--[[
		不可視キャップ（段階1の実測を受けて追加）

		実測で「助走をつければ 2.2m の壁を越えられる」ことが判明した。
		Roblox のキャラクターは前進速度がある状態だと、脚の当たり判定が縁に
		乗り上げてジャンプ高を超える段差に上がれてしまう。
		JumpHeight を下げて対処すると 1.8m を越えられなくなり、
		「越えられる壁／越えられない壁」の区別そのものが壊れる。

		そこで、越えられない壁の上に不可視の当たり判定を積む。
		高さが足りていても、上に乗れる場所が存在しなくなる。

		このキャップは CanQuery = false とすること。
		そうしないと弾が見えない壁に当たり、遮蔽の高さが実質的に変わってしまう。
	]]
	SolidWallCapM = 1.6,
}

Config.Boundary = {
	Method              = "InvisibleWall", -- 退場システムは実装しない
	ShowGridOnContact   = true,
	CeilingMarginM      = 5,
	RefundOnBlockedJump = false, -- 壁に阻まれてもコストは返却しない
}

--==================================================
-- 10. Bot
--==================================================

Config.Bot = {
	Enabled          = true,
	FillToTeamSize   = true,
	Loadout          = { "Assault", "Handgun" }, -- 固定軽装
	AllowSwitching   = false,  -- 切替判断をさせない
	AllowGear        = false,  -- 支援装備を使わせない
	AimAccuracy      = 0.55,
	ReactionTimeSec  = 0.45,
}

--==================================================
-- 11. UI
--==================================================

Config.UI = {
	ShowCategoryColorOnSlot = true,
	ShowCategoryIcon        = true,
	ShowMaxHPPreview        = true,  -- 空けられることを見せる（必須）
	ShowSlotCount           = true,
}

-- スロット表示の記号は「手の数」と対応させる
Config.CategoryDisplay = {
	TwoHandWeapon = { symbol = "■■", color = Color3.fromRGB(220,  70,  60) },
	OneHandWeapon = { symbol = "■",  color = Color3.fromRGB(230, 140,  50) },
	Shield        = { symbol = "◇",  color = Color3.fromRGB( 60, 140, 220) },
	Deployable    = { symbol = "▤",  color = Color3.fromRGB( 70, 180, 110) },
	Mobility      = { symbol = "▲",  color = Color3.fromRGB(220, 200,  70) },
	Stealth       = { symbol = "◐",  color = Color3.fromRGB(150,  90, 200) },
}

--==================================================
-- 12. 初版プリセット
--==================================================
-- 自由編成UIは最終段階で実装する。それまではこの3種から選択させる

Config.Presets = {
	{
		Name  = "突撃型",
		Line1 = { "Assault", "Melee", nil, nil },
		Line2 = { "StealthRadar", "Shield_Standard", nil, nil },
	},
	{
		Name  = "斥候型",
		Line1 = { "Sniper", "Handgun", nil, nil },
		Line2 = { "StealthRadar", "Shield_Focus", "AirJump", nil },
	},
	{
		Name  = "支援型",
		Line1 = { "Shotgun", "Melee", nil, nil },
		Line2 = { "Shield_Wide", "Barricade", "StealthRadar", nil },
	},
}

--==================================================
-- 14. 戦闘処理（実装用パラメータ）
--==================================================
-- 段階1（移動・射撃・ヒット判定）の実装で必要になった値。
-- ゲームデザイン上の数値ではなく、サーバー権威処理のための実装値。

Config.Combat = {
	Hitscan             = true,  -- 段階1は即着弾。弾速実装は当面行わない
	FireRateTolerance   = 0.90,  -- 連射間隔検証の許容係数（回線遅延の吸収用）
	MaxAimDistanceM     = 200,   -- クライアントから届く照準点の妥当性上限
	HeadPartName        = "Head",

	--[[
		空中時の実効拡散:
			effectiveSpreadDeg = Weapons[x].SpreadDeg / (1 - Airborne.AccuracyPenalty)
		AccuracyPenalty = 0.30 なら拡散は約1.43倍になる。
		この計算はサーバー側でのみ行うこと（クライアントは描画のみ）。
	]]
	AirborneSpreadFromPenalty = true,

	--[[
		射程:
			レイの最大長 = Weapons[x].RangeEffectiveM
		距離減衰は実装しない（仕様書に減衰の記述がないため）。
		実効射程を超えた弾は命中しない。
	]]
	RangeIsHardLimit    = true,
}

--==================================================
-- 15. 段階1 検証用アリーナ
--==================================================
-- 本番マップではない。移動・ジャンプ・射撃・遮蔽の検証専用。
-- 段階9以降で本番マップに差し替える。

Config.TestArena = {
	Enabled        = true,
	FloorDiameterM = 80,
	CoverCount     = 12,  -- 高さ基準(MapStandards)の遮蔽物をリング状に配置
	LongSightlines = true,

	--[[
		高さ検証台

		「何mまでなら助走で越えられるか」を実測するための設備。
		仕様書 9. は「基準を先に確定してからマップ制作に入ること」としている。
		基準が実機の挙動と合っていないままマップを作ると、
		全域で「登れる/登れない」の修正が発生する。

		キャップ無しの壁を 0.2m 刻みで並べる。助走をつけて順に試し、
		越えられた最大の高さを WallSolidM の判断材料にする。
	]]
	HeightProbe = {
		Enabled     = true,
		HeightsM    = { 1.8, 2.0, 2.2, 2.4, 2.6, 2.8, 3.0, 3.2 },
		SpacingM    = 6.0,   -- 壁の間隔。助走距離を確保する
		OffsetM     = 28.0,  -- 中心からの距離。遮蔽リング(20m)とスポーン(35m)の間
		WidthM      = 4.0,
		ThicknessM  = 0.6,
	},
}

--==================================================
-- 13. 要調整項目（実プレイで計測し判断する）
--==================================================

Config.TuningWatchlist = {
	{ path = "Gear.Barricade.CastTimeSec",  current = 1.2, trigger = "誰も使わない / 簡単すぎる" },
	{ path = "Gear.StealthRadar.CostPerSec",current = 4,   trigger = "装備率が100%に張り付く" },
	{ path = "Map.DiameterM",               current = 80,  trigger = "平均試合時間90秒未満 / 接触が遅い" },
	{ path = "Map.SpawnRadiusM",            current = 35,  trigger = "開幕の交戦が早すぎる" },
	{ path = "Scoring.SoleSurvivorBonus",   current = 2,   trigger = "最後まで隠れる者が出る" },
	{ path = "SlotCost",                    current = "-40", trigger = "軽装一択 / 重装一択になる" },
	{ path = "STUDS_PER_METER",             current = 3.571, trigger = "体感速度・高さが仕様と合わない" },
}

return Config
