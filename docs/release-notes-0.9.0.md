# Fullteq 0.9.0 Beta

The first public Fullteq beta is available for macOS 11 or later as Universal 2
VST3, AU, and Standalone.

## Install

Download `Fullteq-0.9.0-macOS-universal.zip`, verify it against
`SHA256SUMS.txt`, and run `Install Fullteq.command`. The installer writes to the
current user's plug-in folders and `~/Applications`.

The build is ad-hoc signed and not notarized. Right-click the Standalone app and
choose Open. For a plug-in that a host refuses to load, read `INSTALL.txt` and
run the documented quarantine command.

## Validation

- Offline DSP test suite: pass
- `pluginval --strictness-level 10` on VST3: pass
- `auval` on AU: pass
- Ableton Live 12.4.6: VST3 and AU load, parameters, and audio pass

Ableton Live is the only tested host. macOS 11 is the declared minimum, not a
tested operating system.

## License

Fullteq is free software under AGPLv3. The complete source is available at
<https://github.com/eefsowa-source/Fullteq>. JUCE 8.0.6 is used under AGPLv3.
The Jost typeface is used under the SIL Open Font License 1.1.
