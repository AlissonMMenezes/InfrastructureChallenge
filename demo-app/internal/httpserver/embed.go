package httpserver

import (
	"embed"
	"html/template"
)

//go:embed templates/*.tmpl
var templateFS embed.FS

//go:embed openapi.json
var openAPISpec []byte

// ParseTemplates loads and parses HTML templates from the embedded filesystem.
func ParseTemplates() (*template.Template, error) {
	return template.ParseFS(templateFS, "templates/*.tmpl")
}
