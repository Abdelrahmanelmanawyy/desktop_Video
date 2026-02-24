# Soft Kiosk Setup

For controlled environments, the app can run as a soft kiosk: fullscreen, always on top, with Explorer hidden. `starter.bat` restarts the app if it closes and restores Explorer when kiosk mode ends.

## Deployment

1. **Build the app**
   ```bash
   flutter build windows
   ```

2. **Create the kiosk folder** (e.g. `C:\KioskApp\`)

3. **Copy files**
   - `build\windows\x64\runner\Release\desktop_recorder.exe` → `C:\KioskApp\`
   - `starter.bat` (from project root) → `C:\KioskApp\`
   - `build\windows\x64\runner\Release\*` — copy all DLLs and `data\` folder (required for the exe)

4. **Run as Administrator**
   - Right‑click `starter.bat` → Run as administrator  
   - Explorer is terminated, the app runs fullscreen, and restarts if closed

## Exiting Kiosk Mode

1. Press **Ctrl+Shift+F12**
2. Enter the admin PIN (default: `1234`)
3. Click **Exit Kiosk** — the app writes `STOP_KIOSK.txt`, exits, and the watchdog restores Explorer

## Configuration

- **Admin PIN**: Change `KioskConfig.defaultAdminPin` in `lib/config/kiosk_config.dart`
- **Paths**: `STOP_KIOSK.txt` is created in the same folder as the executable
