#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>

#include "print_job.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Dart'tan pencere başlığı: "inken/window" kanalı, "setTitle".
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;
  // Yazdırma: "inken/print" kanalı. "begin" {title, pageCount} yazdırma
  // penceresini açar → {pages, width, height, dpi} ya da null (vazgeçildi);
  // "page" {bgra, width, height} bir sayfa; "end" / "abort".
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      print_channel_;
  PrintJob print_job_;
  // Pano: "inken/clipboard" kanalı, "readImage" → görsel baytları (PNG ya da
  // BMP) ya da null.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      clipboard_channel_;

  // Tam ekran: girmeden önceki pencere biçemi ve konumu.
  void SetFullscreen(bool on);
  bool fullscreen_ = false;
  LONG saved_style_ = 0;
  RECT saved_rect_{};
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
