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

func logRequest(r *http.Request) *log.Entry {
	return log.WithFields(log.Fields{
		"method": r.Method,
		"url":    r.URL.String(),
		"ip":     r.RemoteAddr,
		"agent":  r.UserAgent(),
	})
}

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
	logger := logRequest(r)

	if r.Method != http.MethodGet {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusMethodNotAllowed)
		w.Write([]byte("Method not allowed"))
		logger.Warn("Method not allowed")
		return
	}

	query := r.URL.Query()
	employeeId := query.Get("id")

	var employee models.Employee

	result := db.DB.First(&employee, employeeId)

	if result.Error != nil {
		msg := "Failed to query user informaion"
		http.Error(w, msg, http.StatusInternalServerError)
		logger.WithError(result.Error).Error(msg)

		return
	}

	w.Header().Set("Content-Type", "text/plan")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf("Hello %s!", employee.Name)))

	logger.WithFields(log.Fields{
		"employeeId": employeeId,
	}).Info("HomeHandler completed successfully")
}

type ArticleBody struct {
	Content string `json:"content"`
}

// DB에 article write하는 handler
func ArticleHandler(w http.ResponseWriter, r *http.Request) {

	logger := logRequest(r)

	if r.Method != http.MethodPost {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusMethodNotAllowed)
		w.Write([]byte("Method not allowed"))
		logger.Warn("Method not allowed")

		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		msg := "Failed to read request body"
		http.Error(w, msg, http.StatusBadRequest)
		logger.WithError(err).Error(msg)
		return
	}

	var writeBody ArticleBody
	err = json.Unmarshal(body, &writeBody)

	if err != nil {
		msg := "Failed to parse request body"
		http.Error(w, msg, http.StatusBadRequest)
		log.WithError(err).Error(msg)
		return
	}

	query := r.URL.Query()
	idStr := query.Get("id")
	employeeId, err := strconv.ParseUint(idStr, 10, 32)
	employeeIdUint := uint(employeeId)

	if err != nil {
		msg := "Invalid employee id"
		http.Error(w, msg, http.StatusBadRequest)
		log.WithError(err).Error(msg)
		return

	}

	article := models.Article{
		EmployeeID: employeeIdUint,
		Content:    writeBody.Content,
	}

	result := db.DB.Create(&article)

	if result.Error != nil {
		msg := "Failed to write data to db"
		http.Error(w, msg, http.StatusInternalServerError)
		log.WithError(result.Error).Error(msg)
		return
	}

	w.Header().Set("Content-Type", "text/plan")
	w.WriteHeader(http.StatusCreated)
	w.Write([]byte("Successfully wrote the article"))

	logger.WithFields(log.Fields{
		"employeeId": employeeId,
	}).Info("ArticleHandler completed successfully")

}
