// Skyrim Together Host: run a co-op server from a window.
//
// Sits in a release next to SkyrimTogether-1.6.1170 (and Play Skyrim Together.exe). Edits the server's
// config\STServer.ini (name, password, player limit, port, PvP, host world), starts SkyrimTogetherServer.exe without a console
// window and talks to it through its stdin/stdout: it lists who is connected every few seconds (/players) and kicks
// the selected player (/kick). It shows the addresses friends join with and copies an invite to the clipboard.
//
// Build (clang-cl / MSVC): cl /std:c++20 /O2 /EHsc SkyrimTogetherHost.cpp /link /SUBSYSTEM:WINDOWS
//   user32.lib gdi32.lib shell32.lib comctl32.lib iphlpapi.lib ws2_32.lib winhttp.lib

#ifndef UNICODE
#define UNICODE
#define _UNICODE
#endif
#include <WinSock2.h>
#include <Windows.h>
#include <CommCtrl.h>
#include <windowsx.h>
#include <iphlpapi.h>
#include <winhttp.h>
#include <ws2tcpip.h>

#include <filesystem>
#include <fstream>
#include <iterator>
#include <regex>
#include <string>
#include <thread>
#include <vector>

namespace fs = std::filesystem;

namespace
{
constexpr wchar_t kTitle[] = L"Skyrim Together Host";
constexpr UINT WM_SERVER_LINE = WM_APP + 1; // lParam: std::string* (one stdout line), owned by the receiver
constexpr UINT WM_SERVER_EXIT = WM_APP + 2;
constexpr UINT WM_PUBLIC_IP = WM_APP + 3;   // lParam: std::wstring*
constexpr UINT_PTR kPollTimer = 1;
constexpr UINT kPollMs = 3000;

enum Control : int
{
    kName = 100, kPassword, kMaxPlayers, kPort, kPvp, kHostWorld, kStartStop, kPlayers, kKick, kStatus, kAddresses, kCopy, kLog
};

struct Player
{
    unsigned id;
    std::wstring name;
};

struct State
{
    HWND window{};
    HFONT font{};
    fs::path serverDir;
    PROCESS_INFORMATION process{};
    HANDLE stdinWrite{};
    bool running = false;
    std::wstring publicIp;
    std::vector<Player> players;
    std::vector<Player> pendingPlayers; // collected from a /players answer
    bool readingPlayers = false;
} g;

std::wstring Widen(const std::string& acText)
{
    if (acText.empty())
        return {};
    const int cLength = MultiByteToWideChar(CP_UTF8, 0, acText.data(), static_cast<int>(acText.size()), nullptr, 0);
    std::wstring out(cLength, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, acText.data(), static_cast<int>(acText.size()), out.data(), cLength);
    return out;
}

HWND Item(int aId) { return GetDlgItem(g.window, aId); }

std::wstring Text(int aId)
{
    const int cLength = GetWindowTextLengthW(Item(aId));
    std::wstring text(cLength + 1, L'\0');
    GetWindowTextW(Item(aId), text.data(), cLength + 1);
    text.resize(cLength);
    return text;
}

// The server folder of this release: any SkyrimTogether-*\SkyrimTogetherReborn with the server in it
fs::path FindServerDir()
{
    wchar_t path[MAX_PATH * 4]{};
    GetModuleFileNameW(nullptr, path, static_cast<DWORD>(std::size(path)));
    const fs::path cOwn = fs::path(path).parent_path();
    for (const wchar_t* pFolder : {L"SkyrimTogether-1.6.1170", L"SkyrimTogether-1.7.104", L"."})
    {
        const fs::path cDir = cOwn / pFolder / L"SkyrimTogetherReborn";
        if (fs::exists(cDir / L"SkyrimTogetherServer.exe"))
            return cDir;
    }
    if (fs::exists(cOwn / L"SkyrimTogetherServer.exe"))
        return cOwn;
    return {};
}

// Host world mode (Gameplay:bHostWorld) is in the Plus server only: its library names the setting
bool ServerHasHostWorld()
{
    std::ifstream file(g.serverDir / L"STServer.dll", std::ios::binary);
    const std::string cBytes{std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>()};
    return cBytes.find("Gameplay:bHostWorld") != std::string::npos;
}

fs::path IniPath() { return g.serverDir / L"config" / L"STServer.ini"; }

std::wstring IniRead(const wchar_t* apSection, const wchar_t* apKey, const wchar_t* apDefault)
{
    wchar_t value[512]{};
    GetPrivateProfileStringW(apSection, apKey, apDefault, value, static_cast<DWORD>(std::size(value)), IniPath().c_str());
    return value;
}

void IniWrite(const wchar_t* apSection, const wchar_t* apKey, const std::wstring& acValue)
{
    std::error_code ec;
    fs::create_directories(IniPath().parent_path(), ec);
    WritePrivateProfileStringW(apSection, apKey, acValue.c_str(), IniPath().c_str());
}

void LoadSettings()
{
    SetWindowTextW(Item(kName), IniRead(L"GameServer", L"sServerName", L"Skyrim Together co-op").c_str());
    SetWindowTextW(Item(kPassword), IniRead(L"GameServer", L"sPassword", L"").c_str());
    SetWindowTextW(Item(kMaxPlayers), IniRead(L"GameServer", L"uMaxPlayerCount", L"8").c_str());
    SetWindowTextW(Item(kPort), IniRead(L"GameServer", L"uPort", L"10578").c_str());
    Button_SetCheck(Item(kPvp), IniRead(L"Gameplay", L"bEnablePvp", L"false") == L"true" ? BST_CHECKED : BST_UNCHECKED);
    Button_SetCheck(Item(kHostWorld), IniRead(L"Gameplay", L"bHostWorld", L"false") == L"true" ? BST_CHECKED : BST_UNCHECKED);
    ShowWindow(Item(kHostWorld), ServerHasHostWorld() ? SW_SHOW : SW_HIDE);
}

bool SaveSettings()
{
    const std::wstring cMax = Text(kMaxPlayers), cPort = Text(kPort);
    const int cMaxValue = _wtoi(cMax.c_str()), cPortValue = _wtoi(cPort.c_str());
    if (cMaxValue < 1 || cMaxValue > 64 || cPortValue < 1024 || cPortValue > 65535)
    {
        MessageBoxW(g.window, L"Players must be 1 to 64 and the port 1024 to 65535.", kTitle, MB_ICONWARNING);
        return false;
    }
    IniWrite(L"GameServer", L"sServerName", Text(kName));
    IniWrite(L"GameServer", L"sPassword", Text(kPassword));
    IniWrite(L"GameServer", L"uMaxPlayerCount", std::to_wstring(cMaxValue));
    IniWrite(L"GameServer", L"uPort", std::to_wstring(cPortValue));
    IniWrite(L"Gameplay", L"bEnablePvp", Button_GetCheck(Item(kPvp)) == BST_CHECKED ? L"true" : L"false");
    if (ServerHasHostWorld())
        IniWrite(L"Gameplay", L"bHostWorld", Button_GetCheck(Item(kHostWorld)) == BST_CHECKED ? L"true" : L"false");
    return true;
}

void AppendLog(const std::wstring& acLine)
{
    HWND log = Item(kLog);
    // keep the box from growing without end: drop the older half past ~60 KB
    if (GetWindowTextLengthW(log) > 60000)
    {
        SendMessageW(log, EM_SETSEL, 0, 30000);
        SendMessageW(log, EM_REPLACESEL, FALSE, reinterpret_cast<LPARAM>(L""));
    }
    const int cEnd = GetWindowTextLengthW(log);
    SendMessageW(log, EM_SETSEL, cEnd, cEnd);
    const std::wstring cText = acLine + L"\r\n";
    SendMessageW(log, EM_REPLACESEL, FALSE, reinterpret_cast<LPARAM>(cText.c_str()));
}

void SendCommand(const std::string& acCommand)
{
    if (!g.running)
        return;
    const std::string cLine = acCommand + "\n";
    DWORD written = 0;
    WriteFile(g.stdinWrite, cLine.data(), static_cast<DWORD>(cLine.size()), &written, nullptr);
}

std::vector<std::wstring> LocalAddresses()
{
    std::vector<std::wstring> result;
    ULONG size = 16 * 1024;
    std::vector<BYTE> buffer(size);
    auto* pAdapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
    if (GetAdaptersAddresses(AF_INET, GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER, nullptr, pAdapters, &size) != NO_ERROR)
        return result;
    for (auto* pAdapter = pAdapters; pAdapter; pAdapter = pAdapter->Next)
    {
        if (pAdapter->OperStatus != IfOperStatusUp || pAdapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK)
            continue;
        for (auto* pAddress = pAdapter->FirstUnicastAddress; pAddress; pAddress = pAddress->Next)
        {
            wchar_t text[64]{};
            auto* pIn = reinterpret_cast<sockaddr_in*>(pAddress->Address.lpSockaddr);
            InetNtopW(AF_INET, &pIn->sin_addr, text, static_cast<DWORD>(std::size(text)));
            if (wcsncmp(text, L"169.254.", 8) != 0)
                result.emplace_back(text);
        }
    }
    return result;
}

// The internet address friends outside the home network use (needs the port forwarded on the router)
void FetchPublicIp(HWND aWindow)
{
    std::thread(
        [aWindow]
        {
            std::wstring ip;
            HINTERNET session = WinHttpOpen(kTitle, WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, nullptr, nullptr, 0);
            HINTERNET connect = session ? WinHttpConnect(session, L"api.ipify.org", INTERNET_DEFAULT_HTTPS_PORT, 0) : nullptr;
            HINTERNET request = connect ? WinHttpOpenRequest(connect, L"GET", L"/", nullptr, nullptr, nullptr, WINHTTP_FLAG_SECURE) : nullptr;
            if (request && WinHttpSendRequest(request, nullptr, 0, nullptr, 0, 0, 0) && WinHttpReceiveResponse(request, nullptr))
            {
                char body[64]{};
                DWORD read = 0;
                if (WinHttpReadData(request, body, sizeof(body) - 1, &read))
                    ip = Widen(std::string(body, read));
            }
            for (HINTERNET handle : {request, connect, session})
            {
                if (handle)
                    WinHttpCloseHandle(handle);
            }
            PostMessageW(aWindow, WM_PUBLIC_IP, 0, reinterpret_cast<LPARAM>(new std::wstring(ip)));
        })
        .detach();
}

void UpdateAddresses()
{
    const std::wstring cPort = Text(kPort);
    std::wstring text = L"Same Wi-Fi: ";
    const auto cLocal = LocalAddresses();
    for (size_t i = 0; i < cLocal.size(); i++)
        text += (i ? L", " : L"") + cLocal[i] + L":" + cPort;
    if (cLocal.empty())
        text += L"(no network)";
    text += L"\r\nInternet: " + (g.publicIp.empty() ? std::wstring(L"looking up...") : g.publicIp + L":" + cPort) +
            L"  (forward UDP port " + cPort + L" on your router)";
    SetWindowTextW(Item(kAddresses), text.c_str());
}

void UpdateUi()
{
    SetWindowTextW(Item(kStartStop), g.running ? L"Stop server" : L"Start server");
    for (int id : {kName, kPassword, kMaxPlayers, kPort, kPvp, kHostWorld})
        EnableWindow(Item(id), !g.running);
    const std::wstring cStatus = g.running ? L"Running: " + std::to_wstring(g.players.size()) + L" of " + Text(kMaxPlayers) + L" players connected"
                                           : L"Stopped";
    SetWindowTextW(Item(kStatus), cStatus.c_str());

    HWND list = Item(kPlayers);
    const LRESULT cSelected = SendMessageW(list, LB_GETCURSEL, 0, 0);
    SendMessageW(list, LB_RESETCONTENT, 0, 0);
    for (const auto& player : g.players)
    {
        const std::wstring cRow = L"#" + std::to_wstring(player.id) + L"  " + player.name;
        SendMessageW(list, LB_ADDSTRING, 0, reinterpret_cast<LPARAM>(cRow.c_str()));
    }
    if (cSelected != LB_ERR && cSelected < static_cast<LRESULT>(g.players.size()))
        SendMessageW(list, LB_SETCURSEL, cSelected, 0);
    EnableWindow(Item(kKick), g.running && !g.players.empty());
}

void ReaderThread(HANDLE aStdout, HWND aWindow)
{
    std::string pending;
    char buffer[4096];
    DWORD read = 0;
    while (ReadFile(aStdout, buffer, sizeof(buffer), &read, nullptr) && read)
    {
        pending.append(buffer, read);
        for (size_t newline; (newline = pending.find('\n')) != std::string::npos;)
        {
            std::string line = pending.substr(0, newline);
            pending.erase(0, newline + 1);
            if (!line.empty() && line.back() == '\r')
                line.pop_back();
            PostMessageW(aWindow, WM_SERVER_LINE, 0, reinterpret_cast<LPARAM>(new std::string(std::move(line))));
        }
    }
    CloseHandle(aStdout);
    PostMessageW(aWindow, WM_SERVER_EXIT, 0, 0);
}

void StartServer()
{
    if (!SaveSettings())
        return;
    SECURITY_ATTRIBUTES inherit{sizeof(inherit), nullptr, TRUE};
    HANDLE stdinRead{}, stdoutRead{}, stdoutWrite{};
    if (!CreatePipe(&stdinRead, &g.stdinWrite, &inherit, 0) || !CreatePipe(&stdoutRead, &stdoutWrite, &inherit, 0))
        return;
    SetHandleInformation(g.stdinWrite, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(stdoutRead, HANDLE_FLAG_INHERIT, 0);

    STARTUPINFOW startup{sizeof(startup)};
    startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdInput = stdinRead;
    startup.hStdOutput = stdoutWrite;
    startup.hStdError = stdoutWrite;
    std::wstring commandLine = L"\"" + (g.serverDir / L"SkyrimTogetherServer.exe").wstring() + L"\"";
    const BOOL cStarted = CreateProcessW(nullptr, commandLine.data(), nullptr, nullptr, TRUE, CREATE_NO_WINDOW, nullptr,
                                         g.serverDir.c_str(), &startup, &g.process);
    CloseHandle(stdinRead);
    CloseHandle(stdoutWrite);
    if (!cStarted)
    {
        CloseHandle(stdoutRead);
        CloseHandle(g.stdinWrite);
        MessageBoxW(g.window, L"Couldn't start SkyrimTogetherServer.exe.", kTitle, MB_ICONERROR);
        return;
    }
    g.running = true;
    g.players.clear();
    std::thread(ReaderThread, stdoutRead, g.window).detach();
    SetTimer(g.window, kPollTimer, kPollMs, nullptr);
    AppendLog(L"--- server starting ---");
    UpdateUi();
}

void StopServer()
{
    if (!g.running)
        return;
    SendCommand("/quit");
    if (WaitForSingleObject(g.process.hProcess, 5000) != WAIT_OBJECT_0)
        TerminateProcess(g.process.hProcess, 0);
}

void OnServerExit()
{
    KillTimer(g.window, kPollTimer);
    if (g.process.hProcess)
    {
        CloseHandle(g.process.hProcess);
        CloseHandle(g.process.hThread);
    }
    if (g.stdinWrite)
        CloseHandle(g.stdinWrite);
    g.process = {};
    g.stdinWrite = nullptr;
    g.running = false;
    g.players.clear();
    AppendLog(L"--- server stopped ---");
    UpdateUi();
}

// /players answers: "<------Players-(2)--->" then "1: Name" lines, or "No players on here..."
void OnServerLine(const std::string& acLine)
{
    static const std::regex kHeader(R"(<-+Players-\((\d+)\)-+>)");
    static const std::regex kRow(R"((?:^|\] )(\d+): (.+)$)");
    std::smatch match;
    if (acLine.find("No players on here") != std::string::npos)
    {
        g.players.clear();
        g.readingPlayers = false;
        UpdateUi();
        return;
    }
    if (std::regex_search(acLine, match, kHeader))
    {
        g.pendingPlayers.clear();
        g.readingPlayers = true;
        if (std::stoul(match[1]) == 0)
            g.readingPlayers = false;
        return;
    }
    if (g.readingPlayers && std::regex_search(acLine, match, kRow))
    {
        g.pendingPlayers.push_back({static_cast<unsigned>(std::stoul(match[1])), Widen(match[2])});
        g.players = g.pendingPlayers;
        UpdateUi();
        return;
    }
    g.readingPlayers = false;
    AppendLog(Widen(acLine));
}

void CopyInvite()
{
    const std::wstring cPort = Text(kPort);
    const auto cLocal = LocalAddresses();
    std::wstring text = L"Skyrim Together: press F2 in game, then connect to ";
    text += g.publicIp.empty() ? (cLocal.empty() ? L"?" : cLocal.front()) : g.publicIp;
    text += L":" + cPort;
    if (const std::wstring cPassword = Text(kPassword); !cPassword.empty())
        text += L"  password: " + cPassword;
    if (!OpenClipboard(g.window))
        return;
    EmptyClipboard();
    HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, (text.size() + 1) * sizeof(wchar_t));
    memcpy(GlobalLock(memory), text.c_str(), (text.size() + 1) * sizeof(wchar_t));
    GlobalUnlock(memory);
    SetClipboardData(CF_UNICODETEXT, memory);
    CloseClipboard();
    SetWindowTextW(Item(kCopy), L"Copied!");
}

HWND Add(const wchar_t* apClass, const wchar_t* apText, DWORD aStyle, int x, int y, int w, int h, int aId)
{
    HWND control = CreateWindowExW(0, apClass, apText, WS_CHILD | WS_VISIBLE | aStyle, x, y, w, h, g.window,
                                   reinterpret_cast<HMENU>(static_cast<INT_PTR>(aId)), nullptr, nullptr);
    SendMessageW(control, WM_SETFONT, reinterpret_cast<WPARAM>(g.font), TRUE);
    return control;
}

void CreateControls()
{
    constexpr int kLeft = 16, kField = 150, kFieldWidth = 330;
    int y = 16;
    auto row = [&](const wchar_t* apLabel, int aId, DWORD aStyle)
    {
        Add(L"STATIC", apLabel, 0, kLeft, y + 3, kField - kLeft, 20, -1);
        Add(L"EDIT", L"", WS_BORDER | WS_TABSTOP | ES_AUTOHSCROLL | aStyle, kField, y, kFieldWidth, 24, aId);
        y += 32;
    };
    row(L"Server name", kName, 0);
    row(L"Password", kPassword, 0);
    row(L"Max players", kMaxPlayers, ES_NUMBER);
    row(L"Port (UDP)", kPort, ES_NUMBER);
    Add(L"BUTTON", L"Allow PvP", BS_AUTOCHECKBOX | WS_TABSTOP, kField, y, 110, 22, kPvp);
    // Friends take over your quests, cleared dungeons and dead NPCs, and start next to you
    Add(L"BUTTON", L"Friends join my world", BS_AUTOCHECKBOX | WS_TABSTOP, kField + 120, y, kFieldWidth - 120, 22, kHostWorld);
    y += 34;
    Add(L"BUTTON", L"Start server", BS_DEFPUSHBUTTON | WS_TABSTOP, kLeft, y, 150, 32, kStartStop);
    Add(L"BUTTON", L"Copy invite", WS_TABSTOP, kLeft + 160, y, 150, 32, kCopy);
    y += 44;
    Add(L"STATIC", L"Stopped", 0, kLeft, y, 480, 20, kStatus);
    y += 24;
    Add(L"STATIC", L"", 0, kLeft, y, 480, 40, kAddresses);
    y += 48;
    Add(L"STATIC", L"Players", 0, kLeft, y, 200, 20, -1);
    y += 22;
    Add(L"LISTBOX", L"", WS_BORDER | WS_VSCROLL | LBS_NOTIFY, kLeft, y, 360, 120, kPlayers);
    Add(L"BUTTON", L"Kick", WS_TABSTOP, kLeft + 370, y, 110, 32, kKick);
    y += 128;
    Add(L"STATIC", L"Server log", 0, kLeft, y, 200, 20, -1);
    y += 22;
    Add(L"EDIT", L"", WS_BORDER | WS_VSCROLL | ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL, kLeft, y, 480, 150, kLog);
}

LRESULT CALLBACK WindowProc(HWND aWindow, UINT aMessage, WPARAM aWParam, LPARAM aLParam)
{
    switch (aMessage)
    {
    case WM_CREATE:
        g.window = aWindow;
        CreateControls();
        LoadSettings();
        UpdateAddresses();
        UpdateUi();
        FetchPublicIp(aWindow);
        return 0;
    case WM_COMMAND:
        switch (LOWORD(aWParam))
        {
        case kStartStop:
            g.running ? StopServer() : StartServer();
            return 0;
        case kKick:
        {
            const LRESULT cIndex = SendMessageW(Item(kPlayers), LB_GETCURSEL, 0, 0);
            if (cIndex == LB_ERR || cIndex >= static_cast<LRESULT>(g.players.size()))
            {
                MessageBoxW(aWindow, L"Select a player first.", kTitle, MB_ICONINFORMATION);
                return 0;
            }
            const Player cPlayer = g.players[cIndex];
            if (MessageBoxW(aWindow, (L"Kick " + cPlayer.name + L"?").c_str(), kTitle, MB_YESNO | MB_ICONQUESTION) == IDYES)
            {
                SendCommand("/kick " + std::to_string(cPlayer.id));
                SendCommand("/players");
            }
            return 0;
        }
        case kCopy:
            CopyInvite();
            return 0;
        case kPort:
            if (HIWORD(aWParam) == EN_CHANGE)
                UpdateAddresses();
            return 0;
        }
        break;
    case WM_TIMER:
        if (aWParam == kPollTimer)
        {
            SendCommand("/players");
            SetWindowTextW(Item(kCopy), L"Copy invite");
        }
        return 0;
    case WM_SERVER_LINE:
    {
        std::unique_ptr<std::string> line(reinterpret_cast<std::string*>(aLParam));
        OnServerLine(*line);
        return 0;
    }
    case WM_SERVER_EXIT:
        OnServerExit();
        return 0;
    case WM_PUBLIC_IP:
    {
        std::unique_ptr<std::wstring> ip(reinterpret_cast<std::wstring*>(aLParam));
        g.publicIp = *ip;
        UpdateAddresses();
        return 0;
    }
    case WM_CLOSE:
        if (g.running)
        {
            const std::wstring cAsk = g.players.empty() ? L"Stop the server and close?"
                                                        : std::to_wstring(g.players.size()) + L" player(s) are connected. Stop the server and close?";
            if (MessageBoxW(aWindow, cAsk.c_str(), kTitle, MB_YESNO | MB_ICONQUESTION) != IDYES)
                return 0;
            StopServer();
        }
        DestroyWindow(aWindow);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(aWindow, aMessage, aWParam, aLParam);
}
} // namespace

int WINAPI wWinMain(HINSTANCE aInstance, HINSTANCE, PWSTR, int aShow)
{
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    INITCOMMONCONTROLSEX controls{sizeof(controls), ICC_STANDARD_CLASSES};
    InitCommonControlsEx(&controls);

    g.serverDir = FindServerDir();
    if (g.serverDir.empty())
    {
        MessageBoxW(nullptr, L"SkyrimTogetherServer.exe wasn't found. Keep this program in the unzipped release folder.", kTitle, MB_ICONERROR);
        return 1;
    }

    NONCLIENTMETRICSW metrics{sizeof(metrics)};
    SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0);
    g.font = CreateFontIndirectW(&metrics.lfMessageFont);

    WNDCLASSW windowClass{};
    windowClass.lpfnWndProc = WindowProc;
    windowClass.hInstance = aInstance;
    windowClass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    windowClass.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_BTNFACE + 1);
    windowClass.lpszClassName = L"SkyrimTogetherHost";
    windowClass.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    RegisterClassW(&windowClass);

    RECT size{0, 0, 512, 700};
    AdjustWindowRect(&size, WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX, FALSE);
    CreateWindowW(windowClass.lpszClassName, kTitle, WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX, CW_USEDEFAULT,
                  CW_USEDEFAULT, size.right - size.left, size.bottom - size.top, nullptr, nullptr, aInstance, nullptr);
    ShowWindow(g.window, aShow);

    MSG message;
    while (GetMessageW(&message, nullptr, 0, 0))
    {
        if (!IsDialogMessageW(g.window, &message))
        {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
    }
    return 0;
}
