// Play Skyrim Together: one click from an unzipped release to the game.
//
// Sits next to the release's SkyrimTogether-1.6.1170 and SkyrimTogether-1.7.104 folders. It finds Skyrim Special
// Edition (Steam or GOG Galaxy install records, else asks for the folder once), picks the folder matching the game's
// version, copies it into the game's Data folder when it isn't installed yet or a different build is, turns on
// SkyrimTogether.esp and SkyrimTogetherQuestPatches.esp in the load order, checks for the Address Library, and starts
// Data\SkyrimTogetherReborn\SkyrimTogether.exe. Hold Shift while starting it to pick the game folder again.
// Hold Ctrl while starting it (or pass --collect-logs) to put the logs, crash dumps and settings needed to report a
// problem into a new Desktop folder instead (passwords removed, no save games).
//
// Build (clang-cl / MSVC): cl /std:c++20 /O2 /EHsc PlaySkyrimTogether.cpp /link /SUBSYSTEM:WINDOWS
//   user32.lib shell32.lib ole32.lib advapi32.lib version.lib

#include <Windows.h>
#include <shlobj.h>
#include <shobjidl.h>

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

namespace
{
constexpr wchar_t kTitle[] = L"Play Skyrim Together";
constexpr wchar_t kGameExe[] = L"SkyrimSE.exe";
constexpr wchar_t kStampFile[] = L"SkyrimTogetherReborn\\.installed-build";
constexpr wchar_t kSettingsKey[] = L"Software\\HAB3X\\PlaySkyrimTogether";
constexpr wchar_t kAddressLibraryUrl[] = L"https://www.nexusmods.com/skyrimspecialedition/mods/32444?tab=files";
const wchar_t* const kPlugins[] = {L"SkyrimTogether.esp", L"SkyrimTogetherQuestPatches.esp"};

void Fail(const std::wstring& acMessage)
{
    MessageBoxW(nullptr, acMessage.c_str(), kTitle, MB_ICONERROR);
    ExitProcess(1);
}

fs::path OwnFolder()
{
    wchar_t path[MAX_PATH * 4]{};
    GetModuleFileNameW(nullptr, path, static_cast<DWORD>(std::size(path)));
    return fs::path(path).parent_path();
}

bool HasGame(const fs::path& acDir)
{
    std::error_code ec;
    return !acDir.empty() && fs::exists(acDir / kGameExe, ec);
}

std::wstring ReadRegistryString(HKEY aRoot, const wchar_t* apSubKey, const wchar_t* apValue)
{
    wchar_t buffer[MAX_PATH * 4]{};
    DWORD size = sizeof(buffer);
    if (RegGetValueW(aRoot, apSubKey, apValue, RRF_RT_REG_SZ, nullptr, buffer, &size) != ERROR_SUCCESS)
        return {};
    return buffer;
}

void WriteRegistryString(const wchar_t* apValue, const std::wstring& acData)
{
    RegSetKeyValueW(HKEY_CURRENT_USER, kSettingsKey, apValue, REG_SZ, acData.c_str(),
                    static_cast<DWORD>((acData.size() + 1) * sizeof(wchar_t)));
}

// The game folder without asking: last used, around this program, then Steam's and GOG Galaxy's install records
fs::path FindGame()
{
    if (fs::path last = ReadRegistryString(HKEY_CURRENT_USER, kSettingsKey, L"GamePath"); HasGame(last))
        return last;
    for (fs::path dir = OwnFolder(); dir.has_relative_path(); dir = dir.parent_path())
    {
        if (HasGame(dir))
            return dir;
    }
    const std::pair<const wchar_t*, const wchar_t*> cInstallKeys[] = {
        {L"Software\\Wow6432Node\\Bethesda Softworks\\Skyrim Special Edition", L"installed path"},
        {L"Software\\Wow6432Node\\GOG.com\\Games\\1711230643", L"path"}};
    for (const auto& [subKey, value] : cInstallKeys)
    {
        fs::path dir = ReadRegistryString(HKEY_LOCAL_MACHINE, subKey, value);
        if (HasGame(dir))
            return dir;
    }
    return {};
}

std::optional<fs::path> AskForFolder()
{
    IFileOpenDialog* pDialog = nullptr;
    if (FAILED(CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_ALL, IID_PPV_ARGS(&pDialog))))
        return std::nullopt;
    DWORD options = 0;
    pDialog->GetOptions(&options);
    pDialog->SetOptions(options | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM);
    pDialog->SetTitle(L"Select your Skyrim Special Edition folder (the one with SkyrimSE.exe)");

    std::optional<fs::path> result;
    IShellItem* pItem = nullptr;
    PWSTR folder = nullptr;
    if (SUCCEEDED(pDialog->Show(nullptr)) && SUCCEEDED(pDialog->GetResult(&pItem)) &&
        SUCCEEDED(pItem->GetDisplayName(SIGDN_FILESYSPATH, &folder)))
    {
        result = fs::path(folder);
        CoTaskMemFree(folder);
    }
    if (pItem)
        pItem->Release();
    pDialog->Release();
    return result;
}

fs::path PickGame()
{
    for (int attempt = 0; attempt < 3; attempt++)
    {
        auto folder = AskForFolder();
        if (!folder)
            ExitProcess(0); // cancelled
        if (HasGame(*folder))
            return *folder;
        MessageBoxW(nullptr, L"That folder doesn't have SkyrimSE.exe in it. Pick the folder Skyrim Special Edition is installed in.",
                    kTitle, MB_ICONWARNING);
    }
    Fail(L"Skyrim Special Edition wasn't found.");
    return {};
}

// "1.6.1170.0" from the exe's version resource
std::wstring GameVersion(const fs::path& acExe)
{
    DWORD handle = 0;
    const DWORD size = GetFileVersionInfoSizeW(acExe.c_str(), &handle);
    std::vector<BYTE> data(size);
    VS_FIXEDFILEINFO* pInfo = nullptr;
    UINT length = 0;
    if (!size || !GetFileVersionInfoW(acExe.c_str(), 0, size, data.data()) ||
        !VerQueryValueW(data.data(), L"\\", reinterpret_cast<void**>(&pInfo), &length) || !pInfo)
        return {};
    std::wstringstream version;
    version << HIWORD(pInfo->dwFileVersionMS) << L'.' << LOWORD(pInfo->dwFileVersionMS) << L'.'
            << HIWORD(pInfo->dwFileVersionLS) << L'.' << LOWORD(pInfo->dwFileVersionLS);
    return version.str();
}

// The release folder built for this game version: Steam 1.6.1170 and GOG 1.6.1179 share one build, 1.7.x the other
fs::path ReleaseFolderFor(const std::wstring& acVersion)
{
    const fs::path cOwn = OwnFolder();
    if (acVersion.rfind(L"1.6.1170.", 0) == 0 || acVersion.rfind(L"1.6.1179.", 0) == 0)
        return cOwn / L"SkyrimTogether-1.6.1170";
    if (acVersion.rfind(L"1.7.", 0) == 0)
        return cOwn / L"SkyrimTogether-1.7.104";
    Fail(L"This Skyrim is version " + acVersion +
         L". Skyrim Together supports Steam 1.7.x, Steam 1.6.1170 and GOG 1.6.1179 (Anniversary Edition updates).");
    return {};
}

std::wstring ReadStamp(const fs::path& acData)
{
    std::wifstream file(acData / kStampFile);
    std::wstring stamp;
    std::getline(file, stamp);
    return stamp;
}

void Install(const fs::path& acSource, const fs::path& acData, const std::wstring& acStamp)
{
    std::error_code ec;
    fs::copy(acSource, acData, fs::copy_options::recursive | fs::copy_options::overwrite_existing, ec);
    if (ec)
    {
        const std::string cReason = ec.message();
        Fail(L"Couldn't copy Skyrim Together into " + acData.wstring() + L":\n" + std::wstring(cReason.begin(), cReason.end()) +
             L"\n\nIf the game is in Program Files, run this program as administrator once.");
    }
    std::wofstream(acData / kStampFile) << acStamp;
}

fs::path KnownFolder(REFKNOWNFOLDERID aId)
{
    PWSTR path = nullptr;
    fs::path result;
    if (SUCCEEDED(SHGetKnownFolderPath(aId, 0, nullptr, &path)))
        result = path;
    CoTaskMemFree(path);
    return result;
}

// The game's per-user folder name under %LOCALAPPDATA% and Documents\My Games. GOG's build ships Galaxy64.dll and no
// Steam API; its settings live in "Skyrim Special Edition GOG".
const wchar_t* SettingsFolderName(const fs::path& acGame)
{
    std::error_code ec;
    const bool cGog = fs::exists(acGame / L"Galaxy64.dll", ec) || !fs::exists(acGame / L"steam_api64.dll", ec);
    return cGog ? L"Skyrim Special Edition GOG" : L"Skyrim Special Edition";
}

// %LOCALAPPDATA%\Skyrim Special Edition[ GOG]\Plugins.txt: every plugin line with '*' is enabled
void EnablePlugins(const fs::path& acGame)
{
    const fs::path cLocalAppData = KnownFolder(FOLDERID_LocalAppData);
    if (cLocalAppData.empty())
        return;
    const fs::path cDir = cLocalAppData / SettingsFolderName(acGame);
    std::error_code ec;
    fs::create_directories(cDir, ec);
    const fs::path cFile = cDir / L"Plugins.txt";

    std::vector<std::string> lines;
    {
        std::ifstream in(cFile);
        for (std::string line; std::getline(in, line);)
        {
            if (!line.empty() && line.back() == '\r')
                line.pop_back();
            lines.push_back(line);
        }
    }
    auto lower = [](std::string s) { std::transform(s.begin(), s.end(), s.begin(), ::tolower); return s; };
    for (const wchar_t* pPlugin : kPlugins)
    {
        const std::string cName(pPlugin, pPlugin + wcslen(pPlugin));
        // drop the plugin wherever it is, then add it enabled at the end (Skyrim Together's plugins load last)
        std::erase_if(lines, [&](const std::string& l) { return lower(l.starts_with('*') ? l.substr(1) : l) == lower(cName); });
        lines.push_back("*" + cName);
    }
    std::ofstream out(cFile, std::ios::binary);
    for (const auto& line : lines)
        out << line << "\r\n";
}

bool HasAddressLibrary(const fs::path& acData, const std::wstring& acVersion)
{
    std::wstring name = acVersion;
    std::replace(name.begin(), name.end(), L'.', L'-');
    std::error_code ec;
    return fs::exists(acData / L"SKSE\\Plugins" / (L"versionlib-" + name + L".bin"), ec);
}
// ---- Collect logs: hold Ctrl while starting (or pass --collect-logs) to gather what's needed to report a problem ----

std::string ToUtf8(const std::wstring& acText)
{
    if (acText.empty())
        return {};
    const int cSize = WideCharToMultiByte(CP_UTF8, 0, acText.data(), static_cast<int>(acText.size()), nullptr, 0, nullptr, nullptr);
    std::string utf8(cSize, '\0');
    WideCharToMultiByte(CP_UTF8, 0, acText.data(), static_cast<int>(acText.size()), utf8.data(), cSize, nullptr, nullptr);
    return utf8;
}

std::wstring LowerW(std::wstring aText)
{
    std::transform(aText.begin(), aText.end(), aText.begin(), ::towlower);
    return aText;
}

// Case-insensitive name match with at most one '*' ("*.log", "crash-*.log", "Plugins.txt")
bool MatchesPattern(const std::wstring& acName, std::wstring_view aPattern)
{
    const std::wstring cName = LowerW(acName), cPattern = LowerW(std::wstring(aPattern));
    const auto cStar = cPattern.find(L'*');
    if (cStar == std::wstring::npos)
        return cName == cPattern;
    const std::wstring_view cPrefix = std::wstring_view(cPattern).substr(0, cStar), cSuffix = std::wstring_view(cPattern).substr(cStar + 1);
    return cName.size() >= cPrefix.size() + cSuffix.size() && cName.starts_with(cPrefix) && cName.ends_with(cSuffix);
}

// Copies the aCount newest non-empty files in acDir matching aPattern into acDest; failures are added to aProblems
void CopyNewest(const fs::path& acDest, const fs::path& acDir, std::wstring_view aPattern, size_t aCount, std::wstring& aProblems)
{
    std::vector<std::pair<fs::file_time_type, fs::path>> found;
    std::error_code ec;
    for (const auto& entry : fs::directory_iterator(acDir, ec))
    {
        std::error_code entryError;
        if (entry.is_regular_file(entryError) && entry.file_size(entryError) > 0 && MatchesPattern(entry.path().filename().wstring(), aPattern))
            found.emplace_back(entry.last_write_time(entryError), entry.path());
    }
    std::sort(found.begin(), found.end(), [](const auto& a, const auto& b) { return a.first > b.first; });
    found.resize((std::min)(found.size(), aCount)); // parenthesised: Windows.h defines min
    for (const auto& [time, file] : found)
    {
        fs::create_directories(acDest, ec);
        if (!fs::copy_file(file, acDest / file.filename(), fs::copy_options::overwrite_existing, ec))
            aProblems += L"\n" + file.wstring();
    }
}

// STServer.ini with every password/token value replaced, so the folder can be shared
void CopyRedactedIni(const fs::path& acSource, const fs::path& acDest, std::wstring& aProblems)
{
    std::error_code ec;
    if (!fs::exists(acSource, ec))
        return;
    fs::create_directories(acDest.parent_path(), ec);
    std::ifstream in(acSource, std::ios::binary);
    std::ofstream out(acDest, std::ios::binary);
    if (!in || !out)
    {
        aProblems += L"\n" + acSource.wstring();
        return;
    }
    for (std::string line; std::getline(in, line);)
    {
        const auto cEquals = line.find('=');
        std::string key = cEquals == std::string::npos ? std::string{} : line.substr(0, cEquals);
        std::transform(key.begin(), key.end(), key.begin(), ::tolower);
        key.erase(0, key.find_first_not_of(" \t"));
        const bool cSecret = !key.empty() && key[0] != ';' && key[0] != '#' &&
                             (key.find("password") != std::string::npos || key.find("token") != std::string::npos);
        if (cSecret)
            line = line.substr(0, cEquals + 1) + "<removed>" + (line.ends_with('\r') ? "\r" : "");
        out << line << '\n';
    }
}

// "Build: v1.8.4-plus.3 ..." baked into SkyrimTogether.exe
std::string BuildString(const fs::path& acExe)
{
    std::ifstream file(acExe, std::ios::binary);
    const std::string cData((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    const auto cStart = cData.find("Build: v");
    if (cStart == std::string::npos)
        return "(no build string)";
    return cData.substr(cStart, cData.find('\0', cStart) - cStart);
}

std::string SystemSummary(const fs::path& acGame)
{
    const wchar_t* const cWindowsKey = L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion";
    std::ostringstream summary;
    SYSTEMTIME now;
    GetLocalTime(&now);
    char date[32];
    snprintf(date, sizeof(date), "%04u-%02u-%02u %02u:%02u:%02u", now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond);
    summary << "collected " << date << "\r\n";
    summary << "Windows: " << ToUtf8(ReadRegistryString(HKEY_LOCAL_MACHINE, cWindowsKey, L"ProductName")) << " "
            << ToUtf8(ReadRegistryString(HKEY_LOCAL_MACHINE, cWindowsKey, L"DisplayVersion")) << " (build "
            << ToUtf8(ReadRegistryString(HKEY_LOCAL_MACHINE, cWindowsKey, L"CurrentBuild")) << ")\r\n";
    using WineVersion = const char*(__cdecl*)();
    if (const auto cWine = reinterpret_cast<WineVersion>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "wine_get_version")))
        summary << "Wine: " << cWine() << "\r\n";
    summary << "game folder: " << ToUtf8(acGame.wstring()) << "\r\n";
    summary << "game version: " << ToUtf8(GameVersion(acGame / kGameExe)) << "\r\n";
    summary << "installed Skyrim Together build: " << ToUtf8(ReadStamp(acGame / L"Data")) << "\r\n";
    summary << "SkyrimTogether.exe: " << BuildString(acGame / L"Data\\SkyrimTogetherReborn\\SkyrimTogether.exe") << "\r\n";
    return summary.str();
}

// A new Desktop folder "SkyrimTogether-logs-<date>" with the mod's logs, crash dumps, Crash Logger reports, the load
// order and settings, STServer.ini without its passwords and a system summary; opened in Explorer. No save games.
void CollectLogs(const fs::path& acGame)
{
    const fs::path cDesktop = KnownFolder(FOLDERID_Desktop);
    if (cDesktop.empty())
        Fail(L"Couldn't find your Desktop folder.");
    SYSTEMTIME now;
    GetLocalTime(&now);
    wchar_t name[64];
    swprintf_s(name, L"SkyrimTogether-logs-%04u-%02u-%02u_%02u%02u%02u", now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond);
    const fs::path cOut = cDesktop / name;
    std::error_code ec;
    if (!fs::create_directories(cOut, ec))
        Fail(L"Couldn't create " + cOut.wstring() + L".");

    const fs::path cMod = acGame / L"Data\\SkyrimTogetherReborn";
    const fs::path cMyGames = KnownFolder(FOLDERID_Documents) / L"My Games" / SettingsFolderName(acGame);
    const fs::path cLoadOrder = KnownFolder(FOLDERID_LocalAppData) / SettingsFolderName(acGame);
    const fs::path cSettings = cOut / L"game-settings";
    std::wstring problems;
    CopyNewest(cOut / L"mod", cMod / L"logs", L"*.log", 8, problems);
    CopyNewest(cOut / L"skse", cMyGames / L"SKSE", L"crash-*.log", 5, problems);
    CopyNewest(cOut / L"skse", cMyGames / L"SKSE", L"skse64.log", 1, problems);
    CopyNewest(cOut / L"skse", cMyGames / L"SKSE", L"CrashLogger.log", 1, problems);
    // The mod writes crash_UTC_<time>.dmp next to SkyrimTogether.exe
    for (const fs::path& dir : {cMod, acGame})
        CopyNewest(cOut / L"dumps", dir, L"*.dmp", 3, problems);
    for (const wchar_t* pFile : {L"Plugins.txt", L"loadorder.txt"})
        CopyNewest(cSettings, cLoadOrder, pFile, 1, problems);
    for (const wchar_t* pFile : {L"Skyrim.ini", L"SkyrimPrefs.ini", L"SkyrimCustom.ini"})
        CopyNewest(cSettings, cMyGames, pFile, 1, problems);
    CopyNewest(cSettings, cMod / L"config", L"CrashGuards.ini", 1, problems);
    CopyRedactedIni(cMod / L"config\\STServer.ini", cSettings / L"STServer.ini", problems);
    std::ofstream(cOut / L"system.txt", std::ios::binary) << SystemSummary(acGame);

    if (!problems.empty())
        MessageBoxW(nullptr, (L"The logs are in " + cOut.wstring() + L", but these files couldn't be copied:" + problems).c_str(),
                    kTitle, MB_ICONWARNING);
    ShellExecuteW(nullptr, L"open", cOut.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
}

bool WantsLogCollection()
{
    if (GetAsyncKeyState(VK_CONTROL) & 0x8000)
        return true;
    int count = 0;
    LPWSTR* ppArgs = CommandLineToArgvW(GetCommandLineW(), &count);
    bool wanted = false;
    for (int i = 1; ppArgs && i < count; i++)
        wanted = wanted || _wcsicmp(ppArgs[i], L"--collect-logs") == 0;
    LocalFree(ppArgs);
    return wanted;
}
} // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    const bool cPickAgain = GetAsyncKeyState(VK_SHIFT) & 0x8000;
    fs::path game = cPickAgain ? fs::path{} : FindGame();
    if (game.empty())
        game = PickGame();
    WriteRegistryString(L"GamePath", game.wstring());
    if (WantsLogCollection())
    {
        CollectLogs(game);
        return 0;
    }

    const std::wstring cVersion = GameVersion(game / kGameExe);
    if (cVersion.empty())
        Fail(L"Couldn't read the version of " + (game / kGameExe).wstring() + L".");
    const fs::path cSource = ReleaseFolderFor(cVersion);
    if (!fs::exists(cSource / L"SkyrimTogetherReborn\\SkyrimTogether.exe"))
        Fail(L"The release folder " + cSource.wstring() + L" is missing. Unzip the whole release, then run this again.");

    // The installed build is remembered by release folder + its exe's timestamp, so a newer release reinstalls
    const fs::path cData = game / L"Data";
    std::error_code ec;
    const auto cBuildTime = fs::last_write_time(cSource / L"SkyrimTogetherReborn\\SkyrimTogether.exe", ec).time_since_epoch().count();
    const std::wstring cStamp = OwnFolder().filename().wstring() + L"/" + cSource.filename().wstring() + L"/" + std::to_wstring(cBuildTime);
    if (cPickAgain || ReadStamp(cData) != cStamp)
        Install(cSource, cData, cStamp);
    EnablePlugins(game);

    if (!HasAddressLibrary(cData, cVersion))
    {
        if (MessageBoxW(nullptr,
                        L"Skyrim Together needs the Address Library for SKSE Plugins, which isn't installed yet.\n\n"
                        L"Open its download page now? Install \"All in one\" with your mod manager (or copy its "
                        L"SKSE folder into Data), then run Play Skyrim Together again.",
                        kTitle, MB_ICONINFORMATION | MB_YESNO) == IDYES)
            ShellExecuteW(nullptr, L"open", kAddressLibraryUrl, nullptr, nullptr, SW_SHOWNORMAL);
        return 0;
    }

    const fs::path cLauncher = cData / L"SkyrimTogetherReborn";
    STARTUPINFOW startup{sizeof(startup)};
    PROCESS_INFORMATION process{};
    std::wstring commandLine = L"\"" + (cLauncher / L"SkyrimTogether.exe").wstring() + L"\"";
    if (!CreateProcessW(nullptr, commandLine.data(), nullptr, nullptr, FALSE, 0, nullptr, cLauncher.c_str(), &startup, &process))
        Fail(L"Couldn't start " + (cLauncher / L"SkyrimTogether.exe").wstring() + L".");
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return 0;
}
