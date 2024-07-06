package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/hjk1996/LGUPlus-Intern-Project/router"
)

func main() {
	router := router.NewRouter()
	addr := os.Getenv("APP_PORT")

	if addr == "" {
		addr = "8000"
	}

	log.Printf("Starting server on :%s\n", addr)

	if err := http.ListenAndServe(fmt.Sprintf(":%s", addr), router); err != nil {
		log.Fatalf("failed to start server: %s\n", err.Error())
	}

}
