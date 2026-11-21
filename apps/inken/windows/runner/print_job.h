#ifndef RUNNER_PRINT_JOB_H_
#define RUNNER_PRINT_JOB_H_

#include <windows.h>

#include <cstdint>
#include <string>
#include <vector>

// Windows'ta yazdırma: sistemin yazdırma penceresi (yazıcı, kopya, sayfa
// aralığı) ve GDI ile sayfa görüntülerini yazıcıya gönderme. Sayfaları
// Dart tarafı PDFium ile görüntüye çevirir; varsayılan PDF uygulamasına
// bağlı değildir (Edge'in "yazdır" komutu yoktur).
class PrintJob {
 public:
  ~PrintJob();

  struct Started {
    // Gönderilecek sayfalar (0'dan), sırasıyla; sürücü kopyaları kendisi
    // basamıyorsa kopyalar listede tekrarlanır.
    std::vector<int32_t> pages;
    // Yazdırılabilir alan (piksel) ve yazıcı çözünürlüğü (dpi).
    int32_t width = 0;
    int32_t height = 0;
    int32_t dpi = 0;
  };

  enum class BeginResult { kStarted, kCancelled, kFailed };

  // Yazdırma penceresini açar; onaylanırsa belgeyi başlatır.
  BeginResult Begin(HWND owner, const std::wstring& title, int page_count,
                    Started* out);

  // Bir sayfa: BGRA8888, üstten aşağı satırlar. Yazdırılabilir alana oranı
  // korunarak ortalanır.
  bool AddPage(const uint8_t* bgra, size_t size, int width, int height);

  bool End();
  void Abort();
  bool active() const { return dc_ != nullptr; }

 private:
  HDC dc_ = nullptr;
};

#endif  // RUNNER_PRINT_JOB_H_
