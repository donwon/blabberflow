# Blabberflow for Mac

Hold a shortcut, speak, and release to put your words into the text field you’re using.

Blabberflow is an experimental native macOS dictation utility built with SwiftUI and Apple Speech. It supports cross-app insertion, configurable hold shortcuts, custom vocabulary, and optional local transcript history. No app account, subscription, or paid transcription API key is required.

## Download and install

**[⬇ Download Blabberflow for Mac](https://github.com/donwon/blabberflow/releases/download/v0.3.1/Blabberflow-0.3.1-universal.dmg)**

macOS 13+ · Apple Silicon and Intel · Experimental v0.3.1

1. Download and open the DMG.
2. Drag **Blabberflow** to **Applications**, eject the disk image, and launch the installed app.
3. Allow **Microphone**, **Speech Recognition**, and **Accessibility**.
4. Click a text field, hold **Control + Shift**, speak, then release the keys.

**This early build is not Developer ID signed or notarized by Apple.** macOS may block the first launch. Read [the installation guide](docs/INSTALL.md#if-macos-blocks-the-app) before deciding whether to open it. A signed, notarized release is still planned; this is not a Mac App Store release.

[Step-by-step setup and troubleshooting](docs/INSTALL.md) · [ZIP download](https://github.com/donwon/blabberflow/releases/download/v0.3.1/Blabberflow-0.3.1-universal.zip) · [Release notes and checksums](https://github.com/donwon/blabberflow/releases/tag/v0.3.1)

**Windows is not supported yet.** No Xcode or Terminal is needed for the download above.

Independent software. Not affiliated with Wispr Flow. Despite earlier internal names, transcription uses **Apple Speech**, not OpenAI Whisper.

## Build from source (optional)

Requires macOS 13 or later, Xcode Command Line Tools, and Swift 5.8 or later. No external package dependencies.

```sh
git clone https://github.com/donwon/blabberflow.git
cd blabberflow
swift test
bash scripts/build.sh
open 'dist/Blabberflow.app'
```

For regular use, move the built app into your Applications folder and launch that copy before granting permissions. The build script applies an ad-hoc local signature. Rebuilding may require granting permissions again.

## Use

1. Allow Microphone and Speech Recognition when prompted. Enable Blabberflow under System Settings → Privacy & Security → Accessibility for global shortcuts and insertion.
2. Click the text field you want to write in.
3. Hold **Control + Shift** until Listening appears.
4. Speak, release the shortcut, and keep the field selected while recognition finishes.

Settings supports Fn / Globe alone and supported combinations of two or three modifier keys. Control + Shift is the default. The listener observes keys without reserving them exclusively, so shortcuts used by other apps can overlap.

If Fn also starts an Apple action, review System Settings → Keyboard → Press Fn / Globe key to and Apple Dictation shortcuts. Blabberflow does not change these settings. Some keyboards do not expose Fn events; use a modifier combination on those keyboards.

For hands-free recording, start with Try dictation or the menu bar, select the destination field, and finish from the floating panel. Closing the main window leaves the menu-bar app running.

## Features

- Hold to record; release to finish and insert.
- Apple Speech recognition, language selection, and an on-device-only setting.
- Nonactivating recording panel with microphone level, finish, and cancel controls.
- Clipboard paste for Chromium/Electron editors; direct Accessibility insertion with paste fallback for compatible native fields.
- Vocabulary hints and whole-word phrase replacements.
- Optional conservative filler removal; no LLM sentence rewriting.
- Optional local history, search, copy, and deletion. History defaults off and retains up to 200 dictations.

## Privacy

With **on-device-only** enabled, recognition must be supported on the Mac for the selected language; otherwise recording refuses to start. With it disabled, Apple may process speech online. Do not assume all recognition is local merely because no API key is required.

The app does not save audio. Optional history and vocabulary are stored under `~/Library/Application Support/WhisperFlow/` with owner-only file permissions. Preferences use macOS UserDefaults. The legacy internal names preserve compatibility with earlier local builds.

A bounded `runtime-status.json` stores delivery, destination app/field role, permission, and shortcut status for troubleshooting, without transcript text or audio. The latest transcript remains in memory until quit. Copied dictation remains on the system clipboard.

## Limitations and troubleshooting

- Sessions stop at about 55 seconds. Long-form dictation, contextual rewriting, command mode, mobile sync, and login launch are not implemented.
- Automatic insertion depends on Accessibility permission and a compatible field. Keep the destination selected. If focus changes or insertion fails, recover the transcript with Copy and paste manually.
- “Paste sent” means the keyboard event was dispatched; it does not confirm that every editor accepted it. Unusual editors may need manual paste.
- Text delivery into secure/password fields is intentionally avoided.
- If a rebuilt app loses Accessibility access, remove its old entry, add the current app copy, and relaunch.

## Development

`Sources/FlowCore` contains vocabulary processing, delivery decisions, shortcut state, and completion logic. `Sources/WhisperFlow` contains the macOS app and integrations. Tests cover these state transitions and delivery decisions. Live microphone recording and cross-app behavior still need interactive testing on each supported setup.

The executable target and bundle identifier retain their original internal names. The visible app name is Blabberflow.

To reproduce the universal DMG, ZIP and SHA-256 checksums, run `bash scripts/package-release.sh` on a Mac with Xcode installed. Files are written to `dist/releases/`. This packaging script uses an ad-hoc signature; it does not perform Apple notarization.

See [contributing](CONTRIBUTING.md) and [the project directory](https://github.com/donwon/open-source).

## License

[MIT](LICENSE) — Copyright 2026 Don Wong. You may use, modify, and redistribute the code, including commercially, subject to the license.
