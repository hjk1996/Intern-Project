package models

import (
	"time"
	"gorm.io/gorm"
)

type Article struct {
	gorm.Model

	ID         uint `gorm:"primaryKey"`
	EmployeeID uint
	Content    string
	CreatedAt  time.Time
}
