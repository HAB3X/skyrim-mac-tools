// winres.h stand-in for the Mac cross toolchain (Visual Studio ships winres.h with ATL/MFC, which xwin doesn't fetch).
// Same content as Microsoft's: the resource-compiler definitions plus IDC_STATIC.
#include <winresrc.h>
#ifdef IDC_STATIC
#undef IDC_STATIC
#endif
#define IDC_STATIC (-1)
