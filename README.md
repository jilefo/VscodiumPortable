<p align="center"><a href="https://portapps.io/app/vscodium-portable/" target="_blank"><img width="100" src="https://github.com/portapps/vscodium-portable/blob/master/res/papp.png"></a></p>

<p align="center">
  <a href="https://portapps.io/app/vscodium-portable/#download"><img src="https://img.shields.io/github/release/portapps/vscodium-portable.svg?style=flat-square" alt="GitHub release"></a>
  <a href="https://portapps.io/app/vscodium-portable/#download"><img src="https://img.shields.io/github/downloads/portapps/vscodium-portable/total.svg?style=flat-square" alt="Total downloads"></a>
  <a href="https://github.com/portapps/vscodium-portable/actions?workflow=build"><img src="https://img.shields.io/github/actions/workflow/status/portapps/vscodium-portable/build.yml?label=build&logo=github&style=flat-square" alt="Build Status"></a>
  <br /><a href="https://github.com/sponsors/crazy-max"><img src="https://img.shields.io/badge/sponsor-crazy--max-181717.svg?logo=github&style=flat-square" alt="Become a sponsor"></a>
  <a href="https://www.paypal.me/crazyws"><img src="https://img.shields.io/badge/donate-paypal-00457c.svg?logo=paypal&style=flat-square" alt="Donate Paypal"></a>
</p>

## Notice of Non-Affiliation and Disclaimer

Portapps is not affiliated, associated, authorized, endorsed by, or in any way officially connected with VSCodium™, or any of its subsidiaries or its affiliates.

The official VSCodium™ website can be found at https://vscodium.com/.

The name VSCodium™ as well as related names, marks, emblems and images are registered trademarks of their respective owners.

## About

VSCodium™ portable app made with 🚀 [Portapps](https://portapps.io).<br />
Documentation and downloads can be found on https://portapps.io/app/vscodium-portable/

Current release: **1.140.06880-60** (VSCodium 1.140.06880, Portapps core 3.19.0).

## Features

* 🧳 **Truly portable** — no installation required. Download, extract and run.
* 📂 **Data stored next to the app** — settings, extensions, logs and caches live in a `data` folder
  located in the same directory as the executable, making backups and machine migration trivial.
* ⚙️ **Fully configurable** — common settings (logging, extra args, environment variables) and
  app-specific settings (`cleanup`) are managed through a simple YAML config file.
* 🖥️ **Windows x64** — built for Windows 10 / 11 64-bit.
* 🚀 **Powered by Portapps** — battle-tested portable launcher framework.

## Download

Grab the latest release from the **GitHub Releases** page:

* `vscodiumportable-win64-<version>-<release>.7z` — portable package (recommended)
* `VscodiumPortable.exe` — standalone launcher

The `checksums.txt` file in every release provides SHA256 checksums for all artifacts.

## Quick start

1. Download the `.7z` portable package from the latest release.
2. Extract it to any folder (e.g. `D:\VSCodiumPortable`).
3. Run `VscodiumPortable.exe`.

That's it. The launcher starts VSCodium with a portable data directory
(`data\appdata`, `data\extensions`, `data\logs`) located next to the executable.

> **Tip:** for the portable CLI, use `vscodium.cmd` from a command prompt. It runs
> VSCodium's CLI (`cli.js`) with the same portable environment variables.

## Configuration

On first run, the launcher writes a sample configuration file
`vscodiumportable.sample.yml` next to the executable. Copy it to
`vscodiumportable.yml` and edit to customize:

```yaml
common:
  disable_log: false      # Disable log file generation
  args: []                # Additional arguments passed to VSCodium (e.g. ["--log", "debug"])
  env: {}                 # Additional environment variables
  app_path: ""            # Override the app folder (default: ./app)
app:
  cleanup: false          # Cleanup VSCodium APPDATA on exit
```

* `common.disable_log: true` — prevents the launcher from writing log files.
* `common.args` — e.g. `args: ["--disable-gpu"]` to tweak VSCodium startup. Debug logging
  (`--log debug`) is already appended by the launcher and cannot be removed via config;
  VSCodium logs are written under `data\logs`.
* `app.cleanup: true` — removes leftover VSCodium data under `%APPDATA%\VSCodium`
  when the app exits (useful for shared/guest machines).

## Build from sources

### Prerequisites

* [Go](https://go.dev/dl/) **1.26+**
* [Apache Ant](https://ant.apache.org/) (optional, for the one-shot release target)
* [7-Zip](https://www.7-zip.org/) or any zip tool (optional, for packaging)

### Release build (Ant)

```bash
ant release
```

This runs the Portapps core build pipeline (downloads the official VSCodium archive,
compiles the launcher, assembles the portable tree and writes `checksums.txt`
into `bin\release`).

### Manual build

```bash
# 1. Generate Windows version resources
go generate ./...

# 2. Build the launcher (Windows GUI subsystem)
go build -ldflags "-s -w -H=windowsgui" -o bin\tmp\vscodiumportable.exe .

# 3. Assemble the portable tree
#    - extract the official VSCodium zip into bin\build\app
#    - copy the launcher as bin\build\VscodiumPortable.exe
#    - copy res\vscodium.cmd, README.md, CHANGELOG.md and portapp.json
```

## Project structure

```
├── bin\                # Build artifacts (build / release / setup / tmp)
├── res\                # App resources (icons, manifest, setup files, vscodium.cmd)
├── .github\workflows\  # CI and release automation (build / released / labels / zizmor)
├── build.properties    # App version, IDs and official artifact URLs
├── build.xml           # Ant entry point, delegates to the Portapps core build
├── main.go             # Launcher entry point (Portapps app logic)
├── main_*.go           # Platform-specific build-tag files (386/amd64/arm/arm64)
├── versioninfo.json    # Windows version resource definition
├── CHANGELOG.md
└── README.md
```

## Contributing

Want to contribute? Awesome! Please read our [contributing guidelines](CONTRIBUTING.md)
first. The most basic way to show your support is to star the project or to raise issues.

You can also support this project by [**becoming a sponsor on GitHub**](https://github.com/sponsors/crazy-max) or by
making a [Paypal donation](https://www.paypal.me/crazyws) to ensure this journey continues indefinitely!

Thanks again for your support, it is much appreciated! :pray:

## License

MIT. See `LICENSE` for more details.<br />
Rocket icon credit to [Squid Ink](http://thesquid.ink).
