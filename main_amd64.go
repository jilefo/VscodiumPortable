// SPDX-License-Identifier: MIT
// Copyright (c) 2019-2026 CrazyMax
//
// Platform placeholder for GOARCH=amd64. It exists so the launcher package
// always ships an architecture-specific file, keeping build tags exercised
// and the toolchain architecture-aware. Intentionally empty: all runtime
// behavior lives in main.go / the Portapps core.
//go:build amd64
// +build amd64

package main
