# GTA VI JB

A GTA VI–styled build of [Dopamine](https://github.com/opa334/Dopamine), the rootless arm64e
jailbreak for iOS 15.0 – 18.7.1.

The jailbreak is Dopamine's own code, unchanged: the exploit chain, kernel patches, PAC/PPL/SPTM
bypasses, bootstrap installation, package manager install and tweak injection are exactly as
shipped upstream. This fork only changes the app name and the presentation.

## What was changed

| Area | Change |
| --- | --- |
| App name | Bundle display name `GTA VI JB` (`Info.plist`, `INFOPLIST_KEY_CFBundleDisplayName`) |
| Theme | New default theme `Vice City Sunset` — Miami sunset photograph (free licence, credited below) with a code-drawn fallback |
| Userspace reboot screen | `bootlogo.jp2` splash redrawn: dusk background, vignette, "GRAND THEFT AUTO / VI / GTA VI JB / JAILBREAK" |
| Main screen | "GTA VI / JB" wordmark generated at runtime instead of the Dopamine logo |
| Launch screen | Dark splash with the GTA VI JB wordmark instead of a white flash |
| UI strings | CTA and status strings restyled; remaining Dopamine mentions rebranded in the English strings |
| Build output | `Application/GTAVIJB.ipa` and `Application/GTAVIJB.tipa` |
| Update check | App self-update from the upstream release feed disabled (it would replace this build with stock Dopamine) |
| Bundle identifier | `com.rockstar.gta6jb`, including the app lookup `jbctl` uses when updating from a `.tipa` |
| Wallpaper | After every successful jailbreak the device wallpaper is set to the userspace reboot splash (best effort, see below) |
| App icon | Generated at build time from the same palm photograph with a "GTA6JB" lockup (`scripts/generate_app_icons.swift`) |
| Credits | The Source Code button opens this repository |

## What is untouched, on purpose

- Every exploit and kernel patch (`kfd`, `DarkSword`, `Titan`, `dementio`, `weightBufs`, `dmaFail`, `multicast_bytecopy`, `badRecovery`, `ClearSword`, `momentarius`, …)
- The BaseBin launchd job labels and their plists (`com.opa334.Dopamine.startup`, `com.opa334.Dopamine.idownloadd`). These are boot-chain daemons, not the app's bundle name; renaming them would risk the jailbreak environment for no benefit.
- All entitlements in `Dopamine.entitlements`, including `platform-application`
- Bootstrap, trust cache, bind mounts, package manager installation
- The GPLv3 licence

That is deliberate: the entitlements and the exploit chain are what make it stable, and the
launchd labels are load-bearing for the jailbreak environment.

## Supported versions

As documented upstream:

- iOS 15.0 – 17.3.1 (arm64e)
- iOS 15.0 – 18.7.1 (arm64)
- iOS 15.0 – 18.7.1 and 26.0 – 26.0.1 (A12/A13)

## Building the IPA

Requirements: macOS with Xcode, Homebrew, and a case-sensitive checkout is not required.

```sh
# 1. Submodules are required (ChOma, XPF, kfd, opainject, litehook)
git submodule update --init --recursive

# 2. Toolchain
brew install ldid make libarchive
# use GNU make, the build relies on GNU make features:
brew install make
export PATH="$(brew --prefix make)/libexec/gnubin:$PATH"

# 3. Bootstrap archives (bundled into the app)
cd Application/Dopamine/Resources && ./download_bootstraps.sh && cd ../../..

# 4. Build
gmake -j$(sysctl -n hw.logicalcpu)
```

Outputs:

- `Application/GTAVIJB.ipa`
- `Application/GTAVIJB.tipa`

The IPA is ad-hoc signed with `ldid` using `Application/Dopamine/Dopamine.entitlements`, then
packaged. `Application/Makefile` is the whole packaging step if you want to inspect it.

### Building in CI instead

`.github/workflows/main.yml` builds the exact same thing on a macOS runner and uploads the IPA as
a workflow artefact called **GTA VI JB**. Push a fork and download it from the Actions tab — that
is the practical way to get a binary without owning a Mac.

## Installing

Dopamine requires the `platform-application` entitlement, so it **cannot** be installed by
sideloading a plain IPA with a free or paid developer certificate, AltStore, SideStore or Sideloadly.
The app will launch but the jailbreak will fail, because it is not allowed to do what it needs to.

Install it the way upstream Dopamine is installed:

1. Get **TrollStore** on the device (iOS 14.0 – 16.6.1 / 17.0).
2. Download `GTAVIJB.tipa` (or the `.ipa`, they are identical files) to the device.
3. Open it with TrollStore → *Install*.

TrollStore keeps the `platform-application` entitlement from the binary, which is what makes the
jailbreak work, and it never expires.

## Imagery

The `Vice City Sunset` theme and the userspace-reboot splash use a photograph by
[Tom Morbey](https://unsplash.com/@tommorbey) on [Unsplash](https://unsplash.com/photos/a-palm-tree-is-silhouetted-against-a-colorful-sunset-BsbOshnkbpY),
fetched under the [Unsplash License](https://unsplash.com/license) — free for commercial and
non-commercial use, no permission or attribution required (credited here anyway).

Everything else visual is drawn in code at runtime: the `GTA VI / JB` wordmark, the splash lockup,
and the gradient sunset used as a fallback when a theme has no bundled backdrop.

Rockstar's own GTA VI artwork, key art and screenshots are copyrighted, so none of it is bundled —
publicly viewable is not the same as licensed for redistribution.

## Icons

The app icon is generated at build time by `scripts/generate_app_icons.swift`: the palm photograph
cropped square, a dark scrim, and a "GTA6JB" lockup, written into
`Application/Dopamine/Assets.xcassets/AppIcon.appiconset` at every size the catalog declares. The
`Application/Makefile` runs it before `xcodebuild`, so both local builds and CI get the icon.

Run it on its own with `swift scripts/generate_app_icons.swift`.

## Wallpaper

After a successful jailbreak the app sets the device wallpaper to the userspace reboot splash, so
the home and lock screens match the app. This uses the private
`PLStaticWallpaperImageViewController` API, which is not present on every iOS version — every step
is guarded, and a failure only logs and leaves your existing wallpaper alone. It never affects the
jailbreak itself.

## Themes

The theme picker (Settings → Theme) still lists the original Dopamine themes alongside the new
`Vice City Sunset`. Selecting a theme also regenerates the boot logo, so the userspace reboot splash
follows the selected theme.

## Licence and trademarks

This is a derivative work of Dopamine, licensed under the **GPLv3** — see `LICENSE.md`. If you
distribute a build, you must publish the corresponding source.

"Grand Theft Auto", "GTA" and "GTA VI" are trademarks of Rockstar Games. This is an unofficial
fan-themed fork with no affiliation to or endorsement by Rockstar Games; do not distribute it
publicly under that name.
