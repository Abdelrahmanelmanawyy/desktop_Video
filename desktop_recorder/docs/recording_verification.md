# Recording Verification Checklist

The FFmpeg-based recorder is integrated on Windows. Replace the placeholder
executables in `assets/bin/` with the real `ffmpeg.exe` and (optionally)
`ffprobe.exe` builds compiled for Windows x64 before running the app.

## Prep
- Run `flutter pub get` (already done) and rebuild the Windows app.
- Launch the app, sign in, then open `Camera Record`.
- Use **Detect devices** to populate DirectShow video and audio devices.
- Select the desired camera and microphone before starting a recording.

## Phase 1 Tests (run on the kiosk PC)
- Record 10 clips back-to-back; confirm each MP4 is generated.
- Record a full 90-second capture; confirm automatic stop at 90 seconds.
- Start another recording and stop it after ~5–10 seconds.
- Disconnect the network and record a clip; file should still be saved.
- Reboot the PC, open the app again, and record another clip.
- Open the recording folder (`AppData/Roaming/<app>/recordings`) and play each MP4 in VLC (H.264 video + AAC audio).

## Troubleshooting notes
- Check the in-app logs panel for FFmpeg output; failures are also appended to `AppData/Roaming/<app>/logs/recorder.log`.
- If **Detect devices** returns empty lists, verify the camera or microphone are enabled in Windows Device Manager and not claimed by another process.
- When FFmpeg cannot start (e.g., device busy), replace the selection or reboot to release the handle, then retry.
