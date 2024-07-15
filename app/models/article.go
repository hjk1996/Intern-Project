package models

import (
	"time"

	"gorm.io/gorm"
)

type Article struct {
	gorm.Model
	ID         uint `gorm:"primaryKey"`
	EmployeeID uint `gorm:"column:employee_id"`
	Content    string
	CreatedAt  time.Time
}

func (Article) TableName() string {
	return "articles"
}
