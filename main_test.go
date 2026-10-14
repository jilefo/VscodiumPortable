// SPDX-License-Identifier: MIT
// Copyright (c) 2019-2026 CrazyMax
package main

import "testing"

func TestDefaultConfig(t *testing.T) {
	cfg := defaultConfig()
	if cfg.Cleanup {
		t.Errorf("defaultConfig().Cleanup = %v, want false", cfg.Cleanup)
	}
	if cfg.LogLevel != "debug" {
		t.Errorf("defaultConfig().LogLevel = %q, want %q", cfg.LogLevel, "debug")
	}
}

func TestLogArg(t *testing.T) {
	tests := []struct {
		level string
		want  string
	}{
		{"debug", "--log debug"},
		{"info", "--log info"},
		{"warn", "--log warn"},
		{"error", "--log error"},
		{"", "--log "},
	}
	for _, tt := range tests {
		if got := logArg(tt.level); got != tt.want {
			t.Errorf("logArg(%q) = %q, want %q", tt.level, got, tt.want)
		}
	}
}
