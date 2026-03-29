package httpserver

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

const maxItemNameLen = 200

// Handler serves HTTP for the demo API.
type Handler struct {
	pool *pgxpool.Pool
	tmpl *template.Template
}

// NewHandler builds a Handler.
func NewHandler(pool *pgxpool.Pool, tmpl *template.Template) *Handler {
	return &Handler{pool: pool, tmpl: tmpl}
}

func truncateItemName(name string) string {
	r := []rune(strings.TrimSpace(name))
	if len(r) > maxItemNameLen {
		return string(r[:maxItemNameLen])
	}
	return string(r)
}

func (h *Handler) Dashboard(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vm := DashboardView{Title: "Demo API"}
	ctxTO, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	conn, err := h.pool.Acquire(ctxTO)
	if err == nil {
		defer conn.Release()
		vm.DBOK = true
		trows, qerr := conn.Query(ctxTO, `
			SELECT table_name
			FROM information_schema.tables
			WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
			ORDER BY table_name`)
		if qerr != nil {
			vm.DBOK = false
			vm.DBErr = fmt.Sprintf("%T: %v", qerr, qerr)
		} else {
			func() {
				defer trows.Close()
				for trows.Next() {
					var t string
					if trows.Scan(&t) == nil {
						vm.Tables = append(vm.Tables, t)
					}
				}
				if err := trows.Err(); err != nil {
					vm.DBOK = false
					vm.DBErr = fmt.Sprintf("%T: %v", err, err)
				}
			}()
		}
		if vm.DBOK {
			irows, qerr := conn.Query(ctxTO, "SELECT id, name FROM items ORDER BY id LIMIT 100")
			if qerr != nil {
				vm.DBOK = false
				vm.DBErr = fmt.Sprintf("%T: %v", qerr, qerr)
			} else {
				func() {
					defer irows.Close()
					for irows.Next() {
						var id int32
						var name string
						if irows.Scan(&id, &name) == nil {
							vm.Items = append(vm.Items, ItemRowView{
								ID:   strconv.Itoa(int(id)),
								Name: name,
							})
						}
					}
					if err := irows.Err(); err != nil {
						vm.DBOK = false
						vm.DBErr = fmt.Sprintf("%T: %v", err, err)
					}
				}()
			}
		}
	} else {
		vm.DBErr = fmt.Sprintf("%T: %v", err, err)
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := h.tmpl.ExecuteTemplate(w, "layout", vm); err != nil {
		http.Error(w, "template error", http.StatusInternalServerError)
	}
}

func (h *Handler) AddDemoItem(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "bad form", http.StatusBadRequest)
		return
	}
	name := truncateItemName(r.FormValue("name"))
	if name == "" {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}
	ctx := r.Context()
	_, err := h.pool.Exec(ctx, "INSERT INTO items(name) VALUES ($1)", name)
	if err != nil {
		http.Error(w, "db error", http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func (h *Handler) Healthz(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

type itemCreateRequest struct {
	Name string `json:"name"`
}

type itemJSON struct {
	ID   int32  `json:"id"`
	Name string `json:"name"`
}

func (h *Handler) CreateItem(w http.ResponseWriter, r *http.Request) {
	var in itemCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	name := truncateItemName(in.Name)
	if name == "" {
		http.Error(w, "name required", http.StatusBadRequest)
		return
	}
	ctx := r.Context()
	var id int32
	err := h.pool.QueryRow(ctx, "INSERT INTO items(name) VALUES ($1) RETURNING id", name).Scan(&id)
	if err != nil {
		http.Error(w, "db error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"id": id, "name": name})
}

func (h *Handler) ListItems(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	rows, err := h.pool.Query(ctx, "SELECT id, name FROM items ORDER BY id")
	if err != nil {
		http.Error(w, "db error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()
	var items []itemJSON
	for rows.Next() {
		var it itemJSON
		if err := rows.Scan(&it.ID, &it.Name); err != nil {
			http.Error(w, "db error", http.StatusInternalServerError)
			return
		}
		items = append(items, it)
	}
	if items == nil {
		items = []itemJSON{}
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"items": items})
}

func (h *Handler) SwaggerDocs(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_ = h.tmpl.ExecuteTemplate(w, "swagger", SwaggerView{OpenAPIURL: "/api/openapi.json"})
}

func (h *Handler) OpenAPISpec(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(openAPISpec)
}
