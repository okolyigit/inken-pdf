# Değişiklik günlüğü

Inken PDF'in bütün sürümleri, en yenisi üstte. Her sürümün ayrıntılı notu
ve indirme dosyaları GitHub'daki sürüm sayfasındadır.

Bu dosya `packaging/release-notes/` klasöründeki notlardan üretilir
(`python3 packaging/changelog.py`); elle düzenlenmez.

## 0.1.0-beta.12 · 24 Kasım 2026

### Yenilikler

- **Daha ince ikonlar.** Arayüz ikonları ince çizgili; koyu temada daha keskin. Seçili araç dolu zeminde okunsun diye bir kademe kalın.
- **Ekrana uyan araç kutusu.** Kutu sağda ya da soldayken sığıyorsa tek sütun olur (dikey tablet, büyük ekran); yer yetmezse iki sütuna geçer. Tableti çevirince ya da pencereyi büyütüp küçültünce kendiliğinden değişir.

### Düzeltmeler

- Ayarlar → Hakkında'da sürüm numarası Android'de ve Windows'ta "?" görünüyordu.

## 0.1.0-beta.11 · 23 Kasım 2026

### Yenilikler

- **Bölge yakala** (Düzen → Bölge yakala, Ctrl+Shift+C, hızlı erişimde kamera). Sayfada bir alanı çerçeve içine al ya da sayfaya dokunup tamamını seç; sonra **Kopyala** (başka bir uygulamaya yapıştır), **Kaydet**, **Paylaş** ya da **Yeni sayfaya al**. Yeni sayfaya al: seçtiğin soru, arkasına eklenen boş sayfanın üstüne aynı boyda konur, altında çözebilirsin.
- **Dışa aktarma penceresi** (Dosya → Dışa aktar…, Ctrl+E). Çizimli PDF, düzenlenebilir PDF ya da sayfa görselleri (PNG ya da JPEG; 96, 150 ya da 300 dpi; birden çok sayfa tek ZIP dosyasında). Tüm sayfalar, bu sayfa, çizimli sayfalar ya da bir aralık; boş eklenen sayfaları atlama. Önizlemeli.
- **Öğrenci kopyası.** Dışa aktarırken bir rengi gizle: örneğin kırmızıyla yazdığın cevaplar çıkmaz. Belgen değişmez.
- **Sayfayı görsel olarak paylaş.** Dosya menüsünde; sayfa panelinde de sağ tık → Görsel olarak → Kopyala / Kaydet / Paylaş.
- **Daha sıkı arayüz.** Düğmeler, araç kutusu ve hızlı erişim çubuğu küçüldü; yazdırma ve dışa aktarma pencereleri kaydırmadan tek ekrana sığar. Arayüz boyutunda artık Normal ve Büyük var ("Akıllı tahta" seçiliyse Büyük olarak açılır).

## 0.1.0-beta.10 · 23 Kasım 2026

### Yenilikler

- **Sayfaları sırala.** Sayfa panelinde bir sayfayı (ya da seçili sayfaları) sürükleyip istediğin yere bırak; bırakılacak yeri ince bir çizgi gösterir, liste kenara gelince kendiliğinden kayar. Dokunmatikte ve kalemde sayfaya uzun basıp sürükle. Sayfa menüsünde ve seçim şeridinde **Yukarı taşı / Aşağı taşı** da var. Kaydedince sayfalar dosyada da yeni sırada olur; çizimler sayfayla gider. Her taşıma Ctrl+Z ile geri alınır.
- **Sona sayfa ekle.** Hızlı erişim çubuğunda Sayfa ekle düğmesinin yanında **+** var: son seçtiğin zemin, yön ve kâğıt rengiyle belgenin sonuna sayfa ekler.
- **Daha düzenli menüler.** Görünüm menüsündeki çubuk ve panel ayarları **Çubuklar ve paneller** alt menüsünde toplandı; **Spot ışığı** ve **Perde** Araçlar menüsüne taşındı. Alçak pencerede Görünüm menüsü artık başlığını örtmez, kayar; açık menünün başlığı daha sade görünür.

### Düzeltmeler

- Farklı boyutlarda sayfaları olan PDF'lerde (örneğin A4 ile A5 ya da yatay sayfalar bir arada) sayfa boyutları açılışta yanlış alınabiliyordu; araya eklenen sayfaların boyutu ve sayfa panelindeki küçük resimler bundan etkileniyordu.

## 0.1.0-beta.9 · 22 Kasım 2026

### Yenilikler

- **Yeni yazdırma penceresi.** Yazdır artık Inken'in kendi penceresini açar: sayfaların **önizlemesi**, **yazıcı** ve **kopya sayısı**, yazdırılacak **sayfalar** (tümü, geçerli sayfa ya da aralık), **boyut** (sayfaya sığdır / gerçek boyut) ve çizimlerin yazdırılıp yazdırılmayacağı tek yerde. **Diğer seçenekler** altında renkli / gri, çift taraflı, kâğıt boyutu, yön, harmanlama ve ters sıra var; Windows'ta yazıcının kendi ayarları da açılabilir. Seçimlerin hatırlanır. Telefonda tam ekran açılır, yazıcı ve kopya Android'in ekranında seçilir.
- **Daha ince kalemler.** Kalem ve şekil kalınlıkları inceldi: 0,75 / 1,5 / 3 / 5 pt (önceden 1,5 / 3 / 5 / 8). Daha önce çizdiklerin değişmez.
- **Linux'ta grafik tabletle pürüzsüz yazı.** Tablet kalemiyle çizilen çizgiler köşeli ve pikselli görünüyordu; artık kalemin her hareketi alınıyor ve kenarlar yumuşak çiziliyor.

## 0.1.0-beta.8 · 22 Kasım 2026

### Yenilikler

- **Görsel düzenleme.** Seç aracıyla bir görsele çift tıkla (ya da seçim çubuğundaki kırpma düğmesine dokun): görseli **kırp** (Serbest, Orijinal, 1:1, 4:3, 16:9), **sola / sağa döndür**, sayfadaki boyutunu **cm** cinsinden ayarla (🔒 kilitliyken en-boy oranı korunur) ve **opaklığını** değiştir. Telefonda tam ekran açılır. Düzenleme görseli bozmaz: orijinal dosyada kalır, kırpmayı sonradan genişletebilir ya da **Sıfırla** ile geri dönebilirsin.
- **Opaklık.** Seçili metin ve görsellerin saydamlığı seçim çubuğundan %10–100 arası ayarlanır; metin aracında yeni yazının opaklığı da seçilebilir. Diğer PDF okuyucularında da saydam görünür.
- **Telefonda daha düzenli pencereler.** Belge özelliklerinde başlık üstte, bilgi altında; "Kaydedilmemiş değişiklikler" ve yedek geri yükleme pencerelerinde düğmeler tam genişlikte alt alta.

### Önemli

Bu sürümle kaydedilen dosyalar yeni bir kayıt biçimi kullanır. **Eski deneme sürümleri (beta.7 ve öncesi) bu dosyaları açamaz**; Inken'i bu sürüme güncellemen yeterli. Eski dosyalar yeni sürümde sorunsuz açılır.

## 0.1.0-beta.7 · 22 Kasım 2026

### Yenilikler

- **Seç ve Metin seç tek düğmede.** Araç kutusunda ve telefonun alt rafında tek bir **Seç** düğmesi var; en son kullandığın türü seçer. Seçiliyken düğmeye yeniden dokununca **Çizimler** ya da **Metin** seçilir. Telefonda metin seçmek artık alt raftan da yapılabiliyor.
- **Kenara alınan araç kutusu iki sütun.** Araç kutusu sola ya da sağa alınınca kaydırmadan sığar: geri al / yinele üstte; kalem grubu ve silgi sayfaya bakan sütunda, diğer araçlar kenardaki sütunda. Araç seçenekleri kutunun dışında açılır, sütunların üstüne binmez.

## 0.1.0-beta.6 · 22 Kasım 2026

### Yenilikler

- **Telefonda daha kısa yan menü.** Dosya, Düzen, Sayfa, Görünüm ve Yardım bölümleri artık açılır kapanır; başta kapalı gelir, açtığın bölüm belge açıkken açık kalır. **Ayarlar** menünün altında her zaman görünür.
- **Logo her yerde aynı.** Küçük boylarda kullanılan sadeleştirilmiş logo kaldırıldı; uygulama içinde, Windows görev çubuğunda ve Linux menülerinde her zaman "PDF" etiketli logo görünür.

### Düzeltmeler

- **Telefonda sağ üstteki ⋮ menüsü ekranın ortasında açılıyordu.** Artık düğmenin altında, sağ kenara hizalı açılır.

## 0.1.0-beta.5 · 22 Kasım 2026

### Yenilikler

- **Hata bildir.** Ayarlar → Hakkında'da (ve Uygulama bilgileri'nde) yeni düğme. **E-posta** ya da **GitHub** seçilir; uygulama sürümü ve cihaz bilgileri hazır doldurulmuş bir bildirim açılır. E-posta için hesap gerekmez, ekran görüntüsü de eklenebilir. Uygulama bildirimi kendisi göndermez; e-posta uygulaman ya da tarayıcın açılır, ne gideceğine sen karar verirsin.
- **Gizlilik politikası.** Inken PDF hiçbir veri toplamaz ve internete bağlanmaz; ayarların, son belgelerin ve yedeklerin yalnızca cihazında kalır. Ayrıntı: [PRIVACY.md](https://github.com/okolyigit/inken-pdf/blob/main/PRIVACY.md).

### Düzeltmeler

- **Telefonda üst çubuktaki logo "PDF" etiketsiz görünüyordu.** Küçük boy ikonu seçme kararı artık ekrandaki gerçek boyuta göre veriliyor; telefon ve tablette tam ikon görünür.

## 0.1.0-beta.4 · 21 Kasım 2026

### Yenilikler

- **Yeni logo.** Uygulama ikonu yenilendi: sayfaya yazan kalem ve **PDF** etiketi. Masaüstü, görev çubuğu, Başlat menüsü ve Android ana ekranında yeni ikon görünür.
- **PDF dosya ikonu.** Inken varsayılan PDF uygulaması seçilirse PDF dosyaları Windows'ta Inken'in dosya ikonuyla görünür. Linux'ta ikon teması kendi PDF ikonunu getirmiyorsa bu ikon kullanılır.

### Düzeltmeler

- **Windows'ta yazdırma çalışmıyordu** ("Varsayılan PDF uygulaması yazdıramadı"). Yazdırma artık başka bir PDF uygulamasına bırakılmıyor: Windows'un yazdırma penceresi açılır (yazıcı, kopya sayısı, sayfa aralığı), sayfalar doğrudan yazıcıya gider. Yatay sayfalar dikey kâğıda döndürülerek sığdırılır.

## 0.1.0-beta.3 · 21 Kasım 2026

### Neler var

#### Çizim

- **Kalem** (basınca duyarlı), **fosforlu**, **geçici kalem** (bir süre sonra kendiliğinden silinir), **silgi** (bütün çizgi ya da parça).
- **Şekiller:** çizgi, ok, dikdörtgen, elips, koordinat düzlemi.
- **Metin** ve **panodan görsel yapıştırma** (Ctrl+V).
- **Seçme:** taşı, boyutlandır, rengini değiştir, kopyala / yapıştır, başka sayfaya taşı.
- Geri al / yinele.

#### Ders sırasında

- **Ölçme araçları:** cetvel, gönye, iletki ve pergel. Gerçek boyutludur; kenarı boyunca kalemle düz çizgi ve yay çizilir.
- **Tam ekran**, **spot ışığı** ve **perde** (S / C).
- **Gece modu:** sayfa koyu zeminde açık renk yazıyla görünür. Yalnızca ekranı değiştirir; kaydedilen dosya aynı kalır.
- **Araç kutusu** ekranın dört kenarından birine sürüklenip bırakılır.
- **Akıllı tahta:** arayüz boyutu (%125 / %150), parmak ve kalem ayrımı.

#### Sayfalar

- **Sayfa paneli:** küçük resimler; sayfa ekleme, döndürme, silme; birden çok sayfayı birlikte döndürme ve silme.
- **Sayfa ekleme:** boş, kareli, noktalı, çizgili, koordinat düzlemli; dikey ya da yatay; beyaz, siyah ya da saman kâğıdı.
- **Sayfa döndürme** (Ctrl+R sağa, Ctrl+Shift+R sola).
- **İçindekiler:** yan panelde belgenin başlıkları.

#### Okuma

- **Metinde arama** (Ctrl+F): Türkçe I / ı / İ / i ayrımı yapmadan.
- **Metin seçip kopyalama.**
- **Bağlantılar:** belge içi bağlantı o sayfaya gider; web adresi açılmadan önce sorulur.
- **Sığdırma:** sayfaya sığdır (Ctrl+0), gerçek boyut (Ctrl+1), genişliğe sığdır (Ctrl+2).
- **Parolalı PDF açma** ve **belge özellikleri** (Ctrl+D).

#### Dosya

- Kayıt PDF'in içinde; **otomatik yedek**.
- **Çizimleri gömülü dışa aktarma**, **yazdırma** ve **paylaşma**.
- **Dosya → Yeni** (Ctrl+N), PDF'i pencereye sürükleyip bırakarak açma.
- **Türkçe ve İngilizce** arayüz.
- **Inken PDF'i paylaş** (Yardım menüsü): tanıtım metni ve GitHub bağlantısı; Android'de paylaşma sayfası, masaüstünde panoya kopyalanır.

## 0.1.0-beta.2 · 12 Kasım 2026

### Yenilikler

- **Araç imleçleri:** her araç kendi imlecini gösteriyor. Önceden hepsi artı (+) işaretiydi.
  - Kalem: kalem ikonu; ucu çizginin çıkacağı noktada, uçta seçili renk ve kalınlıkta küçük bir nokta.
  - Fosforlu: fosforlu ikonu ve izin gerçek genişliği.
  - Silgi: kapladığı alanı gösteren halka.
  - Geçici kalem: renginde parlayan bir nokta.
  - Şekil aracında artı imleç kaldı; köşeleri tam yerine koymak için.

## 0.1.0-beta.1 · 12 Kasım 2026

### Neler var

- **Kalem ve fosforlu:** renk, kalınlık ve kendi seçtiğin renkler. Basınç algılayan kalemde çizgi bastıkça kalınlaşır.
- **Şekil:** çizgi, ok, dikdörtgen, elips. Shift ile kare ve daire çizilir.
- **Metin:** sayfaya dokun ve yaz. Türkçe harfler ve matematik işaretleri (√ π ≤ ∞) eksiksiz.
- **Silgi:** dokunduğun çizginin tamamını ya da yalnızca üzerinden geçtiğin kısmı siler.
- **Geçici kalem:** göstererek anlatmak için; yazdığın birkaç saniyede kaybolur.
- **Seç, taşı, büyüt:** tek tek ya da dikdörtgen çizerek seç.
- **Sayfalar:** araya boş, kareli, noktalı, çizgili ya da koordinat düzlemli sayfa ekle; sayfa sil.
- **Kaydet:** çizimler PDF'in içine kaydedilir ve her PDF okuyucuda görünür. Orijinal dosyanın üzerine yazılmaz; ilk kayıtta `ad_inken.pdf` oluşur.
- **Dışa aktar ve yazdır:** çizimler sayfaya gömülü bir kopya oluşturur.
- **Ders sırasında:** tam ekran (F11), sayfa kaydırma çubuğu, otomatik yedek (uygulama kapanırsa çizimler kurtarılır).
- **Ayarlar ve kısayollar:** Düzen → Ayarlar (Ctrl+,). Tüm kısayolların listesi Kısayollar sekmesinde.
