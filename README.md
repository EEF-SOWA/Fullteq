# Fullteq

Passive tube program equalizer (EQP-1A-inspired) built with JUCE 8.0.6 in VST3, AU, and Standalone formats.

## Build and test

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target FullteqTests --parallel 4
./build/FullteqTests_artefacts/Release/FullteqTests
cmake --build build --target Fullteq_VST3 Fullteq_AU Fullteq_Standalone --parallel 4
```

- macOS builds default to Universal 2 (`arm64;x86_64`) with minimum deployment target `11.0`.
- Pass `-DFULLTEQ_INSTALL_PLUGINS=OFF` to skip copying built bundles into `~/Library/Audio/Plug-Ins`.

## Architecture

Signal chain: input gain -> 5-stage passive EQ network (700 Hz low boost, dial-scaled low attenuation, resonant high boost + air shelf, high attenuation) -> ADAA1 asymmetric tube stage -> flux-coupled transformer hysteresis with HF iron loss -> output gain and latency-aligned bypass cross-fade.

- `IN` bypasses only the passive EQ network (keeping `TUBE` and `XFMR` available as an analog color box).
- `POWER` bypasses the entire processor against the latency-aligned dry path.
- Nonlinear stages target ~176.4/192 kHz internal sample rate (4x at 44.1/48 kHz, 2x at 88.2/96 kHz, 1x at 176.4/192 kHz).

## Licensing

Built against JUCE 8.0.6 (dual-licensed under AGPLv3 and JUCE commercial terms). Embedded panel typeface is Jost under the SIL Open Font License 1.1 (`Source/Fonts/OFL.txt`). Distributing closed-source binaries requires a valid JUCE commercial license and macOS Developer ID signing/notarization.
