// Package config loads application settings from the environment.
package config

import (
	"net/url"
	"os"
	"strings"
)

// Config holds runtime configuration for the demo API.
type Config struct {
	ListenAddr  string
	PostgresDSN string
}

// Load reads configuration from environment variables.
func Load() Config {
	return Config{
		ListenAddr:  getenv("LISTEN_ADDR", ":8080"),
		PostgresDSN: postgresDSN(),
	}
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func postgresDSN() string {
	if u := os.Getenv("DATABASE_URL"); u != "" {
		return u
	}
	host := getenv("DB_HOST", "localhost")
	port := getenv("DB_PORT", "5432")
	db := getenv("DB_NAME", "app")
	user := getenv("DB_USER", "app")
	pass := getenv("DB_PASSWORD", "app")
	u := &url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(user, pass),
		Host:   netJoinHostPort(host, port),
		Path:   "/" + db,
	}
	q := u.Query()
	q.Set("sslmode", getenv("DB_SSLMODE", "disable"))
	u.RawQuery = q.Encode()
	return u.String()
}

func netJoinHostPort(host, port string) string {
	if strings.Contains(host, ":") && !strings.HasPrefix(host, "[") {
		return "[" + host + "]:" + port
	}
	return host + ":" + port
}
