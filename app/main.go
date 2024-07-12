package main

import (
	"fmt"
	"net/http"
	"os"

	log "github.com/sirupsen/logrus"

	"github.com/hjk1996/LGUPlus-Intern-Project/db"
	"github.com/hjk1996/LGUPlus-Intern-Project/router"
)

func init() {
	log.SetFormatter(&log.JSONFormatter{})
	log.SetOutput(os.Stdout)
}

func main() {

	db.Init()

	router := router.NewRouter()
	addr := os.Getenv("APP_PORT")

	if addr == "" {
		addr = "8080"
	}

	log.Infof("Starting server on :%s", addr)

	err := http.ListenAndServe(fmt.Sprintf(":%s", addr), router)

	if err != nil {
		log.Fatalf("Failed to start server: %v", err)

	}

}
