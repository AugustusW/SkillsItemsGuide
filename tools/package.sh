#!/bin/bash
# 打包 CurseForge 用的 zip：dist/<名稱>-<版本>.zip，zip 最外層是 <名稱>/ 資料夾。
# 內容與 export.sh 相同（toc 列出的檔案＋toc＋README），另外加上 LICENSE。
# 可重現：同一個 commit 打出來的 zip 逐 byte 相同（檔案時間統一用 SOURCE_DATE_EPOCH，
# 未設時取 HEAD 的 commit 時間；檔案依名稱排序後加入）。發版流程靠這點保證 GitHub 與 CurseForge 拿到同一個檔案。
# 目錄名不是插件名時（worktree、發布端 clone）用 PKG_NAME 指定。
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
NAME="${PKG_NAME:-$(basename "$(pwd)")}"
TOCS=("$NAME"_*.toc)
[ -f "${TOCS[0]}" ] || { echo "找不到 ${NAME}_*.toc" >&2; exit 1; }
VER=""
for t in "${TOCS[@]}"; do
  v=$(sed -n 's/^## Version: *//p' "$t" | tr -d '\r')
  [ -n "$v" ] || { echo "$t 沒有 Version" >&2; exit 1; }
  if [ -z "$VER" ]; then VER="$v"; elif [ "$v" != "$VER" ]; then echo "TOC 版本不一致：$t 是 $v，其他是 $VER" >&2; exit 1; fi
done
if [ -n "$(git status --porcelain)" ]; then echo "工作目錄有未 commit 的修改，先 commit 再打包" >&2; exit 1; fi

files=("${TOCS[@]}" README.md LICENSE)
for t in "${TOCS[@]}"; do
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    case " ${files[*]} " in *" $line "*) ;; *) files+=("$line") ;; esac
  done < "$t"
done
# 圖示等資源（toc 的 IconTexture 會用到）不列在 toc 裡，整個 Media/ 一起帶
if [ -d Media ]; then while IFS= read -r m; do files+=("$m"); done < <(git ls-files Media); fi

TMP=$(mktemp -d)
for f in "${files[@]}"; do
  [ -f "$f" ] || { echo "缺少檔案：$f" >&2; exit 1; }
  mkdir -p "$TMP/$NAME/$(dirname "$f")"
  cp "$f" "$TMP/$NAME/$f"
done
EPOCH="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}"
python3 - "$TMP" "$EPOCH" <<'PY'
import os, sys
root, epoch = sys.argv[1], int(sys.argv[2])
for d, dirs, files in os.walk(root):
    for n in dirs + files:
        os.utime(os.path.join(d, n), (epoch, epoch), follow_symlinks=False)
PY
mkdir -p dist
OUT="dist/$NAME-$VER.zip"
rm -f "$OUT"
(cd "$TMP" && find "$NAME" -print | LC_ALL=C sort | zip -qX -@ "$OLDPWD/$OUT")
rm -rf "$TMP"
echo "已打包 $OUT（commit $(git rev-parse --short HEAD)）"
unzip -l "$OUT"
