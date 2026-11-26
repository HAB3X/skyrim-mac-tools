/* game-input.exe: play a fixed sequence of keyboard and mouse input into the game, for repeatable benchmark runs.
 * Runs in the game's Wine prefix; the input goes through SendInput, so it reaches the game's DirectInput as long as the
 * game's window is Wine's foreground window (run fix-input.exe first). Needs no macOS permission.
 *
 * Steps, run in order:
 *   tap:<key>            press and release a key (scan code, e.g. tap:0x1C for Enter)
 *   down:<key> up:<key>  hold / release a key
 *   wait:<ms>            sleep
 *   turn:<dx>:<ms>       move the mouse dx counts to the right, spread evenly over ms (negative: left)
 * Keys are DirectInput scan codes: 0x01 Esc, 0x1C Enter, 0x11 W, 0x12 E, 0x2A left Shift.
 * Prints nothing; exit 2 on a step it doesn't understand.
 *
 * Build: x86_64-w64-mingw32-gcc -O2 -s game-input.c -o game-input.exe -luser32
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void key(WORD scan, int up) {
  INPUT in = { .type = INPUT_KEYBOARD };
  in.ki.wScan = scan;
  in.ki.dwFlags = KEYEVENTF_SCANCODE | (up ? KEYEVENTF_KEYUP : 0);
  SendInput(1, &in, sizeof(in));
}

static void mouse_move(LONG dx) {
  INPUT in = { .type = INPUT_MOUSE };
  in.mi.dx = dx;
  in.mi.dwFlags = MOUSEEVENTF_MOVE;
  SendInput(1, &in, sizeof(in));
}

/* 10 ms steps, the remainder carried so the total is exactly dx */
static void turn(long dx, long ms) {
  long steps = ms / 10 > 0 ? ms / 10 : 1, done = 0;
  for (long i = 1; i <= steps; i++) {
    long to = dx * i / steps;
    mouse_move(to - done);
    done = to;
    Sleep(10);
  }
}

int main(int argc, char **argv) {
  for (int i = 1; i < argc; i++) {
    const char *s = argv[i];
    long a = 0, b = 0;
    if (!strncmp(s, "tap:", 4)) { a = strtol(s + 4, NULL, 0); key((WORD)a, 0); Sleep(60); key((WORD)a, 1); Sleep(60); }
    else if (!strncmp(s, "down:", 5)) key((WORD)strtol(s + 5, NULL, 0), 0);
    else if (!strncmp(s, "up:", 3)) key((WORD)strtol(s + 3, NULL, 0), 1);
    else if (!strncmp(s, "wait:", 5)) Sleep((DWORD)strtol(s + 5, NULL, 0));
    else if (sscanf(s, "turn:%ld:%ld", &a, &b) == 2) turn(a, b);
    else { fprintf(stderr, "game-input.exe: unknown step %s\n", s); return 2; }
  }
  return 0;
}
