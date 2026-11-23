#include "flutter_window.h"

#include <cstring>
#include <variant>
#include <vector>

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include "print_job.h"
#include "utils.h"

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

// [bytes]'ı taşınabilir bir bellek bloğuna kopyalar (pano için).
HGLOBAL CopyToGlobal(const uint8_t* bytes, size_t size) {
  HGLOBAL h = GlobalAlloc(GMEM_MOVEABLE, size);
  if (h == nullptr) return nullptr;
  if (void* dst = GlobalLock(h)) {
    memcpy(dst, bytes, size);
    GlobalUnlock(h);
    return h;
  }
  GlobalFree(h);
  return nullptr;
}

// Görseli panoya koyar: "PNG" biçimi (tarayıcılar, Office, Paint.NET) ve
// CF_DIB (her uygulama). [bgra] üstten aşağı satırlardır; DIB alttan üste
// yazılır. Başarılıysa true.
bool WriteClipboardImage(HWND owner, const std::vector<uint8_t>& png,
                         const std::vector<uint8_t>& bgra, int32_t width,
                         int32_t height) {
  const size_t row = static_cast<size_t>(width) * 4;
  if (width <= 0 || height <= 0 || bgra.size() != row * height) return false;
  BITMAPINFOHEADER info{};
  info.biSize = sizeof(info);
  info.biWidth = width;
  info.biHeight = height;  // alttan üste
  info.biPlanes = 1;
  info.biBitCount = 32;
  info.biCompression = BI_RGB;
  info.biSizeImage = static_cast<DWORD>(row * height);
  std::vector<uint8_t> dib(sizeof(info) + row * height);
  memcpy(dib.data(), &info, sizeof(info));
  for (int32_t y = 0; y < height; y++) {
    memcpy(dib.data() + sizeof(info) + row * (height - 1 - y),
           bgra.data() + row * y, row);
  }
  if (!OpenClipboard(owner)) return false;
  EmptyClipboard();
  bool ok = false;
  static const UINT png_format = RegisterClipboardFormatW(L"PNG");
  if (!png.empty()) {
    if (HGLOBAL h = CopyToGlobal(png.data(), png.size())) {
      if (SetClipboardData(png_format, h) == nullptr) GlobalFree(h);
    }
  }
  if (HGLOBAL h = CopyToGlobal(dib.data(), dib.size())) {
    if (SetClipboardData(CF_DIB, h) == nullptr) {
      GlobalFree(h);
    } else {
      ok = true;
    }
  }
  CloseClipboard();
  return ok;
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
        auto string_arg = [&arg](const char* key) -> const std::string* {
          const auto* v = arg(key);
          return v == nullptr ? nullptr : std::get_if<std::string>(v);
        };
        auto bool_arg = [&arg](const char* key, bool fallback) {
          const auto* v = arg(key);
          const bool* b = v == nullptr ? nullptr : std::get_if<bool>(v);
          return b == nullptr ? fallback : *b;
        };
        const std::string& method = call.method_name();
        if (method == "printers") {
          flutter::EncodableList list;
          for (const auto& p : PrintJob::ListPrinters()) {
            list.emplace_back(flutter::EncodableMap{
                {flutter::EncodableValue("name"),
                 flutter::EncodableValue(Utf8FromUtf16(p.name.c_str()))},
                {flutter::EncodableValue("default"),
                 flutter::EncodableValue(p.is_default)},
            });
          }
          result->Success(flutter::EncodableValue(list));
        } else if (method == "properties") {
          const auto* printer = string_arg("printer");
          if (printer == nullptr) {
            result->Error("bad_args", "printer gerekli");
            return;
          }
          result->Success(flutter::EncodableValue(
              print_job_.ShowProperties(GetHandle(), Utf8ToWide(*printer))));
        } else if (method == "begin") {
          const auto* title = string_arg("title");
          const auto* printer = string_arg("printer");
          if (title == nullptr || printer == nullptr) {
            result->Error("bad_args", "title ve printer gerekli");
            return;
          }
          PrintJob::Settings settings;
          settings.printer = Utf8ToWide(*printer);
          settings.color = bool_arg("color", true);
          if (const auto* d = string_arg("duplex")) {
            settings.duplex = *d == "longEdge" ? 1 : *d == "shortEdge" ? 2 : 0;
          }
          if (const auto* paper = string_arg("paper")) {
            settings.paper = *paper == "a3"       ? DMPAPER_A3
                             : *paper == "a5"     ? DMPAPER_A5
                             : *paper == "letter" ? DMPAPER_LETTER
                             : *paper == "legal"  ? DMPAPER_LEGAL
                                                  : DMPAPER_A4;
          }
          if (const auto* o = string_arg("orientation")) {
            settings.landscape = *o == "landscape";
          }
          PrintJob::Started job;
          if (!print_job_.Begin(Utf8ToWide(*title), settings, &job)) {
            result->Error("print_failed", "Yazdırma başlatılamadı");
            return;
          }
          auto v = [](int32_t n) { return flutter::EncodableValue(n); };
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("width"), v(job.width)},
              {flutter::EncodableValue("height"), v(job.height)},
              {flutter::EncodableValue("physicalWidth"), v(job.physical_width)},
              {flutter::EncodableValue("physicalHeight"),
               v(job.physical_height)},
              {flutter::EncodableValue("offsetX"), v(job.offset_x)},
              {flutter::EncodableValue("offsetY"), v(job.offset_y)},
              {flutter::EncodableValue("dpi"), v(job.dpi)},
          }));
        } else if (method == "page") {
          const auto* bytes_value = arg("bgra");
          const auto* bytes =
              bytes_value == nullptr
                  ? nullptr
                  : std::get_if<std::vector<uint8_t>>(bytes_value);
          const auto width = int_arg("width");
          const auto height = int_arg("height");
          const auto x = int_arg("x");
          const auto y = int_arg("y");
          const auto dest_w = int_arg("destWidth");
          const auto dest_h = int_arg("destHeight");
          if (bytes == nullptr || !width || !height || !x || !y || !dest_w ||
              !dest_h) {
            result->Error("bad_args", "bgra, boyut ve hedef gerekli");
            return;
          }
          if (print_job_.AddPage(bytes->data(), bytes->size(),
                                 static_cast<int>(*width),
                                 static_cast<int>(*height),
                                 static_cast<int>(*x), static_cast<int>(*y),
                                 static_cast<int>(*dest_w),
                                 static_cast<int>(*dest_h))) {
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
        if (call.method_name() == "writeImage") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          auto get = [&](const char* key) -> const flutter::EncodableValue* {
            if (args == nullptr) return nullptr;
            auto it = args->find(flutter::EncodableValue(key));
            return it == args->end() ? nullptr : &it->second;
          };
          const auto* png = get("png");
          const auto* bgra = get("bgra");
          const auto* width = get("width");
          const auto* height = get("height");
          if (png == nullptr || bgra == nullptr || width == nullptr ||
              height == nullptr ||
              !std::holds_alternative<std::vector<uint8_t>>(*png) ||
              !std::holds_alternative<std::vector<uint8_t>>(*bgra) ||
              !std::holds_alternative<int32_t>(*width) ||
              !std::holds_alternative<int32_t>(*height)) {
            result->Error("bad_args", "png, bgra, width, height gerekli");
            return;
          }
          const bool ok = WriteClipboardImage(
              GetHandle(), std::get<std::vector<uint8_t>>(*png),
              std::get<std::vector<uint8_t>>(*bgra), std::get<int32_t>(*width),
              std::get<int32_t>(*height));
          if (ok) {
            result->Success(flutter::EncodableValue(true));
          } else {
            result->Error("clipboard_failed", "Pano yazılamadı");
          }
          return;
        }
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
