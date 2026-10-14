// SPDX-License-Identifier: MIT
// Copyright (c) 2019-2026 CrazyMax
//
//go:generate go tool goversioninfo -icon=res/papp.ico -manifest=res/papp.manifest
package main

import (
	"os"
	"path/filepath"

	"github.com/portapps/portapps/v3"
	"github.com/portapps/portapps/v3/pkg/files"
	"github.com/portapps/portapps/v3/pkg/log"
)

type config struct {
	Cleanup  bool   `yaml:"cleanup" mapstructure:"cleanup"`
	LogLevel string `yaml:"log_level" mapstructure:"log_level"`
}

// defaultConfig returns the default launcher configuration.
func defaultConfig() *config {
	return &config{
		Cleanup:  false,
		LogLevel: "debug",
	}
}

// logArg returns the "--log <level>" CLI argument appended to the VSCodium
// command line to force its log level into the portable data\logs folder
// (VSCODE_LOGS). The level is read from vscodiumportable.yml (app.log_level,
// default "debug" matching the upstream Portapps template). Hardcoded CLI args
// are appended after both common.args (vscodiumportable.yml) and command-line
// args (see portapps App.Launch), so they cannot be overridden by the user;
// set app.log_level to e.g. "info" to reduce volume.
func logArg(level string) string {
	return "--log " + level
}

var (
	app *portapps.App
	cfg *config
)

// ensureApp initializes the application once. It is invoked from main so that
// the package can be linked and unit-tested without side effects.
func ensureApp() {
	if app != nil {
		return
	}
	var err error

	// Default config
	cfg = defaultConfig()

	// Init app
	if app, err = portapps.NewWithCfg("vscodiumportable", "VSCodium", cfg); err != nil {
		log.Fatal().Err(err).Msg("Cannot initialize application. See log file for more info.")
	}
}

func main() {
	ensureApp()

	if err := os.MkdirAll(app.DataPath, os.ModePerm); err != nil {
		log.Fatal().Err(err).Msg("Cannot create data directory.")
	}
	app.Process = filepath.Join(app.AppPath, "VSCodium.exe")
	// "--log <level>" forces VSCodium's log level into the portable data\logs
	// folder (VSCODE_LOGS). The level is read from vscodiumportable.yml
	// (app.log_level, default "debug" matching the upstream Portapps template).
	// Hardcoded CLI args are appended after both common.args (vscodiumportable.yml)
	// and command-line args (see portapps App.Launch), so they cannot be
	// overridden by the user; set app.log_level to e.g. "info" to reduce volume.
	app.Args = []string{
		logArg(cfg.LogLevel),
	}

	// Cleanup on exit
	if cfg.Cleanup {
		defer func() {
			files.Cleanup(filepath.Join(os.Getenv("APPDATA"), "VSCodium"))
		}()
	}

	os.Setenv("VSCODE_APPDATA", filepath.Join(app.DataPath, "appdata"))
	if !app.Config().Common.DisableLog {
		os.Setenv("VSCODE_LOGS", filepath.Join(app.DataPath, "logs"))
	}
	os.Setenv("VSCODE_EXTENSIONS", filepath.Join(app.DataPath, "extensions"))

	defer app.Close()
	app.Launch(os.Args[1:])
}
