# Ubuntu Touch for the Motorola Moto G5S Plus (sanders)

Halium 11 port of Ubuntu Touch 24.04-1.x for the Moto G5S Plus (XT1802/03/04/05/06,
codename `sanders`, Snapdragon 625 / MSM8953).

- Kernel: [android_kernel_motorola_sanders](https://github.com/EEMuk/android_kernel_motorola_sanders)
  (branch `halium-11`), the PixelExperience 11 3.18 kernel plus Halium, AppArmor and driver fixes.
- Android base: the PixelExperience 11 vendor image, which this device keeps on the `oem` partition.

## Status

| Works | Not working / not tested |
|---|---|
| Display, touch, GPU, video playback | NFC, FM radio |
| Wi-Fi, hotspot, Bluetooth | Video calls (ViLTE): not supported by Ubuntu Touch |
| Calls (VoLTE and 2G), SMS, mobile data | Dual SIM, MMS: not tested |
| Audio: speaker, earpiece, microphone, call audio | Wired headset: not tested |
| Rear and front camera, video recording, dual-tone flash | |
| Flashlight, notification LED, vibration | |
| GPS with XTRA assistance | |
| Fingerprint, proximity, light sensor, auto-brightness, rotation | |
| USB: MTP, tethering, developer mode | |
| Waydroid (Android apps) | |

Idle battery drain is still being tuned.

## Installation

Requirements:

1. An unlocked bootloader.
2. PixelExperience 11 installed, so that its vendor image is on the `oem`
   partition. Back up your phone first, including `persist`, `modemst1`,
   `modemst2` and `fsg`: they hold the IMEI, calibration and carrier data.
3. `fastboot` on the computer.

Then flash the boot image and system image built from this repository (see
below) from the bootloader:

```
fastboot flash boot boot.img
fastboot flash system ubuntu.img
fastboot -w
fastboot reboot
```

`fastboot -w` erases userdata. The first boot takes a few minutes.

## Building

```
./build.sh            # kernel, boot.img and the device tarball (out/)
sudo ./make-system-image.sh   # Ubuntu Touch rootfs + device tarball -> system image
```

`build.sh` wraps [halium-generic-adaptation-build-tools](https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools)
and clones the kernel from `deviceinfo_kernel_source`. To build from a local
kernel checkout instead, set `KERNEL_DIR=/path/to/kernel`.

## Patched components

Prebuilt in `overlay/`, with the source changes in `patches/`:

- `ofono-binder-plugin` 1.1.25: tolerate brief data-registration drops; send
  SMS over IMS with `IRadio.sendImsSms`.
- `ofono-binder-plugin-ext-qti`: place calls with call details so the modem
  can use VoLTE; don't use IMS SMS or hangup methods that this vendor's
  `IImsRadio@1.0` doesn't have.
- `sanders-gnss-netstate` (`tools/`): reports network availability to the GNSS
  HAL so XTRA assistance data gets downloaded.

## Notes for porters

Most of the non-obvious fixes are documented in the commit messages and in
comments in `overlay/`. Some worth knowing on this device:

- The carrier config (MBN) has to be provided to the RIL
  (`sanders-modem-config`), otherwise the modem never registers VoLTE.
- PulseAudio uses `module-droid-card-29`: the audio HAL doesn't implement audio
  patches, so call audio needs `set_parameters` routing.
- usb-moded must use the `android_usb` gadget; configfs stays unmounted on the
  host.
