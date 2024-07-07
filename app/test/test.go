package test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/hjk1996/LGUPlus-Intern-Project/models"
	"github.com/hjk1996/LGUPlus-Intern-Project/router"
	"github.com/stretchr/testify/mock"
	"gorm.io/gorm"
)

type MockDB struct {
	mock.Mock
}

func (mdb *MockDB) First(dest interface{}, conds ...interface{}) *gorm.DB {
	args := mdb.Called(dest, conds)
	return args.Get(0).(*gorm.DB)
}

var db = struct {
	ReplicaDB *MockDB
}{
	ReplicaDB: &MockDB{},
}

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

		if status := rr.Code; status != http.StatusInternalServerError {
			t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusInternalServerError)
		}

		expected := "Failed to query user information\n"
		if rr.Body.String() != expected {
			t.Errorf("handler returned unexpected body: got %v want %v", rr.Body.String(), expected)
		}
	})

	// 정상적인 요청
	t.Run("valid employeeId", func(t *testing.T) {
		employee := models.Employee{ID: 1, Name: "John Doe"}
		mockDB := new(MockDB)
		mockDB.On("First", &employee, "1").Return(&gorm.DB{})
		db.ReplicaDB = mockDB

		req, err := http.NewRequest("GET", "/home?id=1", nil)
		if err != nil {
			t.Fatal(err)
		}

		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)

		if status := rr.Code; status != http.StatusOK {
			t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
		}

		expected := "Hello John Doe!"
		if rr.Body.String() != expected {
			t.Errorf("handler returned unexpected body: got %v want %v", rr.Body.String(), expected)
		}
	})
}
