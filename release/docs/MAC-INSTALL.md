# Skyrim Together Plus on a Mac – install

You need an **Apple Silicon Mac** (M1 or newer) with **macOS 14** or newer, and **Skyrim Special Edition** from Steam
or GOG. Skyrim runs on the Mac through Wine (a layer that runs Windows games); SkyrimMT sets that up for you.

## 1. Set up Skyrim on the Mac (once)

1. Download **SkyrimMT** from <https://github.com/HorrorPills/skyrimmt/releases> (`SkyrimMT-app.zip`) and move it to
   Applications.
2. Open it (the first time: right-click it → **Open**), go to the **Setup** tab and click **Set up everything**. Sign
   in to Steam and confirm the Skyrim install. For the GOG version, pick **Skyrim from: GOG** first.
3. In SkyrimMT's **Mod Manager → Essentials**, install at least the **Address Library for SKSE Plugins**.

## 2. Install Skyrim Together

1. Unzip `SkyrimTogether-1.8.4-plus.5-Mac.zip` and move **Skyrim Together** to Applications.
2. Open it. The first time macOS stops it, because it isn't from the App Store: right-click it → **Open** → **Open**.
   On macOS 15 and newer, open **System Settings → Privacy & Security** and click **Open Anyway** instead.
3. The window checks your setup. Click **Install plus.5**: it downloads the game files from this release
   (about 340 MB), checks them and installs them.
4. Click **Play**.

Use the app every time you play. When a newer Plus release is out, the same button reads **Update to plus.N**.

## Hosting a game

Press **F2 → Connect → Host a game** in the game, or click **Host a Game** in the app. If the setup check says the Mac
firewall blocks Wine, click **Allow Wine…** and enter your Mac password in macOS's own window, so friends can join.

## If something goes wrong

- **Mouse or keyboard stop working** after switching apps: click **Fix Mouse & Keyboard**.
- **AirPods sound bad** once voice chat starts: pick the Mac's own microphone for voice chat (AirPods drop to
  low-quality sound while their microphone is in use).
- **Anything else:** click **Collect Logs** and send the zip it shows with your report.

Everyone in a game needs plus.5, on Windows or Mac; players on both can play together.
