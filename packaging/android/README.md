# Android paketi

CI (`.github/workflows/packages.yml`, `android` işi) `flutter build apk --release --split-per-abi` ile iki APK üretir:

- `InkenPDF-<sürüm>-arm64.apk` — son yıllarda çıkmış tabletlerin neredeyse hepsi.
- `InkenPDF-<sürüm>-armv7.apk` — eski / 32 bit cihazlar.

## İmza

Android, bir uygulamanın güncellemesini ancak **aynı anahtarla** imzalanmışsa önceki kurulumun üzerine kurar. Anahtar değişirse kullanıcı önce uygulamayı kaldırmalıdır; bu sırada uygulamanın ayarları ve otomatik yedekleri silinir (kaydedilen PDF'ler etkilenmez).

`apps/inken/android/app/build.gradle.kts` imzayı ortam değişkenlerinden alır:

| Değişken | Anlamı |
|---|---|
| `INKEN_KEYSTORE` | Anahtar deposu dosyasının yolu (`.jks`) |
| `INKEN_KEYSTORE_PASSWORD` | Deponun parolası |
| `INKEN_KEY_ALIAS` | Anahtarın adı |
| `INKEN_KEY_PASSWORD` | Anahtarın parolası |

Bunlar yoksa APK hata ayıklama anahtarıyla imzalanır (yerel deneme için yeterli; CI'da her çalıştırmada farklı olduğundan sürümler birbirinin üzerine kurulmaz).

### Kalıcı anahtar kurmak (bir kez)

```sh
keytool -genkeypair -v -keystore inken-release.jks -keyalg RSA -keysize 4096 \
  -validity 10000 -alias inken
base64 -w0 inken-release.jks > inken-release.jks.b64
```

GitHub → depo → Settings → Secrets and variables → Actions'a ekleyin:

- `ANDROID_KEYSTORE_BASE64` — `inken-release.jks.b64`'ün içeriği
- `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`inken`), `ANDROID_KEY_PASSWORD`

**Kuruldu (13 Kasım 2026):** anahtar ve parolalar geliştiricinin makinesinde `~/.local/share/inken-pdf-imza/` (`inken-release.jks`, `imza.env`), GitHub gizli değerleri eklendi. Sertifika SHA-256: `42:45:D6:80:E9:B1:71:F6:BC:1F:E1:42:12:FD:E0:7C:5A:6D:5D:C6:45:88:27:6F:84:7F:33:1A:4C:5E:DE:E7`. Yerelde imzalı derleme:

```sh
. ~/.local/share/inken-pdf-imza/imza.env
cd apps/inken && flutter build apk --release --split-per-abi
```

`inken-release.jks` dosyasını ve parolaları güvenli bir yerde saklayın, depoya koymayın. Kaybolursa yayımlanmış uygulama bir daha aynı kimlikle güncellenemez.

Google Play'e çıkarken Play App Signing kullanılır; yukarıdaki anahtar "yükleme anahtarı" olur. Uygulama kimliği (`com.inkenpdf.app`) yayından sonra değiştirilemez.
