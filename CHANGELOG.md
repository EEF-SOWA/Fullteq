# Changelog

## 0.9.0-beta - 2026-11-18

- First public macOS beta under AGPLv3.
- Universal 2 VST3, AU, and Standalone builds for macOS 11 or later.
- Five-stage passive EQ model with measured low-band turnover behavior.
- ADAA1 triode saturation and transformer hysteresis with high-frequency iron
  loss.
- Output DC blocking, click-free TUBE and XFMR ramps, and corrected hysteresis
  pitch tracking.
- Lower audio-thread CPU use through coefficient and parameter caching.
- Event-driven UI repaint and reusable response-curve buffers.
- Removed unused metering, duplicate parameter synchronization, and unused font
  data.
- Added release packaging, install and uninstall scripts, checksums, and
  release validation documentation.

### Known limitations

- The beta is not notarized and uses an ad-hoc signature.
- Ableton Live is the only tested host.
- Windows, AAX, and copy protection are not included.
