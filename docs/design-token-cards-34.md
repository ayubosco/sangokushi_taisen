# 手指＝卡 — 3:4 金邊場上 Token — Design 2026-09-11

H0 後下一刀。跟 `design-player-feel-v1.md`／`design-portrait-anim-layers.md`。

## 鎖

| 項 | 要 |
|---|---|
| 比例 | 場上 token **≈3:4** 豎卡（手指拖「一張卡」） |
| 框 | 黑漆面＋**重金邊** |
| 內容 | **淨武器角** 或 半身人物＋武器（**無場景背景**） |
| 選中 | 外圈肥金 ring |
| 敵 | 深粗描邊＋黃敵向箭（已 Pass） |
| 禁 | 抽象灰圓；透視場景底；人體全身剪影 |

## 資產（先塞）

| 檔 | 用途 |
|---|---|
| `token-cards-34/token-cards-34-moodboard.png` | 騎／槍／弓／刀 四張金邊卡一板（槍有選中光） |
| `token-cards-34/token-card-spear-34.png` | 單張槍卡框＋矛頭 |
| `token-cards-34/token-card-zhaoyun-sample.png` | 半身樣（參考；場景底要跟「人物＋配件」再收） |

Backend：用 moodboard／槍卡先換場上 chip；肖像半身下一刀按 anim-layers 重出無風景版。
