package router

import (
	"net/http"

	"github.com/hjk1996/LGUPlus-Intern-Project/handlers"
)

func NewRouter() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/", handlers.HealthCheckHandler)
	mux.HandleFunc("/home", handlers.HomeHandler)
	mux.HandleFunc("/article", handlers.ArticleHandler)
	return mux
}
