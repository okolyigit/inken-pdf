#ifndef RUNNER_PRINT_JOB_H_
#define RUNNER_PRINT_JOB_H_

#include <windows.h>

#include <cstdint>
#include <map>
#include <string>
#include <vector>

// Windows'ta yazdırma: yazıcı ve ayarlar Inken'in penceresinde seçilir;
// sistemin yazdırma penceresi açılmaz. Sayfaları Dart tarafı PDFium ile
// görüntüye çevirir, burada GDI ile yazıcıya gönderilir. Varsayılan PDF
// uygulamasına bağlı değildir (Edge'in "yazdır" komutu yoktur).
class PrintJob {
 public:
  ~PrintJob();

  struct Printer {
    std::wstring name;
    bool is_default = false;
  };

  // Yerel ve ağ (bağlantı) yazıcıları.
  static std::vector<Printer> ListPrinters();

  // Yazıcının kendi ayar penceresi (sürücü). Tamam'a basılırsa seçilenler
  // bu oturumda o yazıcının sonraki işlerinde kullanılır.
  bool ShowProperties(HWND owner, const std::wstring& printer);

  struct Settings {
    std::wstring printer;
    bool color = true;
    // 0: tek taraflı, 1: uzun kenardan, 2: kısa kenardan çevir.
    int duplex = 0;
    // DMPAPER_* (A4, A3, A5, Letter, Legal).
    short paper = DMPAPER_A4;
    // Kâğıt yatay mı? (Otomatikte dikey; sayfa Dart'ta döndürülür.)
    bool landscape = false;
  };

  struct Started {
    // Yazdırılabilir alan ve kâğıdın tamamı (aygıt pikseli), alanın
    // kâğıttaki yeri ve çözünürlük (dpi).
    int32_t width = 0;
    int32_t height = 0;
    int32_t physical_width = 0;
    int32_t physical_height = 0;
    int32_t offset_x = 0;
    int32_t offset_y = 0;
    int32_t dpi = 0;
  };

  // Belgeyi başlatır (pencere açılmaz).
  bool Begin(const std::wstring& title, const Settings& settings,
             Started* out);

  // Bir sayfa: BGRA8888, üstten aşağı satırlar; yazdırılabilir alanın sol
  // üstüne göre (x, y) konumuna dest_w × dest_h boyutunda çizilir (taşan
  // kısım kesilir).
  bool AddPage(const uint8_t* bgra, size_t size, int width, int height, int x,
               int y, int dest_w, int dest_h);

  bool End();
  void Abort();
  bool active() const { return dc_ != nullptr; }

 private:
  // Yazıcının ayarları: sürücü penceresinde seçilen, yoksa varsayılan.
  std::vector<BYTE> DevMode(HANDLE handle, const std::wstring& printer);

  HDC dc_ = nullptr;
  std::map<std::wstring, std::vector<BYTE>> devmodes_;
};

#endif  // RUNNER_PRINT_JOB_H_
