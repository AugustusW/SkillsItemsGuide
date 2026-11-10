# SkillsItemsGuide（技能物品指南）

An addon for **World of Warcraft: Forever** (Interface 16001) and **Retail** (Midnight, Interface 120105): material reverse lookup in tooltips and recipe breakdown trees with raw-material totals and cooldowns. Forever also has class skill levels with training costs. Data is bundled and works offline.

- Retail: 11,042 recipes across all expansions; quality tiers of the same reagent are merged into one entry, and recipes from older expansions are labeled.

- Hold **Shift** on an item to see recipes from your professions that use it (green = learned).
- **Alt+left-click** an item in your bags, type `/sig`, or click the entry in the addon compartment next to the minimap to open the full window.
- Open each profession window once to mark learned recipes (on Forever, also your class trainer to fill in training costs). On Retail, ranked recipes count as learned when any rank is known.
- Download: [CurseForge](https://www.curseforge.com/wow/addons/skillsitemsguide). Support: support@augustusw.com · [Buy me a coffee / 請我喝杯咖啡](https://link.augustusw.com/coffee). License: MIT.

If this addon helps you, a star on the repo helps other players find it. 覺得好用的話，幫這個 repo 按個星，能讓其他玩家更容易找到。

---

魔獸世界：永恆（Interface 16001）與正式版（至暗之夜，Interface 120105）用的 addon。材料反查、配方樹狀拆解，資料離線打包；永恆另有職業技能等級查詢。

正式版收錄各資料片共 11042 條配方，同一材料的不同品質合併計算，舊資料片的配方會標出資料片名稱。

## 安裝

從 [CurseForge](https://www.curseforge.com/wow/addons/skillsitemsguide) 下載（CurseForge App 可自動更新），或手動安裝：

把整個 `SkillsItemsGuide` 資料夾放到 `_forever_/Interface/AddOns/`（正式版是 `_retail_/Interface/AddOns/`），角色選擇畫面勾選「技能物品指南」。兩個版本用同一個資料夾，遊戲會自動載入對應的 TOC。
裝過探測版 `CraftSkillBook` 的話，先刪掉那個資料夾。

## 使用

- 物品 tooltip：多一行「專業（數量）」；按住 Shift 列出你有學的專業會用到它的配方（最多 8 條）
  - 綠色＝已學會；灰白＝還沒學，或該專業視窗還沒打開過所以不知道（最後一行會提示）。這裡的綠色不是物品品質
- 背包物品 **Alt+左鍵**：開完整視窗並列出用到它的配方（材料反查）
- 小地圖旁的插件收納按鈕：點「技能物品指南」開關完整視窗
- `/sig` 或 `/skillsitemsguide`：開關完整視窗（指令被其他插件佔用時不註冊）
  - 專業分頁：搜尋、依專業瀏覽、數量、滑鼠移到圖示看拆解、「+」展開、Shift+點圖示貼連結
  - 職業技能分頁（永恆限定）：職業下拉、搜尋、已學會／可以學／等級還不到篩選、學費
- `/sigcheck`：檢查已學配方和打包資料對得上多少
- `/sigprobe`：開發用的 API 探測

先開一次自己的專業視窗，tooltip 和清單才知道哪些配方學過。正式版的分級配方（同一成品 1～3 級）學了任一級就算學會。

## 訓練師快取（學費與實際等級）

打包資料的職業技能等級來自永恆 beta 客戶端資料表，沒有學費。開過訓練師視窗後，addon 會記下該職業／專業的完整清單（含還不能學的）。
把 `WTF/Account/<帳號>/SavedVariables/SkillsItemsGuide.lua` 交給維護者，執行
`python3.12 tools/build_data.py all --sv <檔案>` 併入，標示為「已校正」。

## 問題回報

作者 AugustusW，問題與建議請寄 support@augustusw.com。

遇到問題時輸入 `/sig errors`，按「全選」後用 Ctrl+C 複製，把內容一起寄來會比較好查。紀錄只存在本機（最近 20 種錯誤，不含角色與帳號名稱），插件不會連網。

## 資料來源與版本

- 永恆專業：官方 Web API（`static-1.60.1_70399-forever-tw`），經 `tools/build_data.py professions` 產生
- 正式版專業：官方 Web API（`static-12.1.5_70077-tw`）＋ wago.tools 12.1.5 客戶端資料表的材料槽與品質，經 `tools/build_data.py retail` 產生
- 職業技能、冷卻、配方對應法術：wago.tools 的 1.60.1.70532 客戶端資料表
- 遊戲內 API 白名單：`/sigprobe` 在 build 1.60.1.70862 的結果（`tools/gen_manifest.py`）

## 開發

- 測試：`luajit tests/harness.lua . tests/test_*.lua`（假的 WoW API，白名單來自遊戲內 `/sigprobe` 探測）
- 遊戲是 Lua 5.1，語法檢查請用 luajit：`luajit -b <檔案> /dev/null`
- 資料檔 `Data/Forever/*.lua`、`Data/Retail/*.lua` 由作者的資料工具產生，不要手改
