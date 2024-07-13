package db

import (
	"fmt"
	"log"
	"os"

	"github.com/hjk1996/LGUPlus-Intern-Project/models"
	"github.com/hjk1996/LGUPlus-Intern-Project/secrets"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/plugin/dbresolver"
)

var DB *gorm.DB

// TODO db init할 때 dummy data 삽입하기
func Init() {
	dbSecretName := os.Getenv("DB_SECRET_NAME")
	readerEndpoint := os.Getenv("READER_ENDPOINT")
	writerEndpoint := os.Getenv("WRITER_ENDPOINT")
	dbName := os.Getenv("DB_NAME")
	region := os.Getenv("REGION")

	dbSecret, err := secrets.GetDBSecret(dbSecretName, region)

	if err != nil {
		log.Fatalf("failed to load master db secret: %v", err)
	}

	readerDsn := fmt.Sprintf("%s:%s@tcp(%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		dbSecret.User, dbSecret.Password, readerEndpoint, dbName)
	writerDsn := fmt.Sprintf("%s:%s@tcp(%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		dbSecret.User, dbSecret.Password, writerEndpoint, dbName)

	DB, err = gorm.Open(mysql.Open(writerDsn), &gorm.Config{})

	if err != nil {
		log.Fatalf("Failed to connect to master db: %v", err)
	}

	err = DB.Use(
		dbresolver.Register(
			dbresolver.Config{
				Replicas:          []gorm.Dialector{mysql.Open(readerDsn)},
				Policy:            dbresolver.RandomPolicy{},
				TraceResolverMode: true,
			},
		),
	)

	if err != nil {
		log.Fatalf("Failed to connecto read replica: %v", err)
	}

	DB.AutoMigrate(&models.Employee{}, &models.Article{})

	var employee models.Employee

	result := DB.First(&employee, "1")
	// TODO: 데이터 없을 때 데이터 추가하기
	if result.Error != nil {

        
	}

}
