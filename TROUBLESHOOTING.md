# Troubleshooting log

## Corne (pandakb) — controller wouldn't enumerate USB after flashing (2026-05-21)

### Symptoms

- Fast blue blink on the nice!nano after flashing `corne_left.uf2`.
- No nice!nano in `lsusb` (only the bootloader's DFU device disappeared).
- No Bluetooth advertisement, no RGB underglow, no key input.
- `settings_reset` firmware ran fine (booted, wiped NVS, returned to DFU).
- Full `corne_left` firmware crashed every time — same symptom.

### What we tried (none of these fixed it)

- Rebuilding against ZMK `main` with multiple board-target syntaxes:
  - `nice_nano`
  - `nice_nano@1.0.0`
  - `nice_nano@1.0.0//zmk` (required since ZMK PR #3145, Feb 2026)
- Pinning ZMK to `v0.3.0` (pre–Zephyr 4.1, same era our working lily58 was built against).
- Verified all UF2s had target offset `0x26000` (correct for S140 v6.1.1).
- Multiple `settings_reset` cycles, USB ports, cables.

All produced the same fast-blue-blink-no-USB result.

### What actually fixed it

**Swapped the nice!nano for a different unit.** The new controller worked
immediately with the *same* firmware that had been failing.

### Root cause

The bad controller had **Adafruit nRF52 Bootloader v0.10.0 dated Feb 3 2026**.
The working one has **v0.6.0 dated Jun 19 2021**. Both ship SoftDevice S140
v6.1.1, so the application offset is identical (`0x26000`) and the same UF2s
are bit-for-bit compatible.

The newer Feb-2026 bootloader has a USB / device-bring-up regression that
prevents ZMK firmware from enumerating after the bootloader hands off. The
bootloader itself enumerates as a DFU device fine — the failure is on the
application-side USB stack after the jump.

Our working lily58 and tbkmini both ship the older v0.6.0 bootloader, which
is why they were never affected.

### How to check which bootloader you have

With the controller in DFU mode (double-tap reset), mount it as mass storage
and read `INFO_UF2.TXT`:

```bash
DEV=$(lsblk -no NAME,LABEL | awk '$2=="NICENANO"{print "/dev/"$1}')
sudo mount "$DEV" /mnt/nicenano
cat /mnt/nicenano/INFO_UF2.TXT
```

Look at the `UF2 Bootloader` version and `Date` lines. If you see **0.10.0 /
Feb 2026** and the symptoms above, the bootloader is the problem.

### Recovery options

1. **Easiest**: swap the nice!nano for one with v0.6.0 (any older stock).
2. **Reflash the bootloader** via SWD with a debug probe to a known-good
   `nice_nano_bootloader-0.6.0_s140_6.1.1.hex`. Not yet attempted here.

### Useful diagnostic commands

```bash
# Is the controller in DFU? (mass storage labelled NICENANO)
lsblk -no NAME,LABEL | grep -i nicenano

# Did the firmware actually enumerate as a keyboard?
lsusb | grep -iE "nice|239a|1d50"        # 1d50:615e == ZMK Corne
sudo dmesg | tail -30                     # look for "ZMK Project Corne Keyboard"

# Bluetooth scan from PC (left half is BLE central, scans for right —
# it does NOT advertise to host devices over BLE; pair via the right half
# or use USB on the left)
bluetoothctl --timeout 8 scan on
```

### Working firmware reference

CI artifacts under the `v0.3.0`-pinned `west.yml` produced UF2s in
`firmware-zip` at offset `0x26000` (~423 KB for `corne_left`,
~345 KB for `corne_right`, ~93 KB for `settings_reset`). Anything
significantly smaller (~99 KB) means the build resolved to the upstream
pure-Zephyr `nice_nano` board variant without ZMK's USB/BLE stack — fix
the board target before flashing.
