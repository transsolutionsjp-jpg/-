# 導入手順（Roblox Studio）

PC操作に不慣れな方向けの詳細版は、チャットで共有した手順書ページを参照してください。
ここには要点だけを置きます。

## 用意するもの

- Roblox アカウント（無料）
- Roblox Studio（`create.roblox.com` からダウンロード）
- 所要時間 約30分

## Rojo を使わない読み込み（推奨・初回）

`install/` に、Roblox Studio へそのまま読み込める形式のファイルを3つ置いてある。
Explorer 内で対象を右クリックし、`挿入` → `Robloxモデルをインポート` で選ぶ。

| 順 | 右クリックする場所 | 選ぶファイル | 入るもの |
|---|---|---|---|
| 1 | `ReplicatedStorage` | `install/1_ReplicatedStorage.rbxmx` | GameConfig |
| 2 | `ServerScriptService` | `install/2_ServerScriptService.rbxmx` | SV_Net / SV_State / SV_Character / SV_Combat / SV_Bleed / SV_TestArena / SV_Main |
| 3 | `StarterPlayer` > `StarterPlayerScripts` | `install/3_StarterPlayerScripts.rbxmx` | CL_Combat / CL_HUD |

順番を守ること。GameConfig が先に無いと、他のスクリプトが設定を参照できない。

### 右クリックメニューの見分け方

`挿入` サブメニューに3項目ある。ファイル選択ダイアログを開くのは最下段。

| 項目 | 動作 | 今回 |
|---|---|---|
| パーツを挿入 | Part を1個置く | 使わない |
| オブジェクトを挿入… | 種類を選んで新規作成する | 使わない |
| **Robloxモデルをインポート** | **保存済みファイルを読み込む** | **これ** |

旧バージョンの `Insert from File…`（ファイルから挿入）に相当する。名称が変わっただけで動作は同じ。

ファイル選択ダイアログに `.rbxmx` が出ない場合は、ファイル種類を「すべてのファイル」に切り替える。

メニュー自体が見つからない場合の代替手段:

1. `.rbxmx` を Studio の3Dビューへ直接ドラッグ＆ドロップする（`Workspace` に入る）
2. Explorer 上で、入ったものを正しい親へドラッグして移動する

`StarterPlayerScripts` と `StarterCharacterScripts` を間違えないこと。
間違えた場合は入れたものを選んで Delete し、正しい場所でやり直す。

Studio 初期状態の Baseplate と SpawnLocation は `SV_TestArena` が自動で削除する。
手で消す必要はない。

## Rojo を使う読み込み（継続開発時）

```bash
rojo serve
```

Studio 側で Rojo プラグインの Connect を押す。`src/` の変更がそのまま同期される。
数値の反復調整を行う段階に入ったらこちらへ移行する。

## 動作確認

`Home` タブ →  `▶ Play`。3〜5秒で円形アリーナが生成される。

| 操作 | 動き |
|---|---|
| W A S D | 移動（秒速7m） |
| Space | ジャンプ（1.9m／着地後0.4秒は不可） |
| マウス右ドラッグ | 視点 |
| マウス左クリック | 射撃（1発につき体力1消費） |
| R | リロード（2.2秒） |

ダメージと継続ダメージの確認には2人必要。
`Test` タブ → `Clients and Servers` → 人数を2 → `Start`。

## 段階1で確かめること

1. スポーンから中心まで約5秒
2. 黄色い壁(1.8m)は越えられる
3. 赤い壁(2.2m)は越えられない
4. 空中射撃で照準が開き、明確に当たらなくなる
5. 撃つたびに体力が減る／体力が尽きると撃てない（自滅しない）
6. 被弾後3秒間、毎秒1ずつ減る
7. 体力15以下で継続ダメージが止まる
8. 倒れてもリスポーンしない

## 数値の調整

`ReplicatedStorage/GameConfig` をダブルクリックして数値のみ書き換える。
`Ctrl+F` で該当箇所を探す。

| 探す言葉 | 現行値 | 効果 |
|---|---|---|
| `STUDS_PER_METER` | 3.571 | 1mの大きさ。全体の縮尺。体感が合わないときは最初にここ |
| `WalkSpeedMps` | 7.0 | 移動速度 |
| `BaseJumpHeightM` | 1.9 | ジャンプ高 |
| `DiameterM` | 80 | マップ直径 |
| `AccuracyPenalty` | 0.30 | 空中での命中精度低下 |

変更後は Stop → Play で再確認する。

## install/ の再生成

`src/` を変更したら、読み込み用ファイルを作り直す。

```bash
python3 tools/build_install.py
```
