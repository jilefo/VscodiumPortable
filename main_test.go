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
		want  []string
	}{
		{"debug", []string{"--log", "debug"}},
		{"info", []string{"--log", "info"}},
		{"warn", []string{"--log", "warn"}},
		{"error", []string{"--log", "error"}},
		{"", []string{"--log", ""}},
	}
	for _, tt := range tests {
		got := logArg(tt.level)
		if len(got) != len(tt.want) {
			t.Errorf("logArg(%q) = %v, want %v", tt.level, got, tt.want)
			continue
		}
		for i := range got {
			if got[i] != tt.want[i] {
				t.Errorf("logArg(%q) = %v, want %v", tt.level, got, tt.want)
				break
			}
		}
	}
}
