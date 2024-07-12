package test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/hjk1996/LGUPlus-Intern-Project/router"
)

func TestHomeHandler(t *testing.T) {
	router := router.NewRouter()

	// 허용되지 않은 메소드로 요청을 보냈을 때
	t.Run("method not allowed", func(t *testing.T) {
		req, err := http.NewRequest("POST", "/home", nil)
		if err != nil {
			t.Fatal(err)
		}

		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)

		if status := rr.Code; status != http.StatusMethodNotAllowed {
			t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusMethodNotAllowed)
		}

		expected := "Method not allowed"
		if rr.Body.String() != expected {
			t.Errorf("handler returned unexpected body: got %v want %v", rr.Body.String(), expected)
		}
	})

	// employee id를 query param에 입력안했을 때
	t.Run("missing employeeId", func(t *testing.T) {
		req, err := http.NewRequest("GET", "/home", nil)
		if err != nil {
			t.Fatal(err)
		}

		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)

		if status := rr.Code; status != http.StatusBadRequest {
			t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusInternalServerError)
		}

	})

	// 정상적인 요청
}

func TestArticleHandler(t *testing.T) {
	router := router.NewRouter()

	t.Run("method not allowed", func(t *testing.T) {
		req, err := http.NewRequest("GET", "/article", nil)
		if err != nil {
			t.Fatal(err)
		}

		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)

		if status := rr.Code; status != http.StatusMethodNotAllowed {
			t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusMethodNotAllowed)
		}

		expected := "Method not allowed"

		if expected != rr.Body.String() {
			t.Errorf("handler returned unexpected body: got %v want %v", rr.Body.String(), expected)
		}

	})
}
