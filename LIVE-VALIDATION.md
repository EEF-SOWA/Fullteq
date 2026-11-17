# Ableton Live 12.4.6 Host Validation

- Date: 2026-11-17 17:26 KST
- Commit: `29fd2b9`
- Host: Ableton Live 12.4.6 (`2026-09-10_0de5c8fa9a`), CoreAudio, 48000 Hz, 256 samples output buffer
- VST3 binary SHA-256 (`~/Library/Audio/Plug-Ins/VST3/Fullteq.vst3/Contents/MacOS/Fullteq`): `74766161b341f08090da7812a03d8f3fac9f2dfcf7db61ab9d5810887dfe39da`
- AU binary SHA-256 (`~/Library/Audio/Plug-Ins/Components/Fullteq.component/Contents/MacOS/Fullteq`): `c7dbd132961403ca4360c37f8f0b51460514f221c9ef432d821b02a3f9287302`

## Verified

- **Load & binary binding**: Loaded both `Fullteq` VST3 (track `3-Audio`) and AUv2 (track `4-Audio`) via `ableton-cli`. `lsof -p 12705` confirmed the Live process mapped both newly built bundles above.
- **Parameter enumeration & round-trip**: Enumerated 18 VST3 parameters (including `Program`) and 17 AUv2 parameters. Verified write/read-back on VST3 (`Low Boost` `0.4` → `8.00 dB`, `Drive` `0.55` → `55 %`) and AUv2 (`Low Boost` `0.4`, `Low Frequency` `0.0` → `20 Hz`).
- **Audio pass-through**: Played a 48 kHz `-12 dBFS` 1 kHz stereo WAV through both instances; track meters and master meter registered active signal (VST3 track peak `0.7545`, AUv2 track peak `0.6135`, master peak `0.8383`).
- **Format & DSP gates (same binaries)**: `FullteqTests` 16 groups PASS (0 failures), `pluginval --strictness-level 10` PASS on both VST3 and AU, `auval -v aufx Fteq EEFL` PASS.

## Unavailable / Not tested

- Timeline automation envelopes, save/reopen state recall in a saved `.als` set (`song save` is unsupported by the Live script API), and blind listening comparison: `unavailable`.
