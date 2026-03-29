// Command demo-api is the demo application HTTP server (PostgreSQL-backed sample API).
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"

	"github.com/alissonmachado/InfrastructureChallenge/demo-app/internal/config"
	"github.com/alissonmachado/InfrastructureChallenge/demo-app/internal/db"
	"github.com/alissonmachado/InfrastructureChallenge/demo-app/internal/httpserver"
)

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo})))

	cfg := config.Load()

	tmpl, err := httpserver.ParseTemplates()
	if err != nil {
		slog.Error("parse templates", "error", err)
		os.Exit(1)
	}

	ctx := context.Background()
	pool, err := db.Connect(ctx, cfg.PostgresDSN)
	if err != nil {
		slog.Error("database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	if err := db.Migrate(ctx, pool); err != nil {
		slog.Error("migrate", "error", err)
		os.Exit(1)
	}

	handler := httpserver.NewRouter(pool, tmpl)
	slog.Info("listening", "addr", cfg.ListenAddr)
	if err := http.ListenAndServe(cfg.ListenAddr, handler); err != nil {
		slog.Error("server", "error", err)
		os.Exit(1)
	}
}
