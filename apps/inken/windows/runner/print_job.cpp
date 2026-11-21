#include "print_job.h"

#include <commdlg.h>

#include <algorithm>
#include <cmath>
#include <iterator>
#include <utility>

PrintJob::~PrintJob() { Abort(); }

PrintJob::BeginResult PrintJob::Begin(HWND owner, const std::wstring& title,
                                      int page_count, Started* out) {
  Abort();  // yarım kalmış iş varsa
  if (page_count < 1) return BeginResult::kFailed;

  PRINTPAGERANGE ranges[32] = {};
  PRINTDLGEXW pd = {};
  pd.lStructSize = sizeof(pd);
  pd.hwndOwner = owner;
  // Kopya ve harmanlama sürücüde (DEVMODE); sürücü yapamıyorsa nCopies'te
  // döner ve sayfalar burada tekrarlanır.
  pd.Flags = PD_RETURNDC | PD_NOSELECTION | PD_NOCURRENTPAGE |
             PD_USEDEVMODECOPIESANDCOLLATE;
  pd.nPageRanges = 0;
  pd.nMaxPageRanges = static_cast<DWORD>(std::size(ranges));
  pd.lpPageRanges = ranges;
  pd.nMinPage = 1;
  pd.nMaxPage = static_cast<DWORD>(page_count);
  pd.nCopies = 1;
  pd.nStartPage = START_PAGE_GENERAL;

  const HRESULT hr = PrintDlgExW(&pd);
  if (pd.hDevMode) GlobalFree(pd.hDevMode);
  if (pd.hDevNames) GlobalFree(pd.hDevNames);
  if (FAILED(hr)) {
    if (pd.hDC) DeleteDC(pd.hDC);
    return BeginResult::kFailed;
  }
  if (pd.dwResultAction != PD_RESULT_PRINT || pd.hDC == nullptr) {
    if (pd.hDC) DeleteDC(pd.hDC);
    return BeginResult::kCancelled;
  }

  std::vector<int32_t> pages;
  if (pd.Flags & PD_PAGENUMS) {
    for (DWORD i = 0; i < pd.nPageRanges; i++) {
      DWORD from = ranges[i].nFromPage, to = ranges[i].nToPage;
      if (from > to) std::swap(from, to);  // "5-3" → 3..5
      from = std::max<DWORD>(1, from);
      to = std::min<DWORD>(static_cast<DWORD>(page_count), to);
      for (DWORD p = from; p <= to; p++) pages.push_back(p - 1);
    }
  } else {
    for (int p = 0; p < page_count; p++) pages.push_back(p);
  }
  if (pages.empty()) {
    DeleteDC(pd.hDC);
    return BeginResult::kCancelled;
  }

  const DWORD copies = std::max<DWORD>(1, pd.nCopies);
  std::vector<int32_t> sequence;
  if (copies > 1 && (pd.Flags & PD_COLLATE)) {
    for (DWORD c = 0; c < copies; c++) {
      sequence.insert(sequence.end(), pages.begin(), pages.end());
    }
  } else if (copies > 1) {
    for (int32_t p : pages) sequence.insert(sequence.end(), copies, p);
  } else {
    sequence = std::move(pages);
  }

  DOCINFOW doc = {};
  doc.cbSize = sizeof(doc);
  doc.lpszDocName = title.c_str();
  if (StartDocW(pd.hDC, &doc) <= 0) {
    DeleteDC(pd.hDC);
    return BeginResult::kFailed;
  }
  dc_ = pd.hDC;
  out->pages = std::move(sequence);
  out->width = GetDeviceCaps(dc_, HORZRES);
  out->height = GetDeviceCaps(dc_, VERTRES);
  out->dpi = std::max(GetDeviceCaps(dc_, LOGPIXELSX),
                      GetDeviceCaps(dc_, LOGPIXELSY));
  return BeginResult::kStarted;
}

bool PrintJob::AddPage(const uint8_t* bgra, size_t size, int width,
                       int height) {
  if (dc_ == nullptr || width <= 0 || height <= 0 ||
      size < static_cast<size_t>(width) * static_cast<size_t>(height) * 4) {
    return false;
  }
  if (StartPage(dc_) <= 0) return false;
  const int area_w = GetDeviceCaps(dc_, HORZRES);
  const int area_h = GetDeviceCaps(dc_, VERTRES);
  const double scale = std::min(static_cast<double>(area_w) / width,
                                static_cast<double>(area_h) / height);
  const int dest_w = static_cast<int>(std::lround(width * scale));
  const int dest_h = static_cast<int>(std::lround(height * scale));
  const int x = (area_w - dest_w) / 2;
  const int y = (area_h - dest_h) / 2;

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
