package router

import (
	"net/http"

	"github.com/hjk1996/LGUPlus-Intern-Project/handlers"
)

func NewRouter() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/", handlers.HomeHandler)
	mux.HandleFunc("/check-in", handlers.CheckInHandler)
	mux.HandleFunc("check-out", handlers.CheckOutHandler)
	return mux
}
