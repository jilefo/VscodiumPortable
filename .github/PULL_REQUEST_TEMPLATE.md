---
name: Pull Request
about: Submit changes to VscodiumPortable
title: ''
labels: ''
assignees: ''
---

## Description

<!-- Describe the change and the motivation behind it. Link related issues if any. -->

## Testing

<!-- Describe how the change was tested. Tick the checks that apply. -->

- [ ] `go build` passes
- [ ] `go test ./...` passes
- [ ] `scripts\check-version.ps1` passes (version consistency)
- [ ] Manual launch of the portable app works (if runtime code changed)
- [ ] `7za t` passes on the release archive (if build artifacts changed)

## Release impact

<!-- Does this change affect the release process, build properties or published artifacts? -->

## Checklist

- [ ] CHANGELOG.md updated (added/modified an entry under `## [Unreleased]` or the release section)
- [ ] Documentation (README / CONTRIBUTING) updated if needed
- [ ] No unrelated changes mixed into this PR
- [ ] Code is `gofmt`-compliant (if Go code changed)
