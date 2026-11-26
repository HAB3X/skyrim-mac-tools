/* fix-input.exe: give Skyrim its mouse and keyboard back without restarting it. Runs in the game's Wine prefix.
 *
 * Skyrim reads the mouse and keyboard through DirectInput in foreground mode: it only gets input while its window is
 * Wine's foreground window, and takes the devices back when it is activated again. Wine's foreground window isn't
 * macOS's: after a Cmd-Tab Wine can be left with no foreground window (or another process's) while the game is the
 * active Mac app, and then the game gets no input until it restarts. This makes the game's window Wine's foreground
 * window again. With --reset it also releases Wine's cursor clipping and takes Wine's foreground away from the game
 * before giving it back, so DirectInput and the cursor clip start over.
 * With --watch it stays running while the game's window exists and does this whenever Wine has no foreground window
 * at all. (When the Mac app isn't active Wine's foreground is the desktop window, so that case is left alone; making
 * the game Wine's foreground window never makes it the active Mac app.)
 *
 * The game's window: the largest visible top-level window of a process named SkyrimTogether.exe or SkyrimSE.exe (or
 * the names given with --process NAME, for testing). Prints what it did; exit 1 when there is no such window.
 *
 * Build: x86_64-w64-mingw32-gcc -O2 -s fix-input.c -o fix-input.exe -luser32 -lpsapi
 */
#include <windows.h>
#include <psapi.h>
#include <stdio.h>
#include <string.h>

static const char *names[8] = { "SkyrimTogether.exe", "SkyrimSE.exe" };
static int name_count = 2;

struct pick { HWND hwnd; LONG area; };

static int process_matches(DWORD pid) {
  char path[MAX_PATH] = "";
  HANDLE p = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!p) return 0;
  DWORD n = sizeof(path);
  BOOL ok = QueryFullProcessImageNameA(p, 0, path, &n);
  CloseHandle(p);
  if (!ok) return 0;
  const char *base = strrchr(path, '\\');
  base = base ? base + 1 : path;
  for (int i = 0; i < name_count; i++)
    if (!_stricmp(base, names[i])) return 1;
  return 0;
}

static BOOL CALLBACK consider(HWND hwnd, LPARAM lp) {
  struct pick *best = (struct pick *)lp;
  RECT r;
  DWORD pid = 0;
  if (!IsWindowVisible(hwnd) || GetWindow(hwnd, GW_OWNER) || !GetWindowRect(hwnd, &r)) return TRUE;
  GetWindowThreadProcessId(hwnd, &pid);
  LONG area = (r.right - r.left) * (r.bottom - r.top);
  if (area > best->area && process_matches(pid)) { best->hwnd = hwnd; best->area = area; }
  return TRUE;
}

/* SetForegroundWindow on another process's window returns before that process has been activated: wait for it */
static int wait_foreground(HWND want, int is) {
  for (int ms = 0; ms < 1000; ms += 20) {
    if ((GetForegroundWindow() == want) == is) return 1;
    Sleep(20);
  }
  return 0;
}

static HWND find_game(void) {
  struct pick best = { NULL, 0 };
  EnumWindows(consider, (LPARAM)&best);
  return best.hwnd;
}

/* Until the game's window has been gone for 10 s: give it Wine's foreground whenever there is none */
static int watch(void) {
  int missing = 0;
  for (;;) {
    Sleep(500);
    HWND game = find_game();
    if (!game) {
      if (++missing >= 20) return 0;
      continue;
    }
    missing = 0;
    if (GetForegroundWindow() == NULL && !IsIconic(game)) {
      SetForegroundWindow(game);
      int ok = wait_foreground(game, 1);
      printf("%s no foreground window: gave it to the game window %p\n", ok ? "OK  " : "FAIL", (void *)game);
      fflush(stdout);
    }
  }
}

int main(int argc, char **argv) {
  int reset = 0, custom = 0, watching = 0;
  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "--reset")) reset = 1;
    else if (!strcmp(argv[i], "--watch")) watching = 1;
    else if (!strcmp(argv[i], "--process") && i + 1 < argc) {
      if (!custom) { name_count = 0; custom = 1; } /* the names given replace the defaults */
      if (name_count < 8) names[name_count++] = argv[++i];
    } else { fprintf(stderr, "usage: fix-input.exe [--reset | --watch] [--process NAME]...\n"); return 2; }
  }
  HWND game = find_game();
  if (!game) { printf("FAIL no game window (is the game running?)\n"); return 1; }
  if (watching) return watch();
  HWND before = GetForegroundWindow();
  if (reset) {
    ClipCursor(NULL);
    SetForegroundWindow(GetDesktopWindow());
    wait_foreground(game, 0);
  }
  if (IsIconic(game)) ShowWindow(game, SW_RESTORE);
  SetForegroundWindow(game);
  int ok = wait_foreground(game, 1);
  printf("%s game window %p: foreground was %p, now %p%s\n", ok ? "OK  " : "FAIL", (void *)game, (void *)before,
         (void *)GetForegroundWindow(), reset ? " (cursor clip released, window re-activated)" : "");
  return ok ? 0 : 1;
}
