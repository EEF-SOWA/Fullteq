# Fullteq Validation Evidence

## 0.9.0 beta release (2026-11-18)

- Build: macOS 11+, Universal 2 (`arm64` and `x86_64`), version 0.9.0.
- Release package: `Fullteq-0.9.0-macOS-universal.zip`
- ZIP SHA-256: `3cabea31cbf68d1b04e5b39d9b9a3651bbff3d7beba85114c1f66f207bb641a4`
- VST3 binary SHA-256: `363bdbd0d3110eba698c8eba50e7b9a8c723c226005104fabc745682d0e5ed80`
- AU binary SHA-256: `ab453337c50f7a55e4b9a352cd1505d8d301a9798ad0f2db0fd8ac2dba6f4ac7`
- Standalone binary SHA-256: `d55c2f637678803ca2efbdb318711bfdf5f7426b3540a943cdcb259035147f3b`

### Offline and format gates

- `FullteqTests`: all tests pass, 0 failures. Coverage includes 44.1, 48,
  88.2, 96, and 192 kHz, block-size changes, NaN and Inf input, bypass,
  presets, DC blocking, aliasing, hysteresis, and TUBE/XFMR ramps.
- `pluginval --strictness-level 10` on the packaged VST3: SUCCESS.
- `auval -v aufx Fteq EEFL`: PASS.
- `FullteqTests --snapshot`: PASS (2280x760).
- `codesign --verify --deep --strict`: PASS for VST3, AU, and Standalone.
- Signature: ad-hoc. No Developer ID certificate and no notarization ticket.

### Ableton Live 12.4.6 host check

- Host: Ableton Live 12.4.6, CoreAudio, 48000 Hz, 256-sample output buffer.
- VST3: loaded on a temporary MIDI track after Drift. 18 parameters. Low Boost
  `0.4` read back as `8.00 dB`; Drive `0.55` read back as `55 %`. Track meter
  peak was 0.56 while the clip played.
- AU: loaded on a second temporary MIDI track after Drift. 17 parameters. Low
  Boost `0.4` and Drive `0.60` read back as `0.40` and `0.60`. Track meter peak
  was 0.55 while the clip played.
- Both temporary tracks were deleted and the transport returned to beat 0.

### Not tested

- macOS 11 on real hardware. The minimum is declared but not exercised.
- Apple Silicon and Intel hardware separately. Only the Universal binary was
  checked with `lipo`.
- DAWs other than Ableton Live 12.4.6.
- Timeline automation recall and save/reopen state in a saved Live Set.
- Developer ID signing and notarization.
- Windows and AAX.
