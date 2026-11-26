/* A window with a D3D11 swapchain presenting for argv[1] seconds (default 30): the DXMT background
   throttle's log lines then show whether the window counts as foreground. With "activate" as argv[2]
   it calls SetForegroundWindow on itself after 3 s; with "drop" it calls SetActiveWindow(NULL) after 8 s,
   which leaves Wine with no foreground window (GetForegroundWindow() == NULL) while macOS keeps the window key. Build: x86_64-w64-mingw32-gcc -O2 present-loop.c
   -o present-loop.exe -ld3d11 -ldxgi -luser32 -lgdi32 */
#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <d3d11.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static LRESULT CALLBACK proc(HWND h, UINT m, WPARAM w, LPARAM l) {
  if (m == WM_DESTROY) { PostQuitMessage(0); return 0; }
  return DefWindowProcW(h, m, w, l);
}

int main(int argc, char **argv) {
  int seconds = argc > 1 ? atoi(argv[1]) : 30;
  int activate = argc > 2 && !strcmp(argv[2], "activate");
  int drop = argc > 2 && !strcmp(argv[2], "drop");
  WNDCLASSW wc = {0};
  wc.lpfnWndProc = proc; wc.hInstance = GetModuleHandleW(NULL); wc.lpszClassName = L"present-loop";
  RegisterClassW(&wc);
  HWND hwnd = CreateWindowW(L"present-loop", L"DXMT focus test", WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                            100, 100, 640, 400, NULL, NULL, wc.hInstance, NULL);
  DXGI_SWAP_CHAIN_DESC sd = {0};
  sd.BufferCount = 2; sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM; sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
  sd.OutputWindow = hwnd; sd.SampleDesc.Count = 1; sd.Windowed = TRUE; sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
  IDXGISwapChain *sc; ID3D11Device *dev; ID3D11DeviceContext *ctx;
  HRESULT hr = D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, NULL, 0, D3D11_SDK_VERSION,
                                             &sd, &sc, &dev, NULL, &ctx);
  if (FAILED(hr)) { fprintf(stderr, "D3D11CreateDeviceAndSwapChain failed: 0x%08lx\n", hr); return 1; }
  ID3D11Texture2D *bb; ID3D11RenderTargetView *rtv;
  IDXGISwapChain_GetBuffer(sc, 0, &IID_ID3D11Texture2D, (void **)&bb);
  ID3D11Device_CreateRenderTargetView(dev, (ID3D11Resource *)bb, NULL, &rtv);
  DWORD start = GetTickCount(), frames = 0, last = start;
  int activated = 0, dropped = 0;
  for (;;) {
    MSG msg;
    while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
      if (msg.message == WM_QUIT) return 0;
      TranslateMessage(&msg); DispatchMessageW(&msg);
    }
    DWORD now = GetTickCount();
    if (activate && !activated && now - start > 3000) { SetForegroundWindow(hwnd); activated = 1; }
    if (drop && !dropped && now - start > 8000) { SetActiveWindow(NULL); dropped = 1; }
    if (now - start > (DWORD)seconds * 1000) break;
    float c[4] = { (frames % 120) / 120.0f, 0.2f, 0.4f, 1 };
    ID3D11DeviceContext_ClearRenderTargetView(ctx, rtv, c);
    IDXGISwapChain_Present(sc, 1, 0);
    frames++;
    if (now - last >= 2000) {
      HWND fg = GetForegroundWindow();
      printf("t=%lus fps=%.1f foreground=%p ours=%p\n", (now - start) / 1000, frames * 1000.0 / (now - last), (void *)fg, (void *)hwnd);
      fflush(stdout); frames = 0; last = now;
    }
  }
  return 0;
}
