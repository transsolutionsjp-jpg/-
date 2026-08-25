# 多チーム戦術バトル（Roblox / Luau）

仕様は [`CLAUDE.md`](CLAUDE.md) に置いてある。実装はそちらに従う。
**設計の核：チームで行動して相手を倒すこと。** 核に反する変更を加えないこと。

---

## 現在の進捗

| 段階 | 内容 | 状態 |
|---|---|---|
| 0 | GameConfig.lua の作成 | 完了 |
| 1 | 移動・射撃・ヒット判定（武器1種のみ） | 完了 |
| 1.5 | 体力消費型の射撃 | 完了 |
| 1.7 | 継続ダメージ | 完了 |
| 2 | Bot（固定軽装） | 未着手 |
| 3 | チーム分け・得点集計・終了判定 | 未着手 |
| 4 以降 | レーダー・ライン切替・スナイパー … | 未着手 |

段階1で使う武器は `Assault` のみ。ライン切替は段階4.5で
「ラインのアクティブスロットを1つ進める」汎用処理として実装する。

---

## 構成

```
default.project.json          Rojo のプロジェクト定義
src/
  ReplicatedStorage/
    GameConfig.lua            調整可能な数値は全てここ。直書き禁止
  ServerScriptService/
    SV_Main.server.lua        起動・入力受信・プレイヤー管理
    SV_Net.lua                RemoteEvent の生成と取得
    SV_State.lua              プレイヤーごとの権威状態
    SV_Character.lua          生成・移動設定・空中判定・体力初期化
    SV_Combat.lua             射撃・ヒット判定・ダメージ確定・死亡
    SV_Bleed.lua              継続ダメージ
    SV_TestArena.lua          段階1の検証用アリーナ（本番マップではない）
  StarterPlayerScripts/
    CL_Combat.client.lua      入力送信と曳光弾の描画のみ
    CL_HUD.client.lua         体力・弾薬・空中状態の表示のみ
```

### サーバー権威の境界

クライアントがサーバーへ送るのは次の2つだけ。

- `RE_Fire_Weapon(aimPoint: Vector3)` — 「撃ちたい」という意思と照準点
- `RE_Reload_Weapon()` — 「リロードしたい」という意思

連射間隔・弾薬・体力・拡散・レイキャスト・命中・ダメージは全て
`SV_Combat` が確定する。クライアントからダメージ値・体力値を受け取る
RemoteEvent を追加しないこと（仕様書 12. 禁止事項）。

---

## Roblox Studio で動かす

[Rojo](https://rojo.space/) を使う。

```bash
rojo serve
```

Studio 側で Rojo プラグインの Connect を押すと `src/` が同期される。
`Players.CharacterAutoLoads` はサーバー側で `false` にしているので、
Studio のテスト実行でもリスポーンは発生しない（1試合1命）。

Rojo を使わない場合は、`src/` の各ファイルを対応するサービス配下へ
手で配置してもよい。ファイル名の接尾辞と Instance の対応は次のとおり。

| ファイル名 | Instance |
|---|---|
| `*.lua` | ModuleScript |
| `*.server.lua` | Script |
| `*.client.lua` | LocalScript |

---

## 操作

| 入力 | 動作 |
|---|---|
| 左クリック（長押し） | 射撃 |
| R | リロード |
| Space | ジャンプ（1.9m／着地後0.4秒は再ジャンプ不可） |

---

## 段階1で確かめること

検証用アリーナ（`SV_TestArena`）は高さ基準どおりの遮蔽物を並べてある。
色の意味は次のとおり。

| 色 | 高さ | 期待する挙動 |
|---|---|---|
| 緑 | 1.1m | しゃがんで隠れる |
| 黄 | 1.8m | 立って隠れる／ジャンプで越えられる |
| 赤 | 2.2m | 越えられない |

確認事項:

1. 移動速度7m/秒で中心まで約5秒か
2. 1.8mを越えられて2.2mを越えられないか
3. 空中で撃つと明確に当たらなくなるか（照準が開く）
4. 撃つたびに体力バーが減るか。体力1未満になる撃ち方ができないか
5. 被弾後3秒間、毎秒1ずつ減るか。体力15以下で止まるか

`Config.STUDS_PER_METER` は段階1で実機検証して体感に合わせてよい。
数値を変えるときは必ず `GameConfig.lua` を編集する。

---

## GameConfig への追加

仕様書にない値のうち、段階1の実装に必要だったものを追加した。
ゲームデザイン上の判断ではなく、実装上必要な値であることを明記してある。

| 追加 | 理由 |
|---|---|
| `Weapons[*].ReloadSec` | リロード時間が未定義だった |
| `Weapons[*].SpreadDeg` | 「命中精度 -30%」を適用する基準値が必要 |
| `Config.Combat` | 連射間隔の許容係数・照準点の妥当性上限など |
| `Config.TestArena` | 検証用アリーナの寸法 |

空中時の実効拡散は次の式で求める。

```
effectiveSpreadDeg = Weapons[x].SpreadDeg / (1 - Airborne.AccuracyPenalty)
```

`AccuracyPenalty = 0.30` なら拡散は約1.43倍になる。
この計算はサーバー側でのみ行う。

---

## 次の段階

段階2（Bot）。`Config.Bot` は既に定義済みで、固定軽装
`{ "Assault", "Handgun" }`・切替なし・支援装備なし。
`SV_Combat.ApplyDamage` は Player に紐づかない Humanoid にも通るように
してあるので、Bot の体力処理はそのまま乗る。

実装順序は飛ばさないこと。
