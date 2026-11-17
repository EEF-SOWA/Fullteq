# Fullteq Validation Evidence

## Current Universal 2 Build (`x86_64` + `arm64`, macOS 11.0+)

- Date: 2026-11-17 17:57 KST
- VST3 binary SHA-256 (`~/Library/Audio/Plug-Ins/VST3/Fullteq.vst3/Contents/MacOS/Fullteq`): `6cebfcf906f6e928b98caa778119acf1122f1301bf615520372190f16576247f`
- AU binary SHA-256 (`~/Library/Audio/Plug-Ins/Components/Fullteq.component/Contents/MacOS/Fullteq`): `0634ed292a66dc2bc672c8fb71fadfd5e3f28e3b0492e4c9d9bcfec08b6b4582`
- `FullteqTests`: 20 test groups PASS (0 failures), including `releaseResources()` followed by `processBlock()`, `IN` vs `POWER` separation, multi-rate adaptive oversampling (44.1 / 96 / 192 kHz), preset invalidation/restore, and hot-drive ADAA1 aliasing (`-67.7 dB`).
- `pluginval --strictness-level 10`: PASS on both VST3 and AU.
- `auval -v aufx Fteq EEFL`: PASS.
- `FullteqTests --snapshot`: PASS (2280×760).
- Ableton Live 12.4.6 load on this Universal 2 build: `unavailable` (Ableton Live is actively running another workspace test session, so Live was not restarted or modified).

## Earlier Ableton Live 12.4.6 Host Load (`29fd2b9`, `arm64`)

- Date: 2026-11-17 17:26 KST
- Host: Ableton Live 12.4.6 (`2026-09-10_0de5c8fa9a`), CoreAudio, 48000 Hz, 256 samples output buffer
- VST3 binary SHA-256: `74766161b341f08090da7812a03d8f3fac9f2dfcf7db61ab9d5810887dfe39da`
- AU binary SHA-256: `c7dbd132961403ca4360c37f8f0b51460514f221c9ef432d821b02a3f9287302`
- **Load & binary binding**: Loaded both `Fullteq` VST3 (track `3-Audio`) and AUv2 (track `4-Audio`) via `ableton-cli`. `lsof -p 12705` confirmed the Live process mapped both newly built bundles above.
- **Parameter enumeration & round-trip**: Enumerated 18 VST3 parameters (including `Program`) and 17 AUv2 parameters. Verified write/read-back on VST3 (`Low Boost` `0.4` → `8.00 dB`, `Drive` `0.55` → `55 %`) and AUv2 (`Low Boost` `0.4`, `Low Frequency` `0.0` → `20 Hz`).
- **Audio pass-through**: Played a 48 kHz `-12 dBFS` 1 kHz stereo WAV through both instances; track meters and master meter registered active signal (VST3 track peak `0.7545`, AUv2 track peak `0.6135`, master peak `0.8383`).

## Unavailable / Not tested

- Timeline automation envelopes, save/reopen state recall in a saved `.als` set (`song save` is unsupported by the Live script API), Developer ID notarization, Windows build, and blind listening comparison: `unavailable`.
