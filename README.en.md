# LegacyTV Live

A lightweight IPTV player for Android 4.4+ TVs and TV boxes.

## Features

- Android 4.4+ support, including an ARM32/ARM64 universal build
- Uses the auto-updating [ChinaIPTV](https://github.com/hujingguang/ChinaIPTV) M3U by default:
  `https://raw.githubusercontent.com/hujingguang/ChinaIPTV/main/cnTV_AutoUpdate.m3u8`
- Tries direct, ghfast, and ghproxy.net source endpoints in parallel, with cached playback when the network is unavailable
- GitHub upstream requests include a fixed-host compatibility path for Android 4.4 CA stores
- Supports M3U/M3U8, TVBox text playlists, and custom subscriptions
- Automatically tries another URL for a channel when playback fails
- D-pad, number-key, and OK-key navigation for TV remotes
- Software decoding is enabled by default on Android 4.4 to avoid unstable vendor MediaCodec implementations
- No ads or account; the default ChinaIPTV playlist does not enable third-party EPG

ChinaIPTV maintains the playlist upstream. This repository references the remote playlist and does not copy channel data. Availability depends on the TV network and the upstream playlist status.

## Install

Download `LegacyTV.apk` (includes armeabi-v7a and arm64-v8a) from Releases or Actions artifacts and install it through USB, a file manager, or ADB. The original application ID `com.htwmedia.htv` is retained so an existing HTV installation can be upgraded.

## Settings

- **Runtime status** shows software decoding, source loading, and cache state
- Edit or clear the default URL under **Live source → Default source service**
- Add your own M3U/TXT subscription under **Custom live source**
- The app keeps the previous cache when a refresh fails
- **Debug and logs → LAN debug** shows the address and QR code. A LAN debug service starts at port `10381`: use `/api/logs.txt` for plain text, `/api/logs` for JSON, `/api/status` for player state, and `/api/debug/*` for reserved remote player diagnostics

## Build

Requires Flutter 3.13+ and the Android SDK:

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

## License

The application code remains Apache-2.0. ChinaIPTV is an independent upstream project; follow its documentation and the applicable rules for channel content when using its playlist.
