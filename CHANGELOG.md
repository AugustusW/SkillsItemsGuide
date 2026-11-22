# Changelog

每個版本一段，標題是 `## <版本>`；段內小標用 `###`。發版時 GitHub Release 與 CurseForge 的更新說明取自對應的段落。

## 0.5.0

- 永恆：專業分頁的配方清單，有來源資料的列多一個「學會方式」標籤：自動學會（學會專業時就有）、配方（要靠配方書）、訓練師。打開過某專業的訓練師視窗後，該視窗列出的配方會改成金色訓練師標籤並加打勾（已確認）；同時也由配方書教的配方，確認後同樣改成金色訓練師標籤。沒確認的訓練師配方維持灰色（資料推定），沒有打勾；「訓練師（推定）」與提示只出現在資料推斷為訓練師教的配方，不是每個沒確認的配方都有
- 永恆：登入時，如果有學的專業還沒打開過訓練師視窗，聊天視窗會多一行提醒（例：「急救、裁縫的訓練師還沒打開過，打開一次即可確認配方來源」）；每個專業的訓練師打開過一次就不再提醒
- 永恆：配方名稱後面的色塊依你目前的專業技能，顯示這個配方對你的升技程度：橘、黃、綠、灰。只有你的角色有該專業時才會出現；已知可學門檻（配方書的需要技能，或打開過訓練師後記下的技能需求）而技能還不到時不顯示
- 永恆：滑鼠移到專業清單的配方圖示，tooltip 新增「學會方式」段落：配方書（含需要的技能與等級）、聲望需求、陣營標示（[聯盟]／[部落]）、任務獎勵（含任務所在地區）。你自己陣營的來源排前面，另一陣營的整段灰字。每個配方最多列 3 本配方書、每本最多 3 個任務，其餘顯示「另有 N 個」。訓練師學費只在該訓練師確認後才顯示；未確認時顯示「訓練師（推定）」與提示，請到訓練師打開一次視窗
- 永恆：同一個配方圖示 tooltip 新增「技能點數」段落，列出橘、黃、綠、灰各在技能幾點；橘色（可學門檻）取自配方書的需要技能或訓練師，兩者都還沒有時顯示「-」，打開過該專業的訓練師後補上
- 永恆：「學會方式」裡的配方書名依物品品質上色（白、綠、藍、紫）
- 永恆：滑鼠移到專業清單的配方圖示時，配方 tooltip 旁邊會顯示該配方第一本屬於你陣營（或不分陣營）的配方書的遊戲 tooltip；沒有屬於你陣營的配方書就不顯示。遊戲顯示裝備比較時，配方書排在比較 tooltip 的外側；螢幕右邊放不下時改放到左邊。「學會方式」與「技能點數」只出現在這個專業清單的配方圖示 tooltip，其他地方的物品 tooltip 沒有

---

- Forever: recipe rows in the Professions tab that have source data now show an acquisition label: Auto (learned with the profession), Recipe (needs a recipe book) or Trainer. After you open a profession's trainer window, the recipes that window lists switch to a gold Trainer label with a check mark (confirmed); a recipe that is also taught by a book switches to the gold Trainer label too once confirmed. Unconfirmed trainer recipes stay grey with no check mark (inferred from data); the "Trainer (inferred)" label and hint apply only to recipes the data infers as trainer-taught, not to every unconfirmed recipe.
- Forever: on login, if a profession you know has never had its trainer window opened, one extra chat line reminds you (e.g. "Open the First Aid, Tailoring trainer once to confirm recipe sources"); it stops once each trainer has been opened.
- Forever: a colored block after the recipe name shows how much the recipe can raise your current skill: orange, yellow, green or grey. It only appears if your character has that profession; when the recipe's minimum is known (from its recipe book, or recorded when you open the trainer) and your skill is below it, no block is shown.
- Forever: hovering a recipe icon in the Professions list, the tooltip has a new "How to learn" section: recipe books (with required skill and level), reputation requirements, faction tags ([Alliance]/[Horde]) and quest rewards (with the quest's area). Sources for your own faction are listed first; the other faction's are greyed out. At most 3 recipe books per recipe and 3 quests per book are listed, the rest shown as "N more". The trainer cost is shown only once that trainer is confirmed; until then the section says "Trainer (inferred)" with a hint to open the trainer window once.
- Forever: the same recipe icon tooltip has a new "Skill points" section listing the skill points where the recipe turns orange, yellow, green and grey. The orange value (the learning minimum) comes from the recipe book or the trainer; until either is known it shows "-", filled in once you open that profession's trainer.
- Forever: recipe book names in "How to learn" are colored by item quality (white, green, blue, purple).
- Forever: hovering a recipe icon in the Professions list also shows the game tooltip of the recipe's first recipe book that is for your faction (or for both factions) beside the recipe tooltip. If no book is for your faction, nothing extra is shown. When the game shows item comparison tooltips, the recipe book is placed outside them, and on the left if there is no room on the right. "How to learn" and "Skill points" appear only in this Professions list tooltip, not on item tooltips elsewhere.

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
