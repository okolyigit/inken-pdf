#!/usr/bin/env bash
# "Başlarken" / "Getting Started" PDF'lerini HTML kaynaklarından üretir ve
# uygulamanın varlıklarına yazar (ilk açılışta ve Yardım menüsünden açılır).
# Gerekenler: chromium, ağ (Lucide ikonları jsDelivr'den yüklenir).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/../../apps/inken/assets/guide"
mkdir -p "$out"
for pair in "baslarken.html:baslarken.pdf" "getting-started.html:getting-started.pdf"; do
  src="${pair%%:*}"; dst="${pair##*:}"
  chromium --headless --disable-gpu --no-pdf-header-footer \
    --allow-file-access-from-files --virtual-time-budget=10000 \
    --print-to-pdf="$out/$dst" "file://$here/$src" 2>/dev/null
  echo "$out/$dst"
done
