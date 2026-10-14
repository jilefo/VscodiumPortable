
# Contributing to VSCodium Portable

First off, thanks for taking the time to contribute! 🎉

The following is a set of guidelines for contributing to VSCodium Portable.
These are just guidelines, not rules — use your best judgment and feel free to
propose changes to this document in a pull request.

## Code of Conduct

This project and everyone participating in it is governed by our
[Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to
uphold this code. Please report unacceptable behavior.

## How to contribute

### Reporting bugs

1. Search the [open issues](https://github.com/portapps/vscodium-portable/issues)
   to make sure the bug has not already been reported.
2. If not, [open a new issue](https://github.com/portapps/vscodium-portable/issues/new?assignees=&labels=bug&template=bug_report.yml)
   using the **Bug report** template. A good bug report should:
   * Use a clear and descriptive title.
   * Describe the exact steps to reproduce the problem.
   * Describe the behavior you observed and what you expected instead.
   * Attach the launcher log file (`log\vscodiumportable.log` next to the executable)
     and the version of the release you are using.
   * Include your Windows version and architecture.

### Suggesting features / enhancements

1. Search the [open issues](https://github.com/portapps/vscodium-portable/issues)
   to make sure the suggestion has not already been made.
2. [Open a new issue](https://github.com/portapps/vscodium-portable/issues/new?assignees=&labels=enhancement&template=feature_request.yml)
   using the **Feature request** template and describe the feature, why you need
   it and how it should behave.

### Submitting pull requests

1. [Fork](https://github.com/portapps/vscodium-portable/fork) the repository.
2. Create a new branch from `master` for your work:
   `git checkout -b feat/my-feature`.
3. Make your changes.
4. Test your changes (see [Development](#development) below).
5. Update the documentation (`README.md`, `CHANGELOG.md`) if needed.
6. Commit your changes with a clear and descriptive message.
7. Push your branch and open a pull request against `master`.

## Development

### Prerequisites

* [Go](https://go.dev/dl/) **1.26+**
* [Apache Ant](https://ant.apache.org/) (optional)
* [7-Zip](https://www.7-zip.org/) (optional, for packaging)

### Build

```bash
# One-shot release build (Ant)
ant release

# Or manual build
go generate ./...
go build -ldflags "-s -w -H=windowsgui" -o bin\tmp\vscodiumportable.exe .
```

### Project layout

```
├── bin\                # Build artifacts
├── res\                # App resources
├── build.properties    # App version, IDs and official artifact URLs
├── build.xml           # Ant entry point
├── main.go             # Launcher entry point
├── main_*.go           # Platform-specific build-tag files (386/amd64/arm/arm64)
└── versioninfo.json    # Windows version resource definition
```

### Style guidelines

* Format your Go code with `gofmt` / `go fmt`.
* Keep the launcher logic minimal — most behavior should live upstream in the
  [Portapps core](https://github.com/portapps/portapps).
* Keep `CHANGELOG.md` entries in the existing format (version, date, bullet list).

## Attribution

This contributing guide is adapted from the
[Portapps project](https://portapps.io/doc/contribute/).
