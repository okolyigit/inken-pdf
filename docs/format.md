# Inken dosya formatı

Inken'in kaydettiği dosya sıradan bir PDF'tir. Her PDF okuyucu çizimleri görür; Inken ise onları düzenlenebilir olarak geri açar. Dosyada iki katman vardır:

1. **Görünür katman:** her çizim öğesi için bir PDF açıklaması (annotation), kendi görünüm akışıyla (`/AP /N`).
2. **Düzenlenebilir katman:** belgeye gömülü `inken.json` eki (embedded file). Asıl kaynak budur; açıklamalar ondan üretilir. Görsellerin baytları ayrı eklerdedir: `inken-image-<imageId>.png`.

## Kayıt kuralları

- Kaydederken yalnızca `/NM` değeri `inken:` ile başlayan açıklamalar silinip yeniden yazılır. Başka programların açıklamalarına dokunulmaz.
- `inken.json` her kayıtta değiştirilir (aynı adla birden fazla ek bırakılmaz).
- Görsel ekleri: modelde kullanılan her görsel için bir `inken-image-<imageId>.png`; kullanılmayanlar silinir. Aynı görsel birden çok öğede kullanılırsa bir kez saklanır. Düzleştirilmiş dışa aktarmada hiç görsel eki kalmaz.
- Tam kayıt yapılır (artımlı değil). Dosyaya önce geçici bir dosya (`<hedef>.inken-tmp`) yazılır, sonra `rename` ile yerine konur.
- Düz bir PDF ilk kez kaydedilirken orijinale dokunulmaz; yanına `<ad>_inken.pdf` yazılır. O ad doluysa `<ad>_inken (2).pdf`, `(3)`… Inken dosyası (içinde `inken.json` olan) kendi üstüne kaydedilir.
- Şifreli ya da imzalı dosyalar her zaman kopyaya kaydedilir.

## Açarken

- `inken.json` yoksa dosya düz PDF'tir; model boş başlar.
- `inken.json` varsa model ondan yüklenir. Görüntüleyiciye, `inken:` açıklamaları silinmiş bir bellek kopyası verilir; çizimleri Inken'in kendi katmanı çizer.
- Aşağıdaki durumlarda dosya **açılmaz** (açılıp kaydedilse eski çizimler sessizce silinirdi):
  - `formatVersion` uygulamanın bildiğinden büyükse;
  - `inken.json` geçersizse;
  - modeldeki sayfa sayısı dosyadakiyle tutmuyorsa (dosya başka bir programla değiştirilmiş).

## `inken.json` şeması (formatVersion 3)

```jsonc
{
  "formatVersion": 3,
  "pages": [
    {
      "sourceIndex": 0,          // bu sayfanın dosyadaki sırası (0'dan)
      "template": null,          // Inken'in eklediği sayfalarda: blank | grid | dotted | lined | coordinate
      "color": "black",          // isteğe bağlı, eklenen sayfanın kâğıdı: black | straw (yoksa beyaz)
      "width": 595.0,            // pt, ekranda göründüğü hâliyle (/Rotate uygulanmış)
      "height": 842.0,
      "items": [ /* öğeler */ ]
    }
  ]
}
```

- Sayfa listesi, kaydedilen dosyanın sayfalarıyla **bire bir ve aynı sıradadır**.
- Bellekte, henüz kaydedilmemiş eklenmiş bir sayfanın `sourceIndex`'i `null`'dır ve `template` doludur. Yazıcı bu sayfayı dosyaya gerçek sayfa olarak ekler (zemin sayfa içeriğine çizilir) ve kaydedilen modelde bütün sayfaları yeniden numaralar. Eklenmiş sayfalar `template` değerini kayıttan sonra da korur.
- Bellekte (ve otomatik yedekte) silinmiş kaynak sayfalar modelde yoktur: `sourceIndex`'ler artan sırada ama aralıklı olabilir (ör. 0, 2). Yazıcı modelde olmayan sayfaları dosyadan siler. Kaydedilen `inken.json`'da sayfalar her zaman 0'dan aralıksız numaralıdır; format sürümü değişmedi. Sayfa taşıma (sıranın değişmesi) desteklenmez.
- Bellekte (ve otomatik yedekte) döndürülmüş kaynak sayfada `rotation` (1..3, saat yönünde çeyrek tur, henüz dosyaya yazılmamış) bulunur; `width` / `height` döndürülmüş boyuttur ve çizimler döndürülmüş sayfaya göredir. Yazıcı döndürmeyi sayfanın `/Rotate` değerine ekler; kaydedilen `inken.json`'da `rotation` hiç bulunmaz, bu yüzden format sürümü değişmedi. Eklenmiş sayfa döndürülünce yalnızca boyutu değişir.
- `color` (19 Kasım 2026) isteğe bağlı ve yalnızca eklenen sayfalarda; beyazda yazılmaz. Renk kayıtta sayfa içeriğine çizilir (eski sürümler alanı yok sayar, sayfa yine renkli görünür), bu yüzden format sürümü değişmedi.
- Otomatik yedek (`InkenBackup`, uygulamanın iç formatı) dosyanın o anki sayfa sayısını `sourcePageCount` olarak saklar; yoksa (eski yedek) kaynak sayfalar eksiksiz olmalıdır.
- Şimdilik yalnızca araya ekleme desteklenir. Sayfa silme ve taşıma gelince yazıcı genişletilecek; o zamana kadar sırası bozuk bir model yazıcıda hata verir.

### Koordinatlar

Sayfa uzayı: birim PDF noktası (1/72 inç), orijin sayfanın **ekranda göründüğü hâlinin** sol üst köşesi, y aşağı doğru artar. PDF kullanıcı uzayına dönüşüm (CropBox orijini ve `/Rotate` dahil) yalnızca `inken_pdf` içinde yapılır (`pageToPdfTransform`).

### Öğeler

Her öğenin `type` alanı vardır. Renk `0xAARRGGBB` biçiminde işaretsiz tam sayıdır. Sayılar 1/1000 pt'ye yuvarlanır.

| `type` | Alanlar | PDF karşılığı |
|---|---|---|
| `stroke` | `id`, `tool` (`pen` \| `highlighter`), `color`, `width`, `points` | Ink |
| `shape` | `id`, `kind` (`line` \| `arrow` \| `rectangle` \| `ellipse` \| `coordinate`), `color`, `width`, `x1`, `y1`, `x2`, `y2` | `line`, `arrow`, `coordinate` → Ink; `rectangle` → Square; `ellipse` → Circle |
| `text` | `id`, `text`, `color`, `fontSize`, `x`, `y`, `width`, `height` | Stamp; görünümü DejaVu Sans'ın harf şekilleri (dolgu yolu), font gömülmez. Yazı `/Contents`'te de durur. Satırlar yalnızca `\n` ile; `width` / `height` yerleşimden ölçülür (`measureTextItem`). |
| `image` | `id`, `imageId`, `x`, `y`, `width`, `height` | Stamp; görünümü PDFium'un görsel nesnesi (aşağıda). Baytlar `inken-image-<imageId>.png` ekinde. |

- `points`: düz sayı listesi, `[x0, y0, p0, x1, y1, p1, …]`. `p` 0..1 arası basınçtır; basınç bilgisi olmayan girdide 0,5.
- Kalem kalınlığı basınca göre değişir: `penWidthAt(width, p) = width · (0,35 + 1,3·p)`. Fosforlu kalem sabit kalınlıktadır.
- Şekillerde (x1, y1)–(x2, y2) çizgide ve okta başlangıç ile bitiştir, dikdörtgende, elipste ve koordinat düzleminde karşılıklı iki köşedir.
- Koordinat düzlemi (`coordinate`): eksenler kutunun ortasından kenardan kenara, dört uçta ok başı; 1 cm'lik kare çizgileri orijinden dışa doğru, yalnızca kutunun içinde (kutu büyütülse de kareler 1 cm kalır). Kareler şeklin renginin açık tonunda ve ince (`coordinateGridColor`, `coordinateGridWidth`). PDF'te Ink: Ink listesinde yalnızca eksenler ve ok kanatları, görünüm akışında önce kareler sonra eksenler. Geometri `coordinatePlaneLines` (ekran ve PDF aynı).
- Görselde (x, y) sol üst köşe, `width` / `height` sayfadaki boyuttur (görselin piksel boyutundan bağımsız; oran yapıştırırken korunur). `imageId`, PNG baytlarının SHA-256 özetinin ilk 16 onaltılık hanesidir. Uygulama görseli eklerken uzun kenarını en çok 2048 piksele küçültür ve PNG'ye çevirir.

## PDF açıklamaları

Her açıklama şu sırayla yazılır: `SetRect` → `/NM = inken:<id>` → (Ink'te) `AddInkStroke` → `SetColor` (alfa dahil) → `SetBorder` → `SetAP`. Görünüm akışı varken PDFium `SetColor`'ı reddettiği için bu sıra önemlidir. Bayrak: `Print`.

Görünüm akışları `inken_core`'daki `appearanceFor` ile üretilir. Bu saf Dart'tır ve PDFium olmadan test edilebilir. Ekrandaki çizimle aynı geometriyi kullanır:

- **Sabit kalınlıklı çizgi** (fosforlu ya da basıncı sabit kalem): tek yol, yuvarlak uç ve birleşim. Ara noktalar kontrol noktası, ardışık noktaların ortaları uç noktasıdır (ekrandaki kuadratik eğri, PDF'te kübik olarak). Tek yol olduğu için yarı saydam çizgi kendi üstüne binince koyulaşmaz.
- **Basınçlı kalem:** her parça kendi kalınlığıyla, yuvarlak uçlu ayrı bir yol (`w … S`). Ekran da tam olarak böyle çizer; parça uçları üst üste binerek kesintisiz görünür.
- **Tek nokta:** dolu daire (`f`).
- **Yarı saydamlık:** alfa `SetColor` ile verilir (`/CA`); PDFium bundan `/GS` grafik durumunu üretir, akış `/GS gs` ile başlar.
- `/Rect`: çizgi kalınlığı ve 1 pt pay dahil sınır kutusu.

### Görsel açıklaması

Görsel, `/NM = inken:<id>` adlı bir Stamp açıklamasıdır. Görünüm akışı elle yazılmaz: görsel nesnesi (`FPDFPageObj_NewImageObj` + `FPDFImageObj_SetBitmap`, BGRA) birim kareyi görselin yerine götüren matrisle (`FPDFImageObj_SetMatrix`, döndürülmüş sayfada da) `FPDFAnnot_AppendObject` ile açıklamaya eklenir; PDFium görünüm akışını ve görsel XObject'ini kendisi üretir. Saydamlık yumuşak maske (`/SMask`) olarak korunur. PDFium ve Poppler'da (döndürülmüş ve kırpılmış sayfalar dahil) doğrulandı.

Görselin pikselleri dosyada iki kez bulunur: görünümde (sıkıştırılmış bit eşlem) ve ekte (PNG; Inken'in düzenlenebilir kaynağı).

## Sürüm geçmişi

- **1:** çizgi, şekil, metin.
- **2:** görsel (`image`) öğesi ve görsel ekleri. 1 → 2 dönüştürücüsü veriye dokunmaz; sürüm, görselli dosyayı eski uygulamanın açıp görselleri sessizce silmemesi için arttı (eski uygulama "daha yeni sürüm" der ve dosyayı açmaz).
- **3:** koordinat düzlemi şekli (`kind: coordinate`). 2 → 3 dönüştürücüsü veriye dokunmaz; sürüm, eski uygulama böyle bir dosyayı "bozuk" yerine "daha yeni sürümle yazılmış" diye geri çevirsin diye arttı.

## Sürüm değişikliği

Şema değişirse `currentFormatVersion` (`inken_core/lib/src/inken_core_base.dart`) artırılır ve `serialization.dart` içindeki `_migrations` tablosuna N → N+1 dönüştürücüsü eklenir. Eski dosyalar açılırken sırayla dönüştürülür.
