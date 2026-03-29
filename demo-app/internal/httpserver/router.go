package httpserver

import (
	"html/template"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// NewRouter returns the full HTTP handler (Chi mux) for the demo API.
func NewRouter(pool *pgxpool.Pool, tmpl *template.Template) http.Handler {
	h := NewHandler(pool, tmpl)
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(prometheusMiddleware)

	r.Get("/", h.Dashboard)
	r.Post("/demo/item", h.AddDemoItem)
	r.Get("/healthz", h.Healthz)
	r.Get("/items", h.ListItems)
	r.Post("/items", h.CreateItem)
	r.Get("/api/openapi.json", h.OpenAPISpec)
	r.Get("/api/docs", h.SwaggerDocs)
	r.Handle("/metrics", promhttp.Handler())
	return r
}
