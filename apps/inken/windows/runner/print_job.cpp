#include "print_job.h"

#include <winspool.h>

#include <algorithm>
#include <iterator>
#include <utility>

PrintJob::~PrintJob() { Abort(); }

std::vector<PrintJob::Printer> PrintJob::ListPrinters() {
  std::vector<Printer> printers;
  DWORD needed = 0, count = 0;
  const DWORD flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
  EnumPrintersW(flags, nullptr, 4, nullptr, 0, &needed, &count);
  if (needed == 0) return printers;
  std::vector<BYTE> buffer(needed);
  if (!EnumPrintersW(flags, nullptr, 4, buffer.data(), needed, &needed,
                     &count)) {
    return printers;
  }
  wchar_t default_name[512] = {};
  DWORD default_size = static_cast<DWORD>(std::size(default_name));
  const bool has_default =
      GetDefaultPrinterW(default_name, &default_size) != FALSE;
  const auto* info = reinterpret_cast<const PRINTER_INFO_4W*>(buffer.data());
  for (DWORD i = 0; i < count; i++) {
    if (info[i].pPrinterName == nullptr) continue;
    Printer p;
    p.name = info[i].pPrinterName;
    p.is_default = has_default && p.name == default_name;
    printers.push_back(std::move(p));
  }
  return printers;
}

std::vector<BYTE> PrintJob::DevMode(HANDLE handle,
                                    const std::wstring& printer) {
  auto saved = devmodes_.find(printer);
  if (saved != devmodes_.end()) return saved->second;
  auto* name = const_cast<LPWSTR>(printer.c_str());
  const LONG size = DocumentPropertiesW(nullptr, handle, name, nullptr,
                                        nullptr, 0);
  if (size <= 0) return {};
  std::vector<BYTE> buffer(static_cast<size_t>(size));
  if (DocumentPropertiesW(nullptr, handle, name,
                          reinterpret_cast<DEVMODEW*>(buffer.data()), nullptr,
                          DM_OUT_BUFFER) != IDOK) {
    return {};
  }
  return buffer;
}

bool PrintJob::ShowProperties(HWND owner, const std::wstring& printer) {
  HANDLE handle = nullptr;
  if (!OpenPrinterW(const_cast<LPWSTR>(printer.c_str()), &handle, nullptr)) {
    return false;
  }
  bool ok = false;
  std::vector<BYTE> in = DevMode(handle, printer);
  auto* name = const_cast<LPWSTR>(printer.c_str());
  const LONG size = DocumentPropertiesW(owner, handle, name, nullptr, nullptr,
                                        0);
  if (!in.empty() && size > 0) {
    std::vector<BYTE> out(static_cast<size_t>(size));
    const LONG r = DocumentPropertiesW(
        owner, handle, name, reinterpret_cast<DEVMODEW*>(out.data()),
        reinterpret_cast<DEVMODEW*>(in.data()),
        DM_IN_BUFFER | DM_OUT_BUFFER | DM_IN_PROMPT);
    if (r == IDOK) {
      devmodes_[printer] = std::move(out);
      ok = true;
    }
  }
  ClosePrinter(handle);
  return ok;
}

bool PrintJob::Begin(const std::wstring& title, const Settings& settings,
                     Started* out) {
  Abort();  // yarım kalmış iş varsa
  HANDLE handle = nullptr;
  auto* name = const_cast<LPWSTR>(settings.printer.c_str());
  if (!OpenPrinterW(name, &handle, nullptr)) return false;
  std::vector<BYTE> buffer = DevMode(handle, settings.printer);
  DEVMODEW* dm = buffer.empty() ? nullptr
                                : reinterpret_cast<DEVMODEW*>(buffer.data());
  if (dm != nullptr) {
    dm->dmFields |= DM_ORIENTATION | DM_PAPERSIZE | DM_COLOR | DM_DUPLEX |
                    DM_COPIES | DM_COLLATE;
    dm->dmFields &= ~static_cast<DWORD>(DM_PAPERLENGTH | DM_PAPERWIDTH);
    dm->dmOrientation = static_cast<short>(
        settings.landscape ? DMORIENT_LANDSCAPE : DMORIENT_PORTRAIT);
    dm->dmPaperSize = settings.paper;
    dm->dmColor = static_cast<short>(settings.color ? DMCOLOR_COLOR
                                                    : DMCOLOR_MONOCHROME);
    // Dikey kâğıtta uzun kenar DMDUP_VERTICAL'dır; yatayda tersi.
    short duplex = DMDUP_SIMPLEX;
    if (settings.duplex == 1) {
      duplex = settings.landscape ? DMDUP_HORIZONTAL : DMDUP_VERTICAL;
    } else if (settings.duplex == 2) {
      duplex = settings.landscape ? DMDUP_VERTICAL : DMDUP_HORIZONTAL;
    }
    dm->dmDuplex = duplex;
    // Kopyalar ve sıra Dart'ta: sayfalar istenen sırayla gelir.
    dm->dmCopies = 1;
    dm->dmCollate = DMCOLLATE_FALSE;
    // Sürücü ayarları birleştirsin ve doğrulasın.
    DocumentPropertiesW(nullptr, handle, name, dm, dm,
                        DM_IN_BUFFER | DM_OUT_BUFFER);
  }
  ClosePrinter(handle);

  HDC dc = CreateDCW(L"WINSPOOL", settings.printer.c_str(), nullptr, dm);
  if (dc == nullptr) return false;
  DOCINFOW doc = {};
  doc.cbSize = sizeof(doc);
  doc.lpszDocName = title.c_str();
  if (StartDocW(dc, &doc) <= 0) {
    DeleteDC(dc);
    return false;
  }
  dc_ = dc;
  out->width = GetDeviceCaps(dc_, HORZRES);
  out->height = GetDeviceCaps(dc_, VERTRES);
  out->physical_width = GetDeviceCaps(dc_, PHYSICALWIDTH);
  out->physical_height = GetDeviceCaps(dc_, PHYSICALHEIGHT);
  out->offset_x = GetDeviceCaps(dc_, PHYSICALOFFSETX);
  out->offset_y = GetDeviceCaps(dc_, PHYSICALOFFSETY);
  out->dpi = std::max(GetDeviceCaps(dc_, LOGPIXELSX),
                      GetDeviceCaps(dc_, LOGPIXELSY));
  return true;
}

bool PrintJob::AddPage(const uint8_t* bgra, size_t size, int width,
                       int height, int x, int y, int dest_w, int dest_h) {
  if (dc_ == nullptr || width <= 0 || height <= 0 || dest_w <= 0 ||
      dest_h <= 0 ||
      size < static_cast<size_t>(width) * static_cast<size_t>(height) * 4) {
    return false;
  }
  if (StartPage(dc_) <= 0) return false;

  BITMAPINFO info = {};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = width;
  info.bmiHeader.biHeight = -height;  // üstten aşağı
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;

  SetStretchBltMode(dc_, HALFTONE);
  SetBrushOrgEx(dc_, 0, 0, nullptr);
  const int lines = StretchDIBits(dc_, x, y, dest_w, dest_h, 0, 0, width,
                                  height, bgra, &info, DIB_RGB_COLORS, SRCCOPY);
  const bool ok = lines != 0 && lines != GDI_ERROR;
  return EndPage(dc_) > 0 && ok;
}

bool PrintJob::End() {
  if (dc_ == nullptr) return false;
  const bool ok = EndDoc(dc_) > 0;
  DeleteDC(dc_);
  dc_ = nullptr;
  return ok;
}

void PrintJob::Abort() {
  if (dc_ == nullptr) return;
  AbortDoc(dc_);
  DeleteDC(dc_);
  dc_ = nullptr;
}
