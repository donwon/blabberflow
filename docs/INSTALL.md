# Install Blabberflow on your Mac

## Requirements

- macOS 13 Ventura or later.
- An Apple Silicon (M-series) or Intel Mac. The download is a universal app.
- A microphone and macOS permission to use it.

**Early experimental release:** Blabberflow has an ad-hoc local signature, not an Apple Developer ID signature, and has not been notarized by Apple. macOS may block the first launch. If you prefer Apple-verified software, wait for a signed, notarized release. There is no Windows version yet.

## 1. Download and install

1. [Download Blabberflow for Mac](https://github.com/donwon/blabberflow/releases/download/v0.3.1/Blabberflow-0.3.1-universal.dmg).
2. Open the downloaded `.dmg` file.
3. Drag **Blabberflow** onto **Applications** in that window. If your Mac requires an administrator account and you don't have one, copy the app into your own `~/Applications` folder instead.
4. Eject the Blabberflow disk image, then open **Blabberflow from Applications**. Grant permissions to this installed copy, not the one inside the disk image.

[ZIP download instead](https://github.com/donwon/blabberflow/releases/download/v0.3.1/Blabberflow-0.3.1-universal.zip): double-click to extract, then move Blabberflow.app to Applications before opening it.

### If macOS blocks the app

For this non-notarized experimental build, macOS may say the developer cannot be verified or Apple cannot check the app. If you choose to trust this release after reviewing the source and release notes, Apple provides an app-specific exception:

1. Attempt to open the installed Blabberflow app once.
2. Open **System Settings → Privacy & Security**.
3. Find the message about Blabberflow and choose **Open Anyway**, if macOS offers it, then confirm.

[Read Apple's explanation of these security checks](https://support.apple.com/en-us/102445). Managed computers may not permit this exception. Do not disable Gatekeeper or remove quarantine through Terminal. If macOS reports malware or a damaged app, stop and report the exact message; do not treat that as the ordinary developer-verification prompt.

## 2. Enable the three permissions

| Permission | Where to enable it | Why it is needed |
|---|---|---|
| Microphone | Allow the recording prompt, or System Settings → Privacy & Security → Microphone | Hear your dictation |
| Speech Recognition | Allow the speech prompt, or Privacy & Security → Speech Recognition | Turn speech into words |
| Accessibility | Privacy & Security → Accessibility → enable Blabberflow | Use the global shortcut and insert into another app |

Start the installed app and use its Home/Settings permission buttons to request access. In Accessibility, use the **+** button to add the installed Blabberflow.app if it is missing. After changing permissions, quit Blabberflow from its menu-bar menu and reopen it if necessary.

## 3. Try your first dictation

1. Open Notes and click in a new note.
2. Hold **Control + Shift** together until Blabberflow says **Listening**.
3. Say a short sentence while holding the keys.
4. Release both keys and keep the note selected until the words arrive.

Use a short test in Notes before trying a browser or another editor. You can recover text using **Copy** in Blabberflow if automatic insertion fails. Each recording is limited to about 55 seconds.

## Change the shortcut

In Blabberflow → Settings, choose a supported modifier combination or **Fn / Globe**, then click **Apply shortcut**. If Fn triggers Apple's emoji picker or Dictation too, review **System Settings → Keyboard → Press Fn / Globe key to** and Apple's Dictation shortcut. Some keyboards handle Fn internally; choose Control + Shift or another modifier combination if Fn does not work.

## Keep recognition on the Mac

Enable **on-device-only** in Blabberflow Settings if you want to require local recognition. Support depends on the Mac, language and available speech resources. If unsupported, Blabberflow refuses to record with that setting enabled. If the setting is off, Apple may process speech online. No separate paid transcription API key is needed.

## Troubleshooting

- **It records, but nothing appears in another app:** verify Accessibility, click the destination field, and keep it selected through completion. Try Notes first. Some editors require manual paste.
- **The shortcut also opens another app:** change Blabberflow's shortcut or the other app's shortcut. Modifier-only shortcuts cannot be reserved exclusively.
- **Permissions stopped working after an update:** quit the app, remove its old Accessibility entry, add the installed copy again, and relaunch. Use the same installed location.
- **It says “Paste sent,” but the field is empty:** that status confirms an event was sent, not that the editor accepted it. Recover the transcript with Copy and paste manually.
- **You cannot install it on a work Mac:** your administrator may restrict non-notarized apps or Accessibility access.

## Updating and removing

Quit Blabberflow before replacing its app in Applications with a newer download. There is no automatic updater yet. Re-check permissions after an update. Preferences, optional history and vocabulary are separate from the app bundle and are not deleted by replacing it.

To uninstall, quit from the menu bar and move Blabberflow.app to Trash. To remove saved transcripts, use History → Delete all before uninstalling. Optional app data lives at `~/Library/Application Support/WhisperFlow/`.

## For developers: build it yourself

Install Xcode Command Line Tools if needed by running `xcode-select --install` in Terminal and completing Apple's installer. Then:

```sh
git clone https://github.com/donwon/blabberflow.git
cd blabberflow
swift test
bash scripts/build.sh
open dist
```

Move the resulting app into Applications and follow the same permission setup. To build a universal app instead, use `bash scripts/build.sh --universal`.
