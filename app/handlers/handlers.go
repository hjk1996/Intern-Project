package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"

	log "github.com/sirupsen/logrus"

	"github.com/hjk1996/LGUPlus-Intern-Project/db"
	"github.com/hjk1996/LGUPlus-Intern-Project/models"
)

func HealthCheckHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusMethodNotAllowed)
		w.Write([]byte("Method not allowed"))
		return
	}

	w.WriteHeader(http.StatusOK)
}

// 홈화면
func HomeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusMethodNotAllowed)
		w.Write([]byte("Method not allowed"))
		return
	}

	query := r.URL.Query()
	employeeId := query.Get("id")

	var employee models.Employee

	result := db.DB.First(&employee, employeeId)

	if result.Error != nil {
		http.Error(w, "Failed to query user informaion", http.StatusInternalServerError)
		log.Error(result.Error)
		return
	}

	w.Header().Set("Content-Type", "text/plan")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf("Hello %s!", employee.Name)))
}

type ArticleBody struct {
	Content string `json:"content"`
}

// DB에 article write하는 handler
func ArticleHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusMethodNotAllowed)
		w.Write([]byte("Method not allowed"))
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Failed to read request body", http.StatusBadRequest)
		return

	}

	var writeBody ArticleBody
	err = json.Unmarshal(body, &writeBody)

	if err != nil {
		http.Error(w, "Failed to parse request body", http.StatusBadRequest)
		return
	}

	query := r.URL.Query()
	idStr := query.Get("id")
	employeeId, err := strconv.ParseUint(idStr, 10, 32)
	employeeIdUint := uint(employeeId)

	if err != nil {
		http.Error(w, "Invalid employee id", http.StatusBadRequest)
		return

	}

	article := models.Article{
		EmployeeID: employeeIdUint,
		Content:    writeBody.Content,
	}

	result := db.DB.Create(&article)

	if result.Error != nil {
		http.Error(w, "Failed to write data to db", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/plan")
	w.WriteHeader(http.StatusCreated)
	w.Write([]byte("Successfully wrote the article"))

}
