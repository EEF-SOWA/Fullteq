# Fullteq Manual

## Signal path

```text
input gain -> five-stage passive EQ -> tube stage -> transformer -> output gain
```

The tube and transformer stages run at about 176.4 or 192 kHz internally. The
host sees the reported oversampler latency, and the dry path is delayed to
match it for bypass comparison.

## Low band

`CPS` selects 20, 30, 60, or 100 Hz. `LOW BOOST` is a wide shelf with a fixed
700 Hz corner. `LOW ATTEN` is a cut shelf whose corner follows the CPS dial.
Use both for the classic low-end trick: a lift below the boost corner and a dip
above it.

## High band

`KCS` selects 3, 4, 5, 8, 10, 12, or 16 kHz. `HIGH BOOST` is a resonant peak.
`BANDWIDTH` moves from SHARP at 0 to BROAD at 10. `HIGH ATTEN` is a shelf cut at
the `ATTEN SEL` frequency: 5, 10, or 20 kHz.

## Color stages

`DRIVE` controls both the tube and transformer stages. `TUBE` adds asymmetric
triode saturation. `XFMR` adds low-frequency core saturation, hysteresis, and
high-frequency iron loss.

`IN` removes only the passive EQ network. This keeps the tube and transformer
available as a color stage. `POWER` bypasses the complete processor against the
latency-aligned dry signal.

## Presets

The program menu contains Init, Low Trick, Deep Sub Lift, Vocal Presence,
Master Glue, Bright Air, Tame Harsh, and Tube Warmth. A manual knob change marks
the current program as custom.

## Install and remove

Run `Install Fullteq.command` from the release ZIP. The installer writes only to
the current user's folders:

- `~/Library/Audio/Plug-Ins/VST3/Fullteq.vst3`
- `~/Library/Audio/Plug-Ins/Components/Fullteq.component`
- `~/Applications/Fullteq.app`

Run `Uninstall Fullteq.command` to remove those three items.

## Gatekeeper

The beta is ad-hoc signed and not notarized. For the Standalone app, right-click
and choose Open. For a plug-in that a host refuses to load, read `INSTALL.txt`
and remove the quarantine attribute for the installed bundle. The command is
listed there with the exact path.

## Troubleshooting

- If a host does not list Fullteq, confirm that the bundle is in the per-user
  plug-in folder and restart the host.
- If the UI reports a missing program, select a factory preset again.
- If the Standalone app is blocked, use the Gatekeeper steps above.
