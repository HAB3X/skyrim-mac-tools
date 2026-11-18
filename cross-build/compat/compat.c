/* Small runtime pieces a real MSVC build has but this Mac cross build (clang-cl + lld-link + xwin) lacks.
 * Built into compat.lib, which the link wrapper (~/Developer/xwin/bin/link) adds to every program/DLL link.
 * Unused objects are never pulled in, so it changes nothing for code that doesn't need them.
 *
 * - __udivti3 / __umodti3: clang's 128-bit division helpers (compiler-rt builtins, not shipped by Homebrew for
 *   Windows). Clang emits calls for unsigned __int128 division (Crypto++ uses it when __SIZEOF_INT128__ is set).
 * - XGETBV64 / CPUID64: Crypto++ expects them from x64dll.asm, which llvm-ml can't assemble; same behaviour here
 *   with the compiler intrinsics.
 * Build: ~/Developer/xwin/compat/build.sh */
#include <intrin.h>

typedef unsigned __int128 u128;

/* Shift-subtract division: only shifts, compares and subtractions, so it never calls itself. */
static u128 udivmod128(u128 n, u128 d, u128 *rem)
{
    u128 q = 0, r = 0;
    if (d == 0) { /* same as hardware: division by zero traps */
        volatile unsigned long long z = 0;
        *rem = 0;
        return (u128)(1ull / z);
    }
    for (int i = 127; i >= 0; --i) {
        r = (r << 1) | ((n >> i) & 1);
        if (r >= d) { r -= d; q |= (u128)1 << i; }
    }
    *rem = r;
    return q;
}

u128 __udivti3(u128 n, u128 d) { u128 r; return udivmod128(n, d, &r); }
u128 __umodti3(u128 n, u128 d) { u128 r; udivmod128(n, d, &r); return r; }

unsigned long long __fastcall XGETBV64(unsigned int num) { return _xgetbv(num); }

unsigned long long __fastcall CPUID64(unsigned int func, unsigned int subfunc, unsigned int *output)
{
    int regs[4];
    __cpuidex(regs, (int)func, (int)subfunc);
    for (int i = 0; i < 4; ++i) output[i] = (unsigned int)regs[i];
    return 1;
}
