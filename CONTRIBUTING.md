# Contributing

Blabberflow is an early macOS utility. Bug reports and focused improvements are welcome.

For a bug report, include macOS version, selected language, shortcut, destination app, and steps to reproduce. Describe which permissions are enabled. Do not include private dictation, recordings, account details, or credentials. Redact screenshots and diagnostic files before attaching them.

Run `swift test` and `bash scripts/build.sh` before proposing code changes. Permission handling, microphone recognition, and real cross-app insertion also require interactive checks; unit tests alone do not verify them.

Keep changes scoped. Preserve the user's chosen shortcut, vocabulary and history. Never silently fall back to online speech recognition when on-device-only was requested.

Contributions are provided under this repository's MIT license.
