# iOS AOI Replay PiP (In-Game Highlight & Floating Replay Engine)

Hardware-accelerated instant replay and floating picture-in-picture viewer for iOS mobile MOBAs (such as Arena of Valor / Liên Quân Mobile).

## Architecture
- **Broadcast Upload Extension (`ReplayKit`)**: Ingests OS-level screen buffer without modifying target game binaries.
- **Hardware Ring Buffer (`VideoToolbox`)**: H.264 Baseline encoding on GPU with rolling 30-second memory cache.
- **Floating Overlay (`AVKit` + `AVSampleBufferDisplayLayer`)**: Employs native iOS Picture-in-Picture subsystem (iOS 15.0+) for zero-ban, out-of-process overlay execution.

## Automatic GitHub Actions Build
The `.github/workflows/build_ios_replay_pip.yml` compiles on `macos-latest` using `xcodegen` and packages an ad-hoc signed `.ipa` ready for TrollStore, Sideloadly, or AltStore.
