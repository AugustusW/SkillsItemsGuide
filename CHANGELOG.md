# Changelog

每個版本一段，標題是 `## <版本>`；段內小標用 `###`。發版時 GitHub Release 與 CurseForge 的更新說明取自對應的段落。

## 0.4.1

- 永恆資料更新到最新客戶端（1.60.1.71037）：職業技能清單與學習等級跟著遊戲調整（例：聖騎士、盜賊、德魯伊）
- 永恆物品新增 74 件，包含九套新的整套裝備
- 永恆配方：部分材料數量、物品等級與技能需求更新，2 個配方補上對應法術

---

- Forever data updated to the latest client (1.60.1.71037): class skill lists and training levels follow the game's changes (e.g. Paladin, Rogue, Druid)
- 74 new Forever items, including nine new armor sets
- Forever recipes: updated some reagent counts, item levels and skill requirements; 2 recipes now link their spell

## 0.4.0

- 新增「物品」分頁（永恆）：搜尋永恆全部物品（約 1.7 萬筆），依配方材料／可製作、專業、物品類別、品質篩選，依物品等級排序。配方相關物品點一下看由哪些配方製作、用在哪些配方，再點配方會跳到專業分頁並展開拆解
- 新增「法術」分頁（永恆）：搜尋職業技能與專業配方法術，依職業或專業篩選，點一下跳到職業技能或專業分頁的那一列
- 物品支援 Ctrl+點試穿、Shift+點貼連結
- 清單超過 100 筆時可按「顯示更多」
- 介面標明資料來源（Blizzard API、遊戲客戶端資料表）
- 英文客戶端：打包英文物品名稱，可搜尋全部物品，專業分頁不再顯示 Item #id
- 修正：法術連結貼到對話後別人無法點開
- 修正：部分永恆新物品名稱顏色顯示成白色

---

- New Items tab (Forever): search all Forever items (about 17,000), filter by reagent/craftable, profession, item type and quality, sorted by item level. Click a recipe-related item to see which recipes make or use it, then click a recipe to jump to its breakdown in the Professions tab.
- New Spells tab (Forever): search class skills and profession recipe spells, filter by class or profession, and click to jump to that entry in the Class skills or Professions tab.
- Items support Ctrl+click to try on and Shift+click to link.
- Lists longer than 100 entries now have a "Show more" button.
- The window now credits its data sources (Blizzard API and game client tables).
- English clients: item names are now bundled in English, so all items are searchable and the Professions tab no longer shows "Item #id" placeholders.
- Fixed: spell links pasted into chat could not be opened by others.
- Fixed: some Forever-only items showed their names in white instead of their quality color.

## 0.3.0

Adds a local error log. Type `/sig errors` to copy recent errors when reporting a problem. Records stay on your computer; the addon never connects to the network.

## 0.2.1

Added
- Entry in the addon compartment next to the minimap (Forever and Retail): click to open or close the full window; hover for a short how-to. No minimap button is added.

## 0.2.0

Added
- Retail support (Midnight 12.1.5): reagent lookup, Shift recipe list, Shift breakdown and the full window all work. Retail covers item lookup only; the class skill tab stays Forever-only.
- 11,042 retail recipes across 14 professions and all expansions. Quality tiers of the same reagent are merged into one entry.
- Reagent tooltips list current-expansion and older-expansion recipe counts separately; the full window labels older-expansion recipes with their expansion.
- Ranked legacy recipes (ranks 1–3 for the same item) count as learned when any rank is known.

Fixed
- Full-window recipe icon tooltip lost its breakdown when Shift was pressed.
- Opening someone else's profession (chat link, guild member, crafting order) recorded their recipes as learned.

Other
- Separate TOCs for Forever and Retail; the game loads the matching one.
- Upgrading by extracting over an old install leaves SkillsItemsGuide.toc and Data/Professions.lua behind. They are ignored and can be deleted.
- On Retail, open each profession window once to mark learned recipes.

## 0.1.1

- Fixed: items in the full window could stay as "Item #1234" and search could get stuck on "Names loading...". Names are now retried, and official Traditional Chinese names are bundled as a fallback.
- Improved: hovering a recipe icon in the full window now shows the item's own tooltip first (stats, type, sell price), followed by the breakdown.

---

- 修正：完整視窗的物品可能一直顯示「物品 #1234」，搜尋可能卡在「名稱載入中…」。現在會重試載入名稱，並內建官方繁中名稱當備用。
- 改進：完整視窗滑鼠移到配方圖示時，先顯示物品本身的 tooltip（屬性、類型、售價），下面接拆解樹。

Download: [CurseForge](https://www.curseforge.com/wow/addons/skillsitemsguide) or the zip below.

## 0.1.0

First release for World of Warcraft: Forever (Interface 16001).

- Material tooltip: which professions use an item; hold Shift for recipes from your professions (green = learned)
- Alt+left-click an item in your bags, or `/sig`, to open the full window
- Recipe breakdown trees with raw-material totals and cooldowns
- Class skills by level with training costs
- Support: support@augustusw.com

---

魔獸世界：永恆首版。

- 材料 tooltip：哪些專業用得到；按住 Shift 看你有學的專業配方（綠＝已學）
- 背包物品 Alt+左鍵或 `/sig` 開完整視窗
- 配方樹狀拆解，算出原料總數與冷卻次數
- 職業技能依等級列出學費
- 問題回報：support@augustusw.com
