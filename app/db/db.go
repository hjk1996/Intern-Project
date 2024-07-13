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
		log.Println("No data found in Employee table, inserting dummy data...")
		insertDummyData(DB)

	}

}

func insertDummyData(db *gorm.DB) error {
	// **먼저 데이터가 있는지 확인하는 쿼리**
	var count int64
	db.Table("Employee").Count(&count)

	// **데이터가 있으면 더미 데이터 삽입을 생략**
	if count > 0 {
		log.Println("Data already exists, skipping dummy data insertion.")
		return nil
	}

	// 스토어드 프로시저 생성 쿼리
	createProcedureSQL := `
	CREATE PROCEDURE InsertDummyData()
	BEGIN
		DECLARE i INT DEFAULT 1;
		WHILE i <= 5000 DO
			-- Employee 생성
			INSERT INTO Employee (Name) VALUES (CONCAT('Employee', i));
			-- 최근 생성된 Employee ID 가져오기
			SET @employee_id = LAST_INSERT_ID();
			-- Article 생성
			INSERT INTO Article (EmployeeID, Content) VALUES (@employee_id, CONCAT('Article content for employee ', i));
			-- 다음 반복으로 증가
			SET i = i + 1;
		END WHILE;
	END;
	`

	// 스토어드 프로시저 실행 쿼리
	callProcedureSQL := `CALL InsertDummyData();`

	// 스토어드 프로시저를 먼저 생성하고 호출
	if err := db.Exec(createProcedureSQL).Error; err != nil {
		return err
	}
	if err := db.Exec(callProcedureSQL).Error; err != nil {
		return err
	}

	return nil
}
