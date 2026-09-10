# Player Feel Acceptance — UIUX 2026-09-10

跟 `taisen-1to6-nds-player-fun-compare.md` 五條必跟＋`design-player-feel-v1.md`。  
**當 Bosco 係 player。** 空殼／淨指引 **唔**追 playfeel 拍版。唔發明數值。

三閘（順序）：**睇得明 → 拖得郁 → 嚟得切**。

---

## 閘 0 — 睇得明（仍優先收尾）

- [ ] 上＝敵軍只睇｜中＝99C｜下＝己方場（中文）
- [ ] tip「而家做咩／點先過關」
- [ ] 歸城／計略中文肥掣；兵法開局揀，外形≠計略

---

## 五條 → Playfeel（打得似）

| # | 必跟 | Pass（player 語氣） |
|---|---|---|
| 1 | 突撃オーラ ≥1C | 「見環先撞」——未見環唔過關；見環後我仲有時間迎擊／閃 |
| 2 | 迎擊槍尖＋≥1C | 「槍尖常在，我轉面攔到」——唔靠倒數條；轉身窗夠 |
| 3 | 士氣＋計略 | 「撳計略場上出事，盤仲拖到」——FX≤1C；底掣全程可點 |
| 4 | 兵法每場一次 | 「開局揀大招」——場內已用印；唔同計略搶掣 |
| 5 | 城レース・max5 | 「睇城條知贏」——token≤5 唔叠成粥；散退有返城預兆 |

弓延伸：停~1C 蓄勢可讀；走射 v1 可關。

---

## 閘 1 — 拖得郁

- [x] 選→拖有導線／落點；唔係淨自動過關（tip 唔跳拖；match 亦等オーラ≥1C）
- [x] 命中有飛字「突撃／迎擊」＋短震（≤0.3C）；浮字唔叠成「迎擊迎擊」
- [x] 一拇指：≥48dp／計略≥12mm
- 截圖：`feel-drag-live.png` · `feel-drag-hit.png` · `feel-drag-samefaction.png`（Wei=Wei 敵硬描邊）
- FEEL_SHOT=`drag-live`|`drag-hit`|`drag-samefaction`|…；Title=`三國指大戰` only

## 閘 2 — 嚟得切

- [x] 迎擊轉身窗：敵オーラ可見 ≥1C 後先准轉面＋「迎擊」；太早／錯面 → fail/retry；槍尖常駐大光；單粒肥「迎擊」
- [x] 弓停~1C：地面印＋瞄準虛線＋準星；郁就取消；停滿先准第一射（視覺飛字「射」，無發明傷害數）
- [x] 自由教學／對局 HUD C 鐘走表（只 FEEL_SHOT／TUTORIAL_SHOT／DEMO_SHOT 先 freeze）
- [x] 截圖：`feel-intercept-window.png` · `feel-bow-windup.png`（命中續用 `feel-intercept.png`）
- [x] Design 武器角標 sheet＋場漆紋 swatch 已掛（唔再用灰圓／slash）
- [ ] Fail 用語：嚟唔切／睇唔見預兆／擋掣／完全唔似大戦
- 手動驗：教學場2 睇 HUD 由 99C 向下數 ≥1C 先點槍轉面再迎擊；對局選弓停穩數 ~1C 再點射、拖走會取消

---

## 幾時追 Bosco 試

三閘＋五條 **Sim 或真機可玩一局** 先追。之前只丢「睇得明」截圖請他挑毛病，**唔**叫玩感拍版。
