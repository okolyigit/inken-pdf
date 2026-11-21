#include "flutter_window.h"

#include <vector>

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include "print_job.h"

namespace {

// UTF-8 → UTF-16 (sondaki boş karakter olmadan).
std::wstring Utf8ToWide(const std::string& text) {
  if (text.empty()) return std::wstring();
  const int length = MultiByteToWideChar(
      CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring wide(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      wide.data(), length);
  return wide;
}

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
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        auto arg = [args](const char* key) -> const flutter::EncodableValue* {
          if (args == nullptr) return nullptr;
          auto it = args->find(flutter::EncodableValue(key));
          return it == args->end() ? nullptr : &it->second;
        };
        auto int_arg = [&arg](const char* key) -> std::optional<int64_t> {
          const auto* v = arg(key);
          if (v == nullptr) return std::nullopt;
          if (const auto* i = std::get_if<int32_t>(v)) return *i;
          if (const auto* l = std::get_if<int64_t>(v)) return *l;
          return std::nullopt;
        };
        const std::string& method = call.method_name();
        if (method == "begin") {
          const auto* title_value = arg("title");
          const auto* title = title_value == nullptr
                                  ? nullptr
                                  : std::get_if<std::string>(title_value);
          const auto count = int_arg("pageCount");
          if (title == nullptr || !count || *count < 1) {
            result->Error("bad_args", "title ve pageCount gerekli");
            return;
          }
          PrintJob::Started job;
          switch (print_job_.Begin(GetHandle(), Utf8ToWide(*title),
                                   static_cast<int>(*count), &job)) {
            case PrintJob::BeginResult::kCancelled:
              result->Success();
              return;
            case PrintJob::BeginResult::kFailed:
              result->Error("print_failed", "Yazdırma başlatılamadı");
              return;
            case PrintJob::BeginResult::kStarted:
              break;
          }
          flutter::EncodableList pages;
          for (int32_t p : job.pages) pages.emplace_back(p);
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("pages"), flutter::EncodableValue(pages)},
              {flutter::EncodableValue("width"),
               flutter::EncodableValue(job.width)},
              {flutter::EncodableValue("height"),
               flutter::EncodableValue(job.height)},
              {flutter::EncodableValue("dpi"), flutter::EncodableValue(job.dpi)},
          }));
        } else if (method == "page") {
          const auto* bytes_value = arg("bgra");
          const auto* bytes =
              bytes_value == nullptr
                  ? nullptr
                  : std::get_if<std::vector<uint8_t>>(bytes_value);
          const auto width = int_arg("width");
          const auto height = int_arg("height");
          if (bytes == nullptr || !width || !height) {
            result->Error("bad_args", "bgra, width ve height gerekli");
            return;
          }
          if (print_job_.AddPage(bytes->data(), bytes->size(),
                                 static_cast<int>(*width),
                                 static_cast<int>(*height))) {
            result->Success();
          } else {
            print_job_.Abort();
            result->Error("print_failed", "Sayfa yazıcıya gönderilemedi");
          }
        } else if (method == "end") {
          if (print_job_.End()) {
            result->Success();
          } else {
            result->Error("print_failed", "Yazdırma tamamlanamadı");
          }
        } else if (method == "abort") {
          print_job_.Abort();
          result->Success();
        } else {
          result->NotImplemented();
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
