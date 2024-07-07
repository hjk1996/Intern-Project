package db

import (
	"fmt"
	"log"
	"os"

	"github.com/hjk1996/LGUPlus-Intern-Project/models"
	"github.com/hjk1996/LGUPlus-Intern-Project/secrets"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

var MasterDB *gorm.DB
var ReplicaDB *gorm.DB

func Init() {

	masterSecretName := os.Getenv("MASTER_SECRET_NAME")

	if masterSecretName == "" {
		log.Fatalf("no master secret name found in environment variables")
	}

	replicaSecretName := os.Getenv("REPLICA_SECRET_NAME")

	if replicaSecretName == "" {
		log.Fatalf("no replica secret name found in environment variables")
	}

	region := os.Getenv("REGION")

	if region == "" {
		log.Fatalf("no region name fond in environment variables")
	}

	masterSecret, err := secrets.GetDBSecret(masterSecretName, region)

	if err != nil {
		log.Fatalf("failed to load master db secret: %v", err)
	}

	replicaSecret, err := secrets.GetDBSecret(replicaSecretName, region)

	if err != nil {
		log.Fatalf("failed to load replica db secret: %v", err)
	}

	masterDsn := fmt.Sprintf("%s:%s@tcp(%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		masterSecret.User, masterSecret.Password, masterSecret.Host, masterSecret.Name)
	replicaDsn := fmt.Sprintf("%s:%s@tcp(%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		replicaSecret.User, replicaSecret.Password, replicaSecret.Host, replicaSecret.Name)

	MasterDB, err = gorm.Open(mysql.Open(masterDsn), &gorm.Config{})

	if err != nil {
		log.Fatalf("failed to connect to master db: %v", err)
	}

	MasterDB.AutoMigrate(&models.Employee{}, &models.Article{})

	ReplicaDB, err = gorm.Open(mysql.Open(replicaDsn), &gorm.Config{})

	if err != nil {
		log.Fatalf("failed to connect to replica db: %v", err)
	}

	ReplicaDB.AutoMigrate(&models.Employee{}, &models.Article{})

}
