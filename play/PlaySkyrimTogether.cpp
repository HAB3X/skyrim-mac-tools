// Play Skyrim Together: one click from an unzipped release to the game.
//
// Sits next to the release's SkyrimTogether-1.6.1170 and SkyrimTogether-1.7.104 folders. It finds Skyrim Special
// Edition (Steam or GOG Galaxy install records, else asks for the folder once), picks the folder matching the game's
// version, copies it into the game's Data folder when it isn't installed yet or a different build is, turns on
// SkyrimTogether.esp and SkyrimTogetherQuestPatches.esp in the load order, checks for the Address Library, and starts
// Data\SkyrimTogetherReborn\SkyrimTogether.exe. Hold Shift while starting it to pick the game folder again.
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
    PWSTR localAppData = nullptr;
    if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &localAppData)))
        return;
    const fs::path cDir = fs::path(localAppData) / SettingsFolderName(acGame);
    CoTaskMemFree(localAppData);
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
} // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    const bool cPickAgain = GetAsyncKeyState(VK_SHIFT) & 0x8000;
    fs::path game = cPickAgain ? fs::path{} : FindGame();
    if (game.empty())
        game = PickGame();
    WriteRegistryString(L"GamePath", game.wstring());

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
