--!nonstrict
--[[
	SV_Net
	配置場所: ServerScriptService/SV_Net

	RemoteEvent の生成と取得のみを担当する。
	命名規則: RE_動詞_名詞

	【厳守】
	クライアントからダメージ値・体力値を受け取る RemoteEvent を追加しないこと。
	クライアントが送ってよいのは「撃ちたい」「リロードしたい」という意思のみ。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

-- クライアント → サーバー（意思のみ。数値結果は一切受け取らない）
local C2S = {
	"RE_Fire_Weapon",   -- 引数: 照準点(Vector3)。ダメージも命中も送らせない
	"RE_Reload_Weapon", -- 引数: なし
}

-- サーバー → クライアント（確定した結果のみ）
local S2C = {
	"RE_Sync_State",  -- 体力・弾薬・リロード状態
	"RE_Notify_Hit",  -- ヒットマーカー（撃った本人にのみ送る）
	"RE_Notify_Shot", -- 曳光弾の描画（全員に送る）
	"RE_Notify_Death",-- 死亡通知
}

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end

local function ensure(name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = folder
	return re
end

for _, name in ipairs(C2S) do ensure(name) end
for _, name in ipairs(S2C) do ensure(name) end

function Net.Get(name: string): RemoteEvent
	local re = folder:FindFirstChild(name)
	assert(re, ("SV_Net: RemoteEvent '%s' が存在しません"):format(name))
	return re
end

return Net
