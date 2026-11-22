# Windows paketleri

CI (`.github/workflows/packages.yml`, `windows` işi) dört dosya üretir:

| Dosya | Nereye | Ne için |
|---|---|---|
| `InkenPDF-Kurulum-<sürüm>.exe` | GitHub sürümü | Inno Setup kurulumu (`inken-pdf.iss`) |
| `InkenPDF-tasinabilir-<sürüm>.zip` | GitHub sürümü | Kurulumsuz kopya |
| `InkenPDF-Store-<msix>.msix` | Actions → `msix` artifact | Microsoft Store'a yüklenecek paket (imzasız; Store imzalar) |
| `InkenPDF-Deneme-<msix>.msix` + `InkenPDF-Deneme-sertifika.cer` | Actions → `msix` artifact | Store paketiyle aynı kimlikte, geçici sertifikayla imzalı deneme paketi |

MSIX'ler GitHub sürümüne girmez: elle (Actions → Paketler → Run workflow → `windows`) ya da etiketle çalışınca iş akışının **Artifacts** bölümünden `msix` indirilir.

## MSIX sürümü

Store'da sürümün ilk parçası 0, son parçası 0'dan farklı olamaz. Eşleme: `(major+1).minor.build.0`; `pubspec.yaml`'da `0.1.0+3` → `1.1.3.0`. Derleme numarası (`+N`) her sürümde arttığı için MSIX sürümü de artar. Uygulama 1.0'a geçince ilk parça 2 olur; o zaman eşleme yeniden düşünülür (Store yalnızca büyüyen sürümü kabul eder).

## Kimlik

`apps/inken/pubspec.yaml` → `msix_config` (Partner Center → Inken PDF → Product management → Product identity):

- `identity_name`: `OckyApps.InkenPDF`
- `publisher`: `CN=A8A86781-E915-4EB2-B2F9-431C1294634F`
- `publisher_display_name`: `Ocky Apps`

PDF'ler için "Birlikte aç" kaydı manifestte (`file_extension: .pdf`); varsayılan uygulamayı değiştirmez.

## Deneme paketini Windows'ta kurmak

1. `msix` artifact'ini indir, aç.
2. `InkenPDF-Deneme-sertifika.cer` → çift tıkla → **Sertifika yükle** → **Yerel Makine** → "Tüm sertifikaları aşağıdaki depolama alanına yerleştir" → **Güvenilir Kişiler** (Trusted People) → Son. Yönetici izni ister.
   PowerShell (yönetici): `Import-Certificate -FilePath .\InkenPDF-Deneme-sertifika.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople`
3. `InkenPDF-Deneme-*.msix` → çift tıkla → **Yükle**.

Sertifika her CI çalıştırmasında yenidir: başka bir çalıştırmanın deneme paketini kurmadan önce onun `.cer`'ini de kur. Denemeden sonra sertifika `certlm.msc` → Güvenilir Kişiler'den silinebilir. Uygulamayı kaldırmak: Başlat menüsünde sağ tık → Kaldır.

Deneme paketi ile Inno kurulumu farklı kimliklerdir; aynı bilgisayarda yan yana durabilirler. Ayarlar ve yedekler ayrı tutulur (MSIX, AppData'yı pakete özel klasöre yönlendirir).

## Store'a göndermek

Partner Center → Inken PDF → **Start submission**:

- **Packages:** `InkenPDF-Store-<msix>.msix`. Aygıt ailesi: Windows 10/11 Desktop.
- **Pricing and availability:** ücretsiz; pazarlar: hepsi (ya da Türkiye ile başla).
- **Properties:** kategori **Productivity** (Verimlilik). Gizlilik politikası: uygulama kişisel veri toplamaz, ağa çıkmaz; Partner Center yine de isterse depodaki bir sayfanın adresi verilebilir.
- **Age ratings:** IARC anketi; içerik yok, kullanıcılar arası iletişim yok → "3+ / Herkes".
- **Submission options → Restricted capabilities:** `runFullTrust` için gerekçe:

  > Inken PDF is a desktop app built with Flutter (Win32). runFullTrust is required to run as a desktop app: it opens PDF files the user chooses, saves annotations back to the same file or a new file in the user's folders, and prints through the Windows print dialog.

- **Store listings** (Türkçe ve İngilizce): açıklama için `README.md`'nin giriş ve "Neler yapabilirsin" / "Features" bölümleri; ekran görüntüleri `docs/screenshots/` (en az 1366×768: `ders.png`, `olcme.png`, `sayfalar.png`, `spot.png`, `gece.png`, İngilizce için `lesson.png`).

Sertifikasyon genellikle birkaç gün sürer. Güncellemede yeni sürüm numaralı Store paketi aynı ürüne yeni gönderimle yüklenir.

## İkonlar

Uygulama ikonu (`app_icon.ico`) ve .pdf dosya ikonu (`pdf_file.ico`, `inken.exe` içinde kaynak kimliği 102) `packaging/icons/generate.sh` ile tasarım sisteminin SVG'lerinden üretilir. Inno kurulumu `InkenPDF.Document` ProgID'sini kaydeder; Inken varsayılan PDF uygulaması seçilince PDF'ler bu ikonla görünür. MSIX'te aynı ikon CI'da manifestin dosya ilişkisine (`<uap:Logo>`) eklenir.
