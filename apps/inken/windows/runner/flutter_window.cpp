#include "flutter_window.h"

#include <vector>

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Panodaki görsel. Önce tarayıcıların ve Ekran Alıntısı Aracı'nın koyduğu
// "PNG" biçimi (saydamlık korunur); yoksa CF_DIB, başına BMP dosya başlığı
// eklenerek (Flutter BMP'yi çözer). Görsel yoksa boş.
std::vector<uint8_t> ReadClipboardImage(HWND owner) {
  std::vector<uint8_t> out;
  if (!OpenClipboard(owner)) return out;
  static const UINT png_format = RegisterClipboardFormatW(L"PNG");
  if (HANDLE h = GetClipboardData(png_format)) {
    if (const auto* data = static_cast<const uint8_t*>(GlobalLock(h))) {
      out.assign(data, data + GlobalSize(h));
      GlobalUnlock(h);
    }
  } else if (HANDLE dib = GetClipboardData(CF_DIB)) {
    if (const auto* data = static_cast<const uint8_t*>(GlobalLock(dib))) {
      const SIZE_T size = GlobalSize(dib);
      const auto* info = reinterpret_cast<const BITMAPINFOHEADER*>(data);
      if (size >= sizeof(BITMAPINFOHEADER) && info->biSize <= size) {
        DWORD colors = info->biClrUsed;
        if (colors == 0 && info->biBitCount <= 8) colors = 1u << info->biBitCount;
        DWORD masks = (info->biSize == sizeof(BITMAPINFOHEADER) &&
                       info->biCompression == BI_BITFIELDS)
                          ? 3 * sizeof(DWORD)
                          : 0;
        BITMAPFILEHEADER file{};
        file.bfType = 0x4D42;  // "BM"
        file.bfSize = static_cast<DWORD>(sizeof(file) + size);
        file.bfOffBits = static_cast<DWORD>(sizeof(file) + info->biSize +
                                            masks + colors * sizeof(RGBQUAD));
        const auto* head = reinterpret_cast<const uint8_t*>(&file);
        out.assign(head, head + sizeof(file));
        out.insert(out.end(), data, data + size);
      }
      GlobalUnlock(dib);
    }
  }
  CloseClipboard();
  return out;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "inken/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setFullscreen") {
          const auto* on = std::get_if<bool>(call.arguments());
          if (on != nullptr) SetFullscreen(*on);
          result->Success();
          return;
        }
        if (call.method_name() != "setTitle") {
          result->NotImplemented();
          return;
        }
        const auto* title = std::get_if<std::string>(call.arguments());
        if (title != nullptr) {
          int length = MultiByteToWideChar(CP_UTF8, 0, title->c_str(), -1,
                                           nullptr, 0);
          std::wstring wide(length, L'\0');
          MultiByteToWideChar(CP_UTF8, 0, title->c_str(), -1, wide.data(),
                              length);
          SetWindowTextW(GetHandle(), wide.c_str());
        }
        result->Success();
      });

  print_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "inken/print",
          &flutter::StandardMethodCodec::GetInstance());
  print_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "print") {
          result->NotImplemented();
          return;
        }
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        const std::string* path = nullptr;
        if (args != nullptr) {
          auto it = args->find(flutter::EncodableValue("path"));
          if (it != args->end()) path = std::get_if<std::string>(&it->second);
        }
        if (path == nullptr) {
          result->Error("bad_args", "path gerekli");
          return;
        }
        int length =
            MultiByteToWideChar(CP_UTF8, 0, path->c_str(), -1, nullptr, 0);
        std::wstring wide(length, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, path->c_str(), -1, wide.data(),
                            length);
        // Windows'ta yerleşik PDF yazdırma yok: dosya varsayılan PDF
        // uygulamasının "yazdır" komutuna verilir (yazdırma penceresi o
        // uygulamanınkidir). 32'den büyük dönüş başarıdır.
        HINSTANCE r = ShellExecuteW(GetHandle(), L"print", wide.c_str(),
                                    nullptr, nullptr, SW_SHOWNORMAL);
        if (reinterpret_cast<INT_PTR>(r) > 32) {
          result->Success(flutter::EncodableValue("handedOff"));
        } else {
          result->Error("print_failed",
                        "Varsayılan PDF uygulaması yazdıramadı");
        }
      });
  clipboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "inken/clipboard",
          &flutter::StandardMethodCodec::GetInstance());
  clipboard_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "readImage") {
          result->NotImplemented();
          return;
        }
        std::vector<uint8_t> bytes = ReadClipboardImage(GetHandle());
        if (bytes.empty()) {
          result->Success();
        } else {
          result->Success(flutter::EncodableValue(std::move(bytes)));
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::SetFullscreen(bool on) {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr || on == fullscreen_) return;
  if (on) {
    saved_style_ = GetWindowLong(hwnd, GWL_STYLE);
    GetWindowRect(hwnd, &saved_rect_);
    MONITORINFO info{sizeof(info)};
    GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &info);
    SetWindowLong(hwnd, GWL_STYLE, saved_style_ & ~WS_OVERLAPPEDWINDOW);
    SetWindowPos(hwnd, HWND_TOP, info.rcMonitor.left, info.rcMonitor.top,
                 info.rcMonitor.right - info.rcMonitor.left,
                 info.rcMonitor.bottom - info.rcMonitor.top,
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  } else {
    SetWindowLong(hwnd, GWL_STYLE, saved_style_);
    SetWindowPos(hwnd, nullptr, saved_rect_.left, saved_rect_.top,
                 saved_rect_.right - saved_rect_.left,
                 saved_rect_.bottom - saved_rect_.top,
                 SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  }
  fullscreen_ = on;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
