package httpserver

// DashboardView is the data passed to the HTML dashboard templates.
type DashboardView struct {
	Title  string
	DBOK   bool
	DBErr  string
	Tables []string
	Items  []ItemRowView
}

// ItemRowView is one row in the dashboard items table.
type ItemRowView struct {
	ID   string
	Name string
}

// SwaggerView is passed to the Swagger UI template.
type SwaggerView struct {
	OpenAPIURL string
}
